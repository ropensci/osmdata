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

    if (is.character (doc)) {
        header <- is.null (obj$overpass_call) ||
            !grepl ("\\[out:csv\\(.+; false\\)\\]", obj$overpass_call)
        # Values containing `,` | `"` get quoted with `"`. `"` in values -> `""`
        df <- utils::read.table (
            text = doc,
            header = header,
            sep = "\t",
            quote = "\"",
            na.strings = "",
            colClasses = "character", # osm_id doesn't fit in integer
            check.names = FALSE,
            comment.char = "",
            stringsAsFactors = stringsAsFactors
        )
    } else if (isTRUE (obj$meta$query_type == "adiff")) {
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

    if (!is.null (obj$overpass_call) &&
        !grepl (" center;$", obj$overpass_call)
    ) {
        df [, c ("osm_center_lat", "osm_center_lon")] <- NULL
    }

    attr (df, "bbox") <- obj$bbox
    attr (df, "overpass_call") <- obj$overpass_call
    attr (df, "meta") <- obj$meta

    return (df)
}


xml_to_df <- function (doc, stringsAsFactors = FALSE) {

    res <- rcpp_osmdata_df (paste0 (doc))

    keysL <- lapply (c ("points_kv", "ways_kv", "rels_kv"), function (x) {
        out <- names (res [[x]])
        if (isTRUE (out [1] == "osm_id")) {
            out <- out [-1] # remove osm_id. Not always present
        }
        out
    })
    keys <- sort (unique (unlist (keysL)))

    tags <- mapply (function (i, k) {
        i <- i [, k, drop = FALSE] # remove osm_id column if exists
        out <- data.frame (
            matrix (
                nrow = nrow (i), ncol = length (keys),
                dimnames = list (NULL, keys)
            ),
            stringsAsFactors = stringsAsFactors,
            check.names = FALSE
        )
        out [, names (i)] <- i
        return (out)
    }, i = res [1:3], k = keysL, SIMPLIFY = FALSE)

    center <- lapply (c ("points", "ways", "rels"), function (type) {
        get_center_from_cpp_output (res, type)
    })
    missing_center <- vapply (center, function (x) {
        ncol (x) == 0 & nrow (x) > 0
    }, FUN.VALUE = logical (1))
    if (any (missing_center)) { # not a "out * center;" query
        center <- lapply (center, function (x) {
            x [, c ("osm_center_lat", "osm_center_lon")] <- NULL
            x
        })
    }

    meta <- lapply (c ("points", "ways", "rels"), function (type) {
        get_meta_from_cpp_output (res, type)
    })

    df <- lapply (1:3, function (i) {
        osm_type <- if (nrow (res [[i]]) > 0) {
            c ("node", "way", "relation") [i]
        } else {
            character ()
        }
        data.frame (
            osm_type,
            osm_id = rownames (res [[i]]),
            center [[i]],
            meta [[i]],
            tags [[i]],
            stringsAsFactors = stringsAsFactors,
            check.names = FALSE
        )
    })

    df <- do.call (rbind, c (df, list (deparse.level = 0)))
    rownames (df) <- NULL

    cols_no_dup <- fix_duplicated_columns (names (df))
    if (!identical (names (df), cols_no_dup)) {
        warning (
            "Feature keys clash with id or metadata columns and will be ",
            "renamed by appending `.n`:\n\t",
            paste (setdiff (cols_no_dup, names (df)), collapse = ", ")
        )
        names (df) <- cols_no_dup
    }

    if (nrow (df) == 0) {
        df <- data.frame (
            osm_type = character (),
            osm_id = character (),
            stringsAsFactors = stringsAsFactors
        )
    }

    return (df)
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

    center <- get_center_from_xml (osm_obj)
    meta <- get_meta_from_xml (osm_obj)

    df <- data.frame (
        osm_type, osm_id, center, meta,
        adiff_action, adiff_date, adiff_visible, m,
        stringsAsFactors = stringsAsFactors, check.names = FALSE
    )

    return (df)
}


get_center_from_xml <- function (osm_obj) {
    centers <- xml2::xml_find_all (
        osm_obj,
        xpath = ".//center",
        flatten = FALSE
    )
    has_center <- vapply (centers, length, FUN.VALUE = integer (1)) > 0
    if (any (has_center) ||
        all (xml2::xml_has_attr (osm_obj, c ("lat", "lon")))
    ) {

        osm_center_lat_nodes <- xml2::xml_attr (osm_obj, attr = "lat")
        osm_center_lon_nodes <- xml2::xml_attr (osm_obj, attr = "lon")

        osm_center_lat <- vapply (centers, function (x) {
            lat <- xml2::xml_attr (x, attr = "lat")
            ifelse (length (lat) == 0, NA_character_, lat)
        }, FUN.VALUE = character (1))
        osm_center_lon <- vapply (centers, function (x) {
            lon <- xml2::xml_attr (x, attr = "lon")
            ifelse (length (lon) == 0, NA_character_, lon)
        }, FUN.VALUE = character (1))

        osm_center_lat <- ifelse (
            is.na (osm_center_lat),
            osm_center_lat_nodes,
            osm_center_lat
        )
        osm_center_lon <- ifelse (
            is.na (osm_center_lon),
            osm_center_lat_nodes,
            osm_center_lon
        )

        out <- data.frame (
            osm_center_lat = as.numeric (osm_center_lat),
            osm_center_lon = as.numeric (osm_center_lon)
        )
    } else {
        out <- matrix (nrow = length (osm_obj), ncol = 0)
    }

    return (out)
}


get_meta_from_xml <- function (osm_obj) {
    if (all (xml2::xml_has_attr (
        osm_obj,
        c ("version", "timestamp", "changeset", "uid", "user")
    ))
    ) {

        out <- data.frame (
            osm_version = xml2::xml_attr (osm_obj, attr = "version"),
            osm_timestamp = xml2::xml_attr (osm_obj, attr = "timestamp"),
            osm_changeset = xml2::xml_attr (osm_obj, attr = "changeset"),
            osm_uid = xml2::xml_attr (osm_obj, attr = "uid"),
            osm_user = xml2::xml_attr (osm_obj, attr = "user")
        )

    } else {
        out <- matrix (nrow = length (osm_obj), ncol = 0)
    }

    return (out)
}
