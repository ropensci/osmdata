#' Get timestamp from system or optional OSM XML document
#'
#' @param doc OSM XML document. If missing, `Sys.time()` is used.
#'
#' @return An R timestamp object
#'
#' @note This defines the timestamp format for \pkg{osmdata} objects, which
#' includes months as text to ensure umambiguous timestamps
#'
#' @noRd
get_timestamp <- function (doc) {

    if (!missing (doc)) {
        tstmp <- xml2::xml_text (xml2::xml_find_all (doc, "//meta/@osm_base"))
        if (length (tstmp) > 0) {
            tstmp <- as.POSIXct (tstmp, format = "%Y-%m-%dT%H:%M:%SZ")
        }
    } else {
        tstmp <- Sys.time ()
    }

    if (length (tstmp) == 0) {
        tstmp <- Sys.time ()
    }

    out <- paste ("[", format (tstmp, format = "%a %e %b %Y %T"), "]")
    out <- gsub ("  ", " ", out) # remove extra space in %e for single digit days
    out <- gsub ("\\.", "\\\\.", out) # Escape dots
}


#' Get OSM database version
#'
#' @param doc OSM XML document
#'
#' @return Single number (as character string) representing OSM database version
#' @noRd
get_osm_version <- function (doc) {

    xml2::xml_text (xml2::xml_find_all (doc, "//osm/@version"))
}


#' Get overpass version
#'
#' @param doc OSM XML document
#'
#' @return Single number (as character string) representing overpass version
#' @noRd
get_overpass_version <- function (doc) {

    xml2::xml_text (xml2::xml_find_all (doc, "//osm/@generator"))
}


#' Check for not implemented queries in overpass call
#'
#' Detects adiff, out meta/ids/tags and out:csv queries which are not
#' implemented for osmdata_* functions except for osmdata_xml (no out:csv) and
#' osmdata_data_frame.
#'
#' @param obj Initial \link{osmdata} object
#'
#' @return Nothing. Throw errors or warnings for not implemented queries.
#'
#' @noRd
check_not_implemented_queries <- function (obj) {
    if (!is.null (obj$overpass_call)) {

        if (grepl ("; out (tags|ids)( center)*;$", obj$overpass_call)) {
            stop (
                "Queries returning no geometries (out tags/ids) not accepted. ",
                'Use queries with `out="body"` or `out="skel"` instead. ',
                "Alternatively, you can retrieve the results with osmdata_xml ",
                "or osmdata_data_frame.",
                call. = FALSE
            )
        }

        if (grepl ("\\[adiff:", obj$overpass_call)) {
            stop (
                "adiff queries not yet implemented. Alternatively, you can ",
                "retrieve the results with osmdata_xml or ",
                "osmdata_data_frame.",
                call. = FALSE
            )
        }

        if (grepl ("\\[out:csv", obj$overpass_call)) {
            stop ("out:csv queries only work with osmdata_data_frame.")
        }

        if (grepl ("out meta;$", obj$overpass_call)) {
            warning (
                "`out meta` queries not yet implemented. Metadata fields will ",
                "be missing. Alternatively, you can retrieve the results with ",
                "osmdata_xml or osmdata_data_frame.",
                call. = FALSE
            )
        }

    }
}


fix_duplicated_columns <- function (x) {
    dup <- duplicated (x)
    i <- 1
    while (any (dup)) {
        x [dup] <- paste0 (x [dup], ".", i)
        i <- i + 1
        dup <- duplicated (x)
    }

    return (x)
}


fix_columns_list <- function (l) {
    cols <- lapply (l, names)
    cols_no_dup <- lapply (cols, fix_duplicated_columns)
    if (!identical (cols, cols_no_dup)) {
        warning (
            "Feature keys clash with id or metadata columns and will be ",
            "renamed by appending `.n`:\n\t",
            paste (
                unique (setdiff (unlist (cols_no_dup), unlist (cols))),
                collapse = ", "
            )
        )
        l <- mapply (function (x, col) {
            suppressWarnings (names (x) <- col)
            x
        }, x = l, col = cols_no_dup, SIMPLIFY = FALSE)
    }

    return (l)
}


#' fill osmdata object with overpass data and metadata, and return character
#' version of OSM xml document
#'
#' @param obj Initial \link{osmdata} object
#' @param doc Document contain XML-formatted version of OSM data
#' @inheritParams osmdata_sf
#' @return List of an \link{osmdata} object (`obj`), and XML
#'      document (`doc`)
#' @noRd
fill_overpass_data <- function (obj, doc, quiet = TRUE, encoding = "UTF-8") {

    if (missing (doc)) {

        doc <- overpass_query (
            query = obj$overpass_call, quiet = quiet,
            encoding = encoding
        )

        obj <- get_metadata (obj, doc)

    } else {

        if (is.character (doc)) {
            if (!file.exists (doc)) {
                stop ("file ", doc, " does not exist")
            }
            doc <- xml2::read_xml (doc)
        }
        obj <- get_metadata (obj, doc)
    }

    list (obj = obj, doc = doc)
}


get_metadata <- function (obj, doc) {

    if (inherits (doc, "xml_document")) {
        meta <- list (
            timestamp = get_timestamp (doc),
            OSM_version = get_osm_version (doc),
            overpass_version = get_overpass_version (doc)
        )
    } else {
        meta <- list ()
    }

    q <- obj$overpass_call

    # q is mostly passed as result of opq_string_intern, so date and diff query
    # metadata must be extracted from string
    if (is.character (q)) {

        x <- strsplit (q, "\"") [[1]]

        if (grepl ("date", x [1])) {

            if (length (x) < 2) {
                stop ("unrecongised query format")
            }
            meta$datetime_to <- x [2]
            meta$query_type <- "date"

        } else if (grepl ("adiff", x [1])) {

            if (length (x) < 2) {
                stop ("unrecongised query format")
            }
            meta$datetime_from <- x [2]
            meta$datetime_to <- x [4]
            if (!is_datetime (meta$datetime_to) &
                inherits (doc, "xml_document")) { # adiff opq without datetime2
                meta$datetime_to <- xml2::xml_text (xml2::xml_find_all (
                    doc,
                    "//meta/@osm_base"
                ))
            }
            meta$query_type <- "adiff"

        } else if (grepl ("diff", x [1])) {

            if (length (x) < 4) {
                stop ("unrecongised query format")
            }
            meta$datetime_from <- x [2]
            meta$datetime_to <- x [4]
            meta$query_type <- "diff"
        }

    } else if (inherits (q, "overpass_query")) {

        if (!is.null (attr (q, "datetime2"))) {

            meta$datetime_from <- attr (q, "datetime")
            meta$datetime_to <- attr (q, "datetime2")

            if (grepl ("adiff", q$prefix) ||
                (
                    inherits (doc, "xml_document") &&
                        "action" %in% xml2::xml_name (xml2::xml_children (doc))
                )
            ) {
                meta$query_type <- "adiff"
            } else {
                meta$query_type <- "diff"
            }

        } else if (!is.null (attr (q, "datetime"))) {

            if (grepl ("adiff", q$prefix) ||
                (
                    inherits (doc, "xml_document") &&
                        "action" %in% xml2::xml_name (xml2::xml_children (doc))
                )
            ) {
                meta$datetime_from <- attr (q, "datetime")
                meta$datetime_to <- xml2::xml_text (xml2::xml_find_all (
                    doc,
                    "//meta/@osm_base"
                ))
                meta$query_type <- "adiff"
            } else {
                meta$datetime_to <- attr (q, "datetime")
                meta$query_type <- "date"
            }

        }

    } else if (inherits (doc, "xml_document")) { # is.null (q)

        if ("action" %in% xml2::xml_name (xml2::xml_children (doc))) {
            osm_actions <- xml2::xml_find_all (doc, ".//action")
            action_type <- xml2::xml_attr (osm_actions, attr = "type")
            # Adiff have <new> for deleted objects, but diff have not.
            if (length (sel_del <- which (action_type %in% "delete")) > 0) {
                if ("new" %in% xml2::xml_name (xml2::xml_children (
                    osm_actions [sel_del [1]]
                ))) {
                    meta$query_type <- "adiff"
                } else {
                    meta$query_type <- "diff"
                }
            } else {
                meta$query_type <- "diff"
                warning (
                    "OSM data is ambiguous and can correspond either to a ",
                    "diff or an adiff query. As \"q\" parameter is missing, ",
                    "it is not possible to distinguish.\n\tAssuming diff."
                )
            }

        }

    }

    obj$meta <- meta
    attr (q, "datetime") <- attr (q, "datetime2") <- NULL

    obj$overpass_call <- q

    return (obj)
}


#' Extract the metadata character matrices from `rcpp_osmdata_df` output,
#' convert to df, and return only columns with data.
#'
#' The "meta" components returns from `rcpp_osmdata_df()` are all named with
#' underscore prefixes. These are prepended here with "osm" to provide
#' standardised names.
#' @noRd
get_meta_from_cpp_output <- function (res, what = "points") {

    this <- res [[paste0 (what, "_meta")]]
    has_data <- apply (this, 2, function (i) any (nzchar (i)))
    this <- this [, which (has_data), drop = FALSE]
    if (ncol (this) > 0L) {
        colnames (this) <- paste0 ("osm", colnames (this))
    }

    return (as.data.frame (this))
}


#' Extract the center matrices from `rcpp_osmdata_df` output,
#' convert to df, and return only columns with data.
#'
#' The "center" components returns from `rcpp_osmdata_df()` are all named with
#' underscore prefixes. These are prepended here with "osm_center" to provide
#' standardised names.
#' @noRd
get_center_from_cpp_output <- function (res, what = "points") {

    this <- res [[paste0 (what, "_center")]]
    has_data <- apply (this, 2, function (i) any (!is.na (i)))
    this <- this [, which (has_data), drop = FALSE]
    if (ncol (this) > 0L) {
        colnames (this) <- paste0 ("osm_center", colnames (this))
    }

    return (as.data.frame (this))
}


#' Set encoding to UTF-8
#'
#' @param x a data.frame or a list.
#'
#' @return `x` with all the columns or items of type character with UTF-8 encoding set.
#' @noRd
setenc_utf8 <- function (x) {
    char_cols <- which (vapply (x, is.character, FUN.VALUE = logical (1)))
    x [char_cols] <- lapply (x [char_cols], function (y) {
        enc2utf8 (y)
    })

    return (x)
}
