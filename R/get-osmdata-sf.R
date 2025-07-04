#' Return an OSM Overpass query as an \link{osmdata} object in \pkg{sf}
#' format.
#'
#' @note In 'dplyr'-type workflows in which the output of this function is
#' piped to other functions, it will generally be necessary to explicitly load
#' the \pkg{sf} package into the current workspace with 'library(sf)'.
#'
#' @param q An object of class `overpass_query` constructed with
#'      \link{opq} and \link{add_osm_feature} or a string with a valid query, such
#'      as `"(node(39.4712701,-0.3841326,39.4713799,-0.3839475);); out;"`.
#'      39.4712701,-0.3841326,39.4713799,-0.3839475
#'      May be be omitted, in which case the \link{osmdata} object will not
#'      include the query. See examples below.
#' @param doc If missing, `doc` is obtained by issuing the overpass query,
#'        `q`, otherwise either the name of a file from which to read data,
#'        or an object of class \pkg{xml2} returned from \link{osmdata_xml}.
#' @param quiet suppress status messages.
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
#' query <- opq ("hampi india") |>
#'     add_osm_feature (key = "historic", value = "ruins")
#' # Then extract data from 'Overpass' API
#' hampi_sf <- osmdata_sf (query)
#' }
#'
#' # Complex query as a string (not possible with regular osmdata functions)
#' q <- '[out:xml][timeout:50];
#'     area[name="Països Catalans"][boundary=political]->.boundaryarea;
#'
#'     rel(area.boundaryarea)[admin_level=8][boundary=administrative];
#'     map_to_area -> .all_level_8_areas;
#'
#'     ( nwr(area.boundaryarea)[amenity=townhall]; >; );
#'     is_in;
#'     area._[admin_level=8][boundary=administrative] -> .level_8_areas_with_townhall;
#'
#'     (.all_level_8_areas; - .level_8_areas_with_townhall;);
#'     rel(pivot);
#'     (._; >;);
#'     out;'
#'
#' \dontrun{
#' no_townhall <- osmdata_sf (q)
#' no_townhall
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

    check_not_implemented_queries (obj)

    temp <- fill_overpass_data (obj, doc, quiet = quiet)
    obj <- temp$obj
    doc <- temp$doc

    if (isTRUE (obj$meta$query_type == "adiff")) {
        stop ("adiff queries not yet implemented.")
    }

    if (!quiet) {
        message ("converting OSM data to sf format")
    }
    res <- rcpp_osmdata_sf (paste0 (doc))
    # some objects don't have names. As explained in
    # src/osm_convert::restructure_kv_mat, these instances do not get an osm_id
    # column (the first one), so this is appended here:
    if (!"osm_id" %in% names (res$points_kv) [1]) {
        res <- fill_kv (res, "points_kv", "points", stringsAsFactors)
    }
    if (!"osm_id" %in% names (res$polygons_kv) [1]) {
        res <- fill_kv (res, "polygons_kv", "polygons", stringsAsFactors)
    }
    kv_df <- grep ("_kv$", names (res)) # objects with tags
    res [kv_df] <- fix_columns_list (res [kv_df])
    res [kv_df] <- lapply (res [kv_df], setenc_utf8)

    if (missing (q)) {
        obj$bbox <- paste (res$bbox, collapse = " ")
    }

    for (ty in sf_types) {
        obj <- fill_sf_objects (
            res,
            obj,
            type = ty,
            stringsAsFactors = stringsAsFactors
        )
    }

    class (obj) <- c (class (obj), "osmdata_sf")

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
            stringsAsFactors = stringsAsFactors,
            check.names = FALSE
        )
    }

    df <- merge_duplicated_col_names (df)

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

#' Merge any `sf` `data.frame` columns which have mixed-case duplicated names
#' (like "This" and "this"; #348).
#'
#' @param df a `data.frame`
#' @return Returns the `df` without duplicated columnms. If both values in a
#'   row of the duplicated columns are not NA, use the value of the first column.
#'
#' @noRd
merge_duplicated_col_names <- function (df) {

    nms_lower <- tolower (names (df))
    dups <- which (duplicated (nms_lower))
    if (length (dups) > 0L) {
        dup_nms <- nms_lower [dups]
        cols_to_rm <- NULL
        for (nm in dup_nms) {
            index <- which (nms_lower == nm)
            df [, index [1]] <- apply (df [, index], 1, function (i) {
                ifelse (all (is.na (i)), i [1], i [which (!is.na (i)) [1]])
            })
            cols_to_rm <- c (cols_to_rm, index [2])
        }
        df <- df [, -(cols_to_rm)]
    }

    return (df)
}


sf_types <- c ("points", "lines", "polygons", "multilines", "multipolygons")


fill_kv <- function (res, kv_name, g_name, stringsAsFactors) { # nolint

    if (!"osm_id" %in% names (res [[kv_name]])) {

        if (nrow (res [[kv_name]]) == 0) {
            res [[kv_name]] <- data.frame (
                osm_id = names (res [[g_name]]),
                stringsAsFactors = stringsAsFactors,
                check.names = FALSE
            )
        } else {
            res [[kv_name]] <- data.frame (
                osm_id = rownames (res [[kv_name]]),
                res [[kv_name]],
                stringsAsFactors = stringsAsFactors,
                check.names = FALSE
            )
        }
    }

    return (res)
}


fill_sf_objects <- function (res, obj, type = "points",
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
