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

    wday_t <- lubridate::wday (tstmp, label = TRUE)
    wday <- lubridate::wday (tstmp, label = FALSE)
    mon <- lubridate::month (tstmp, label = TRUE)
    year <- lubridate::year (tstmp)

    hms <- strsplit (as.character (tstmp), " ") [[1]] [2]
    paste ("[", wday_t, wday, mon, year, hms, "]")
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

#' Return an OSM Overpass query in XML format
#' Read an (XML format) OSM Overpass response from a string, a connection,
#' or a raw vector.
#'
#' @param q An object of class `overpass_query` constructed with
#' \link{opq} and \link{add_osm_feature}.
#' @param filename If given, OSM data are saved to the named file
#' @param quiet suppress status messages.
#' @param encoding Unless otherwise specified XML documents are assumed to be
#'        encoded as UTF-8 or UTF-16. If the document is not UTF-8/16, and lacks
#'        an explicit encoding directive, this allows you to supply a default.
#' @return An object of class `XML::xml_document` containing the result of the
#'         overpass API query.
#'
#' @note Objects of class `xml_document` can be saved as `.xml` or
#' `.osm` files with `xml2::write_xml`.
#'
#' @family extract
#' @export
#'
#' @examples
#' \dontrun{
#' q <- opq ("hampi india")
#' q <- add_osm_feature (q, key = "historic", value = "ruins")
#' osmdata_xml (q, filename = "hampi.osm")
#' }
osmdata_xml <- function (q, filename, quiet = TRUE, encoding) {

    if (missing (encoding)) {
        encoding <- "UTF-8"
    }

    if (missing (q)) {
        stop ('argument "q" is missing, with no default.')
    } else if (is (q, "overpass_query")) {
        q <- opq_string_intern (q, quiet = quiet)
    } else if (!is.character (q)) {
        stop ("q must be an overpass query or a character string")
    }

    doc <- overpass_query (query = q, quiet = quiet, encoding = encoding)
    if (!missing (filename)) {
        xml2::write_xml (doc, file = filename)
    }

    invisible (doc)
}

#' Return an OSM Overpass query as an \link{osmdata} object in \pkg{sp}
#' format.
#'
#' @param q An object of class `overpass_query` constructed with
#'      \link{opq} and \link{add_osm_feature}. May be be omitted,
#'      in which case the \link{osmdata} object will not include the
#'      query.
#' @param doc If missing, `doc` is obtained by issuing the overpass query,
#'        `q`, otherwise either the name of a file from which to read data,
#'        or an object of class \pkg{XML} returned from
#'        \link{osmdata_xml}.
#' @param quiet suppress status messages.
#'
#' @return An object of class `osmdata` with the OSM components (points, lines,
#'         and polygons) represented in \pkg{sp} format.
#'
#' @family extract
#' @export
#'
#' @examples
#' \dontrun{
#' hampi_sp <- opq ("hampi india") %>%
#'     add_osm_feature (key = "historic", value = "ruins") %>%
#'     osmdata_sp ()
#' }
osmdata_sp <- function (q, doc, quiet = TRUE) {

    obj <- osmdata () # uses class def
    if (missing (q)) {
        if (missing (doc)) {
            stop (
                'arguments "q" and "doc" are missing, with no default. ',
                "At least one must be provided."
            )
        }
        if (!quiet) {
            message ("q missing: osmdata object will not include query")
        }
    } else if (is (q, "overpass_query")) {
        obj$bbox <- q$bbox
        obj$overpass_call <- opq_string_intern (q, quiet = quiet)
    } else if (is.character (q)) {
        obj$overpass_call <- q
    } else {
        stop ("q must be an overpass query or a character string")
    }

    temp <- fill_overpass_data (obj, doc, quiet = quiet)
    obj <- temp$obj
    doc <- temp$doc

    if (!quiet) {
        message ("converting OSM data to sp format")
    }

    res <- rcpp_osmdata_sp (paste0 (doc))
    if (is.null (obj$bbox)) {
        obj$bbox <- paste (res$bbox, collapse = " ")
    }
    obj$osm_points <- res$points
    obj$osm_lines <- res$lines
    obj$osm_polygons <- res$polygons
    obj$osm_multilines <- res$multilines
    obj$osm_multipolygons <- res$multipolygons

    class (obj) <- c (class (obj), "osmdata_sp")

    return (obj)
}

#' fill osmdata object with overpass data and metadata, and return character
#' version of OSM xml document
#'
#' @param obj Initial \link{osmdata} object
#' @param doc Document contain XML-formatted version of OSM data
#' @inheritParams osmdata_sp
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

    meta <- list (
        timestamp = get_timestamp (doc),
        OSM_version = get_osm_version (doc),
        overpass_version = get_overpass_version (doc)
    )

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
            if (!is_datetime (meta$datetime_to)) { # adiff opq without datetime2
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
                "action" %in% xml2::xml_name (xml2::xml_children (doc))) {
                meta$query_type <- "adiff"
            } else {
                meta$query_type <- "diff"
            }

        } else if (!is.null (attr (q, "datetime"))) {

            if (grepl ("adiff", q$prefix) ||
                "action" %in% xml2::xml_name (xml2::xml_children (doc))) {
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

    } else { # is.null (q)

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

#' Make an 'sf' object from an 'sfc' list and associated data matrix returned
#' from 'rcpp_osmdata_sf'
#'
#' @param ... list of objects, at least one of which must be of class 'sfc'
#' @param stringsAsFactors Should character strings in 'sf' 'data.frame' be
#' coerced to factors?
#' @return An object of class `sf`
#'
#' @note Most of this code written by Edzer Pebesma, and taken from
#' <https://github.com/edzer/sfr/blob/master/R/agr.R> and
#' <https://github.com/edzer/sfr/blob/master/R/sfc.R>
#'
#' @noRd
make_sf <- function (..., stringsAsFactors = FALSE) { # nolint

    x <- list (...)
    sf <- vapply (x, function (i) inherits (i, "sfc"),
        FUN.VALUE = logical (1)
    )
    sf_column <- which (sf)

    if (!is.null (names (x [[sf_column]]))) {
        row_names <- names (x [[sf_column]])
    } else {
        row_names <- seq_along (x [[sf_column]])
    }

    df <- if (length (x) == 1) { # ONLY sfc
        data.frame (row.names = row_names)
    } else { # create a data.frame from list:
        data.frame (x [-sf_column],
            row.names = row_names,
            stringsAsFactors = stringsAsFactors
        )
    }

    object <- as.list (substitute (list (...))) [-1L]
    arg_nm <- sapply (object, function (x) deparse (x)) # nolint
    sfc_name <- make.names (arg_nm [sf_column])
    # sfc_name <- "geometry"

    df [[sfc_name]] <- x [[sf_column]]
    attr (df, "sf_column") <- sfc_name
    f <- factor (rep (NA_character_, length.out = ncol (df) - 1),
        levels = c ("constant", "aggregate", "identity")
    )
    names (f) <- names (df) [-ncol (df)]
    attr (df, "agr") <- f
    class (df) <- c ("sf", class (df))

    return (df)
}

sf_types <- c ("points", "lines", "polygons", "multilines", "multipolygons")

#' Return an OSM Overpass query as an \link{osmdata} object in \pkg{sf}
#' format.
#'
#' @inheritParams osmdata_sp
#' @param stringsAsFactors Should character strings in 'sf' 'data.frame' be
#' coerced to factors?
#' @return An object of class `osmdata` with the OSM components (points, lines,
#'         and polygons) represented in \pkg{sf} format.
#'
#' @family extract
#' @export
#'
#' @examples
#' \dontrun{
#' hampi_sf <- opq ("hampi india") %>%
#'     add_osm_feature (key = "historic", value = "ruins") %>%
#'     osmdata_sf ()
#' }
osmdata_sf <- function (q, doc, quiet = TRUE, stringsAsFactors = FALSE) { # nolint

    obj <- osmdata () # uses class def

    if (missing (q)) {
        if (missing (doc)) {
            stop (
                'arguments "q" and "doc" are missing, with no default. ',
                "At least one must be provided."
            )
        }
        if (!quiet) {
            message ("q missing: osmdata object will not include query")
        }
    } else if (is (q, "overpass_query")) {
        obj$bbox <- q$bbox
        obj$overpass_call <- opq_string_intern (q, quiet = quiet)
    } else if (is.character (q)) {
        obj$overpass_call <- q
    } else {
        stop ("q must be an overpass query or a character string")
    }

    temp <- fill_overpass_data (obj, doc, quiet = quiet)
    obj <- temp$obj
    doc <- temp$doc

    if (!quiet) {
        message ("converting OSM data to sf format")
    }
    res <- rcpp_osmdata_sf (paste0 (doc))
    # some objects don't have names. As explained in
    # src/osm_convert::restructure_kv_mat, these instances do not get an osm_id
    # column, so this is appended here:
    if (!"osm_id" %in% names (res$points_kv)) {
        res <- fill_kv (res, "points_kv", "points", stringsAsFactors)
    }
    if (!"osm_id" %in% names (res$polygons_kv)) {
        res <- fill_kv (res, "polygons_kv", "polygons", stringsAsFactors)
    }

    if (missing (q)) {
        obj$bbox <- paste (res$bbox, collapse = " ")
    }

    for (ty in sf_types) {
        obj <- fill_objects (
            res,
            obj,
            type = ty,
            stringsAsFactors = stringsAsFactors
        )
    }

    class (obj) <- c (class (obj), "osmdata_sf")

    return (obj)
}

fill_kv <- function (res, kv_name, g_name, stringsAsFactors) { # nolint

    if (!"osm_id" %in% names (res [[kv_name]])) {

        if (nrow (res [[kv_name]]) == 0) {
            res [[kv_name]] <- data.frame (
                osm_id = names (res [[g_name]]),
                stringsAsFactors = stringsAsFactors
            )
        } else {
            res [[kv_name]] <- data.frame (
                osm_id = rownames (res [[kv_name]]),
                res [[kv_name]],
                stringsAsFactors = stringsAsFactors
            )
        }
    }

    return (res)
}

fill_objects <- function (res, obj, type = "points",
                          stringsAsFactors = FALSE) { # nolint

    if (!type %in% sf_types) {
        stop ("type must be one of ", paste (sf_types, collapse = " "))
    }

    geometry <- res [[type]]
    obj_name <- paste0 ("osm_", type)
    kv_name <- paste0 (type, "_kv")

    if (length (res [[kv_name]]) > 0) {

        if (!stringsAsFactors) {
            res [[kv_name]] [] <- lapply (res [[kv_name]], as.character)
        }
        obj [[obj_name]] <- make_sf (
            geometry,
            res [[kv_name]],
            stringsAsFactors = stringsAsFactors
        )

    } else if (length (obj [[obj_name]]) > 0) {

        obj [[obj_name]] <- make_sf (
            geometry,
            stringsAsFactors = stringsAsFactors
        )
    }

    return (obj)
}

#' Return an OSM Overpass query as an \link{osmdata} object in
#' `silicate` (`SC`) format.
#'
#' @inheritParams osmdata_sp
#' @return An object of class `osmdata` representing the original OSM hierarchy
#'      of nodes, ways, and relations.
#'
#' @note The `silicate` format is currently highly experimental, and
#'      recommended for use only if you really know what you're doing.
#'
#' @family extract
#' @export
#'
#' @examples
#' \dontrun{
#' hampi_sf <- opq ("hampi india") %>%
#'     add_osm_feature (key = "historic", value = "ruins") %>%
#'     osmdata_sc ()
#' }
osmdata_sc <- function (q, doc, quiet = TRUE) {

    obj <- osmdata () # class def used here to for fill_overpass_data fn

    if (missing (q)) {
        if (missing (doc)) {
            stop (
                'arguments "q" and "doc" are missing, with no default. ',
                "At least one must be provided."
            )
        }
        if (!quiet) {
            message ("q missing: osmdata object will not include query")
        }
    } else if (is (q, "overpass_query")) {
        obj$bbox <- q$bbox
        obj$overpass_call <- opq_string_intern (q, quiet = quiet)
    } else if (is.character (q)) {
        obj$overpass_call <- q
    } else {
        stop ("q must be an overpass query or a character string")
    }

    temp <- fill_overpass_data (obj, doc, quiet = quiet)
    obj <- temp$obj
    doc <- temp$doc

    if (!quiet) {
        message ("converting OSM data to sc format")
    }

    res <- rcpp_osmdata_sc (paste0 (doc))

    if (nrow (res$object_link_edge) > 0L) {
        res$object_link_edge$native_ <- TRUE
    }

    obj <- list () # SC **does not** use osmdata class definition
    obj$nodes <- tibble::as_tibble (res$nodes)
    obj$relation_members <- tibble::as_tibble (res$relation_members)
    obj$relation_properties <- tibble::as_tibble (res$relation_properties)
    obj$object <- tibble::as_tibble (res$object)
    obj$object_link_edge <- tibble::as_tibble (res$object_link_edge)
    obj$edge <- tibble::as_tibble (res$edge)
    obj$vertex <- tibble::as_tibble (res$vertex)
    obj$meta <- tibble::tibble (
        proj = NA_character_,
        ctime = temp$obj$meta$timestamp,
        OSM_version = temp$obj$meta$OSM_version,
        overpass_version = temp$obj$meta$overpass_version
    )

    if (!missing (q)) {
        if (!is.character (q)) {
            obj$meta$bbox <- q$bbox
        }
    } else {
        obj$meta$bbox <- bbox_to_string (obj)
    }

    attr (obj, "join_ramp") <- c (
        "nodes",
        "relation_members",
        "relation_properties",
        "object",
        "object_link_edge",
        "edge",
        "vertex"
    )
    attr (obj, "class") <- c ("SC", "sc", "osmdata_sc")

    return (obj)
}

getbb_sc <- function (x) {

    apply (x$vertex [, 1:2], 2, range) %>%
        bbox_to_string ()
}

#' Return an OSM Overpass query as a \link{data.frame} object.
#'
#'
#' @inheritParams osmdata_sp
#' @param q An object of class `overpass_query` constructed with
#'      \link{opq} and \link{add_osm_feature}. May be be omitted,
#'      in which case the attributes of the \link{data.frame} will not include
#'      the query.
#' @param stringsAsFactors Should character strings in the 'data.frame' be
#'      coerced to factors?
#' @return A `data.frame` with id, type and tags of the the objects from the
#'      query.
#'
#' @details If you are not interested in the geometries of the results, it's a
#'      good option to query for objects that match the features only and forget
#'      about members of the ways and relations. You can achieve this by passing
#'      the parameter `body = "tags"` to \code{\link{opq}}.
#'
#' @family extract
#' @export
#'
#' @examples
#' \dontrun{
#' hampi_df <- opq ("hampi india") %>%
#'     add_osm_feature (key = "historic", value = "ruins") %>%
#'     osmdata_data_frame ()
#' attr (hampi_df, "bbox")
#' attr (hampi_df, "overpass_call")
#' attr (hampi_df, "meta")
#' }
osmdata_data_frame <- function (q,
                                doc,
                                quiet = TRUE,
                                stringsAsFactors = FALSE) {

    obj <- osmdata () # uses class def

    if (missing (q)) {
        if (missing (doc)) {
            stop (
                'arguments "q" and "doc" are missing, with no default. ',
                "At least one must be provided."
            )
        }
        if (!quiet) {
            message ("q missing: osmdata object will not include query")
        }
    } else if (is (q, "overpass_query")) {
        obj$bbox <- q$bbox
        obj$overpass_call <- opq_string_intern (q, quiet = quiet)
    } else if (is.character (q)) {
        obj$overpass_call <- q
    } else {
        stop ("q must be an overpass query or a character string")
    }

    temp <- fill_overpass_data (obj, doc, quiet = quiet)
    obj <- temp$obj
    doc <- temp$doc

    if (!quiet) {
        message ("converting OSM data to a data.frame")
    }

    if (isTRUE (obj$meta$query_type == "adiff")) {
        datetime_from <- obj$meta$datetime_from
        if (is.null (datetime_from)) datetime_from <- "old"
        datetime_to <- obj$meta$datetime_to
        if (is.null (datetime_to)) datetime_to <- "new"
        df <- xml_adiff_to_df (doc,
            datetime_from = datetime_from, datetime_to = datetime_to,
            stringsAsFactors = stringsAsFactors
        )
    } else {
        df <- xml_to_df (doc, stringsAsFactors = stringsAsFactors)
        if (isTRUE (obj$meta$query_type == "diff")) {
            df <- unique (df)
        }
    }
    attr (df, "bbox") <- obj$bbox
    attr (df, "overpass_call") <- obj$overpass_call
    attr (df, "meta") <- obj$meta

    return (df)
}

xml_to_df <- function (doc, stringsAsFactors = FALSE) {

    res <- rcpp_osmdata_df (paste0 (doc))

    if (nrow (res$points_kv) > 0L) {
        res$points_kv$osm_type <- "node"
        res$points_kv <- cbind (
            get_meta_from_cpp_output (res, "points"),
            res$points_kv
        )
    }
    if (nrow (res$ways_kv) > 0L) {
        res$ways_kv$osm_type <- "way"
        res$ways_kv$osm_id <- rownames (res$ways_kv)
        res$ways_kv <- cbind (
            get_meta_from_cpp_output (res, "ways"),
            res$ways_kv
        )
    }
    if (nrow (res$rels_kv) > 0L) {
        res$rels_kv$osm_type <- "relation"
        res$rels_kv$osm_id <- rownames (res$rels_kv)
        res$rels_kv <- cbind (
            get_meta_from_cpp_output (res, "rels"),
            res$rels_kv
        )
    }

    nms <- sort (unique (unlist (lapply (res [1:3], names))))
    nms1 <- c (
        "osm_type", "osm_id",
        paste0 (
            "osm_",
            c ("version", "timestamp", "changeset", "uid", "user")
        )
    )
    nms1 <- intersect (nms1, nms)
    nms <- c (nms1, setdiff (nms, nms1))

    df <- lapply (res [1:3], function (i) {
        out <- data.frame (
            matrix (nrow = nrow (i), ncol = length (nms)),
            stringsAsFactors = stringsAsFactors
        )
        names (out) <- nms
        out [, names (i)] <- i
        rownames (out) <- rownames (i)
        return (out)
    })
    df <- do.call (rbind, df)
    rownames (df) <- NULL

    if (nrow (df) == 0) {
        df <- data.frame (
            osm_type = character (),
            osm_id = character (),
            stringsAsFactors = stringsAsFactors
        )
    }

    return (df)
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


xml_adiff_to_df <- function (doc,
                             datetime_from,
                             datetime_to,
                             stringsAsFactors = FALSE) {

    osm_actions <- xml2::xml_find_all (doc, ".//action")

    if (length (osm_actions) == 0) {
        return (data.frame (
            osm_type = character (), osm_id = character (),
            adiff_action = character (), adiff_date = character (),
            adiff_visible = character (),
            stringsAsFactors = stringsAsFactors
        ))
    }

    osm_obj <- xml2::xml_find_all (osm_actions, ".//node|.//way|.//relation")

    tags_u <- xml2::xml_find_all (osm_actions, xpath = ".//tag")
    col_names <- sort (unique (xml2::xml_attr (tags_u, attr = "k")))
    m <- matrix (
        nrow = length (osm_obj), ncol = length (col_names),
        dimnames = list (NULL, col_names)
    )

    tags <- xml2::xml_find_all (osm_obj, xpath = ".//tag", flatten = FALSE)
    has_tags <- which (vapply (tags, length, FUN.VALUE = integer (1)) > 0)
    for (i in has_tags) {
        tag <- xml2::xml_attrs (tags [[i]])
        tagV <- vapply (tag, function (x) x, FUN.VALUE = character (2))
        m [i, tagV [1, ]] <- tagV [2, ]
    }

    osm_type <- xml2::xml_name (osm_obj)
    osm_id <- xml2::xml_attr (osm_obj, "id")

    action_type <- xml2::xml_attr (osm_actions, "type")
    adiff_action <- lapply (action_type, function (x) {
        if (x != "create") {
            x <- rep (x, 2)
        }
        x
    })
    adiff_action <- do.call (c, adiff_action)

    adiff_date <- lapply (action_type, function (x) {
        if (x == "create") {
            x <- datetime_to
        } else {
            x <- c (datetime_from, datetime_to)
        }
        x
    })
    adiff_date <- do.call (c, adiff_date)

    adiff_visible <- xml2::xml_attr (osm_obj, "visible")
    adiff_visible [which (adiff_visible == "false")] <- FALSE
    adiff_visible [which (adiff_visible == "true")] <- TRUE

    if (all (xml2::xml_has_attr (
        osm_obj,
        c ("version", "timestamp", "changeset", "uid", "user")
    ))
    ) {

        osm_version <- xml2::xml_attr (osm_obj, attr = "version")
        osm_timestamp <- xml2::xml_attr (osm_obj, attr = "timestamp")
        osm_changeset <- xml2::xml_attr (osm_obj, attr = "changeset")
        osm_uid <- xml2::xml_attr (osm_obj, attr = "uid")
        osm_user <- xml2::xml_attr (osm_obj, attr = "user")

        df <- data.frame (osm_type, osm_id, osm_version, osm_timestamp,
            osm_changeset, osm_uid, osm_user,
            adiff_action, adiff_date, adiff_visible, m,
            stringsAsFactors = stringsAsFactors, check.names = FALSE
        )

    } else {
        df <- data.frame (osm_type, osm_id,
            adiff_action, adiff_date, adiff_visible, m,
            stringsAsFactors = stringsAsFactors, check.names = FALSE
        )
    }

    return (df)
}
