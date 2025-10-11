#' Convert a named matrix or a named or unnamed vector or data.frame to a string
#'
#' This function converts a bounding box into a string for use in web apis
#'
#' @param bbox bounding box as character, matrix, vector or a data.frame with
#' `osm_type` and `osm_id` columns.
#' If character, the bbox will be found (geocoded) and extracted with
#' \link{getbb}. Unnamed vectors will be sorted appropriately and must merely be
#' in the order (x, y, x, y).
#'
#' @return A character string representing min x, min y, max x, and max y
#' bounds. For example: \code{"15.3152361,76.4406446,15.3552361,76.4806446"} is
#' the bounding box for Hampi, India. For data.frames with OSM objects, a
#' character string representing a set of OSM objects in overpass query
#' language. For example: `"relation(id:11747082)"` represents the area of
#' the Catalan Countries. A set of objects can also be represented for multirow
#' data.frames (e.g. `"relation(id:11747082,307833); way(id:22422490)"`).
#'
#' @family queries
#' @export
#'
#' @examples
#' # Note input is (lon, lat) = (x, y) but output as needed for 'Overpass' API
#' # is (lat, lon) = (y, x).
#' bb <- c (-0.4325512, 39.2784496, -0.2725205, 39.566609)
#' bbox_to_string (bb)
#' # This is equivalent to:
#' \dontrun{
#' bbox_to_string (getbb ("València"))
#' bbox_to_string (getbb ("València", format_out = "data.frame"))
#' }
bbox_to_string <- function (bbox) {

    if (missing (bbox)) stop ("bbox must be provided")

    if (is.character (bbox)) {
        if (grepl ("(node|way|relation|rel)\\(id:[0-9, ]+\\)", bbox)) {
            return (bbox)
        } else {
            bbox <- getbb (bbox)
        }
    }

    if (inherits (bbox, "data.frame")) {

        if (!all (c ("osm_type", "osm_id") %in% names (bbox))) {
            stop (
                "bbox must be a data.frame with osm_type and osm_id columns as ",
                "in:\n\t getbb(..., format_out = \"data.frame\")."
            )
        }

        type_id <- split (bbox$osm_id, bbox$osm_type)
        id <- mapply (function (type, ids) {
            paste0 (type, "(id:", paste (ids, collapse = ","), ")")
        }, type = names (type_id), ids = type_id)

        return (paste (id, collapse = "; "))

    }

    if (is.list (bbox)) {
        bbox <- bb_poly_to_mat (bbox)
    }

    if (!is.numeric (bbox)) stop ("bbox must be numeric")

    if (inherits (bbox, "matrix")) {
        if (nrow (bbox) > 2) {
            bbox <- apply (bbox, 2, range)
        }

        if (all (c ("x", "y") %in% tolower (rownames (bbox))) &
            all (c ("min", "max") %in% tolower (colnames (bbox)))) {
            bbox <- c (
                bbox ["y", "min"], bbox ["x", "min"],
                bbox ["y", "max"], bbox ["x", "max"]
            )
        } else if (all (c ("coords.x1", "coords.x2") %in% rownames (bbox)) &
            all (c ("min", "max") %in% colnames (bbox))) {
            bbox <- c (
                bbox ["coords.x2", "min"], bbox ["coords.x1", "min"],
                bbox ["coords.x2", "max"], bbox ["coords.x1", "max"]
            )
        } else {
            # otherwise just presume (x,y) are columns and order the rows
            bbox <- c (
                min (bbox [, 2]), min (bbox [, 1]),
                max (bbox [, 2]), max (bbox [, 1])
            )
        }
    } else {
        if (length (bbox) < 4) {
            stop ("bbox must contain four elements")
        } else if (length (bbox) > 4) {
            message ("only the first four elements of bbox used")
        }

        if (!is.null (names (bbox)) &
            all (names (bbox) %in% c ("left", "bottom", "right", "top"))) {
            bbox <- bbox [c ("bottom", "left", "top", "right")]
        } else {
            x <- sort (bbox [c (1, 3)])
            y <- sort (bbox [c (2, 4)])
            bbox <- c (y [1], x [1], y [2], x [2])
        }
    }

    if (any (is.na (bbox))) {
        stop ("bbox contains 'NA' values")
    }

    return (paste0 (bbox, collapse = ","))
}

#' Get bounding box for a given place name
#'
#' This function uses the free Nominatim API provided by OpenStreetMap to find
#' the bounding box (bb) associated with place names.
#'
#' It was inspired by the functions
#' `bbox` from the \pkg{sp} package,
#' `bb` from the \pkg{tmaptools} package and
#' `bb_lookup` from the github package \pkg{nominatim} package,
#' which can be found at <https://github.com/hrbrmstr/nominatim>.
#'
#' See <https://wiki.openstreetmap.org/wiki/Nominatim> for details.
#'
#' @param place_name The name of the place you're searching for or a wikidata
#'   id. For Wikidata, only `format_out`, `base_url` and `silent` are used; all
#'   other parameters are ignored.
#' @param display_name_contains Text string to match with display_name field
#'   returned by <https://wiki.openstreetmap.org/wiki/Nominatim>.
#' @param viewbox Focuses the search on the given area defined as
#'   a character string `"x1,y1,x2,y2"` or `c(x1, y1, x2, y2)`. Any two corner
#'   points of the box are accepted as long as they make a proper box. `x` is
#'   longitude, `y` is latitude.
#' @param format_out Character string indicating output format: `matrix`
#'   (default), `string` (see [bbox_to_string()]),
#'   `data.frame` (all 'hits' returned by Nominatim),
#'   `sf_polygon` (for polygons that work with the sf package),
#'   `polygon` (full polygonal bounding boxes for each match) or
#'   `osm_type_id` (string for quering inside deffined OSM areas
#'   [bbox_to_string()]).
#' @param base_url Base website from where data is queried.
#' @param featuretype The type of OSM feature (settlement is default; see Note).
#' @param limit How many results should the API return?
#' @param key The API key to use for services that require it.
#' @param silent Should the API be printed to screen? `TRUE` by default.
#'
#' @return For `format_out = "matrix"`, the default, return the bounding box:
#' ```
#'   min   max
#' x ...   ...
#' y ...   ...
#' ```
#'
#' If `format_out = "polygon"`, a list of polygons and multipolygons with one
#' item for each `nominatim` result. The items are named with the OSM type and
#' id. Each polygon is formed by one or more two-columns matrices of polygonal
#' longitude-latitude points. The first matrix represents the outer boundary and
#' the next ones represent holes. See examples below for illustration.
#'
#' If `format_out = "sf_polygon"`, a `sf` object. Each row correspond to a
#' `place_name` within `nominatim` result.
#'
#' For `format_out = "osm_type_id"`, a character string representing an OSM
#' object in overpass query language. For example:
#' `"relation(id:11747082)"` represents the area of the Catalan Countries.
#' If one exact match exists with potentially multiple polygonal boundaries,
#' only the first relation or way is returned. A set of objects can also be
#' represented for multiple results (e.g.
#' `relation(id:11747082,307833); way(id:22422490)`). See examples below for
#' illustration. The OSM objects that can be used as
#' [areas in overpass queries](https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL#Map_way/relation_to_area_(map_to_area))
#' \emph{must be closed rings} (ways or relations).
#'
#' @note Specific values of `featuretype` include "street", "city",
# " "county", "state", and "country" (see
#' <https://wiki.openstreetmap.org/wiki/Nominatim> for details). The default
#' `featuretype = "settlement"` combines results from all intermediate
#' levels below "country" and above "streets". If the bounding box or polygon of
#' a city is desired, better results will usually be obtained with
#' `featuretype = "city"`.
#'
#' @family queries
#' @export
#'
#' @examples
#' \dontrun{
#' getbb ("Salzburg")
#' # Select based on display_name, print query url
#' getbb ("Hereford", display_name_contains = "United States", silent = FALSE)
#' # top 3 matches as data frame
#' getbb ("Hereford", format_out = "data.frame", limit = 3)
#' getbb ("Hereford", format_out = "data.frame", viewbox = getbb ("England"))
#'
#' # Examples of polygonal boundaries
#' bb <- getbb ("Milano, Italy", format_out = "polygon")
#' # A polygon and a multipolygon:
#' str (bb) # matrices of longitude/latitude pairs
#'
#' bb_sf <- getbb ("kathmandu", format_out = "sf_polygon")
#' bb_sf
#' # sf:::plot.sf(bb_sf) # can be plotted if sf is installed
#' getbb ("london", format_out = "sf_polygon")
#'
#' getbb ("València", format_out = "osm_type_id")
#' # Select multiple areas with format_out = "osm_type_id"
#' areas <- getbb ("València", format_out = "data.frame")
#' bbox_to_string (areas [areas$osm_type != "node", ])
#'
#' # Search by wikidata id (València)
#' getbb ("Q5720", format_out = "data.frame")
#'
#' # Using an alternative service (locationiq requires an API key)
#' # add LOCATIONIQ=type_your_api_key_here to .Renviron:
#' key <- Sys.getenv ("LOCATIONIQ")
#' if (nchar (key) == 32) {
#'     getbb (place_name,
#'         base_url = "https://locationiq.org/v1/search.php",
#'         key = key
#'     )
#' }
#' }
getbb <- function (place_name,
                   display_name_contains = NULL,
                   viewbox = NULL,
                   format_out = c (
                       "matrix", "data.frame", "string",
                       "polygon", "sf_polygon", "osm_type_id"
                   ),
                   base_url = "https://nominatim.openstreetmap.org",
                   featuretype = "settlement",
                   limit = 10,
                   key = NULL,
                   silent = TRUE) {

    format_out <- match.arg (format_out)
    is_polygon <- grepl ("polygon", format_out)

    if (grepl ("^Q[0-9]+$", place_name)) {
        rel_id <- get_wikidata_P402 (wikidata = place_name, silent = silent)

        if (is.null (rel_id)) {
            obj <- NULL
        } else {
            if (format_out == "osm_type_id") {
                return (paste0 ("relation(id:", rel_id, ")"))
            }

            obj <- get_nominatim_lookup (
                osm_type = "relation",
                osm_id = rel_id,
                is_polygon = is_polygon,
                base_url = base_url,
                silent = silent
            )
        }

    } else {
        obj <- get_nominatim_query (
            place_name = place_name,
            featuretype = featuretype,
            is_polygon = is_polygon,
            display_name_contains = display_name_contains,
            viewbox = viewbox,
            key = key,
            limit = limit,
            base_url = base_url,
            silent = silent
        )
    }

    if (length (obj) == 0) {
        warning (paste0 ("`place_name` '", place_name, "' can't be found"))

        ret <- getbb_empty (format_out)

        return (ret)
    }

    if (format_out == "data.frame") {
        utf8cols <- c ("licence", "name", "display_name")
        obj [, utf8cols] <- setenc_utf8 (obj [, utf8cols])
        return (obj)
    }

    if (format_out == "osm_type_id") {

        bbox <- obj [which (obj$osm_type %in% c ("relation", "way")) [1], ]
        if (nrow (bbox) == 0) {
            stop ("No area found for `place_name` ", place_name, ".")
        }

        return (bbox_to_string (bbox))
    }

    bn <- as.numeric (obj$boundingbox [[1]])
    bb_mat <- matrix (c (bn [3:4], bn [1:2]), nrow = 2, byrow = TRUE)
    dimnames (bb_mat) <- list (c ("x", "y"), c ("min", "max"))

    if (format_out == "matrix") {
        ret <- bb_mat
    } else if (format_out == "string") {
        ret <- bbox_to_string (bbox = bb_mat)

    } else if (is_polygon) {

        gt_p <- get_geotext_poly (obj)
        gt_mp <- get_geotext_multipoly (obj)

        if (format_out == "polygon") {

            gt <- c (gt_p, gt_mp)
            # multipolys below are not strict SF MULTIPOLYGONs, rather just
            # cases where nominatim returns lists of multiple items
            if (length (gt) == 0) {
                message (
                    "No polygonal boundary for ", place_name,
                    ". Returning the bounding box of the first result"
                )
                ret <- bb_mat
            } else {
                poly_id <- names (gt)
                obj_id <- paste0 (obj$osm_type, "/", obj$osm_id)
                obj_id <- intersect (obj_id, poly_id)
                # sort geometries following Nominatim order
                ord_poly <- match (obj_id, poly_id)
                ret <- gt [ord_poly]
            }
        } else if (format_out == "sf_polygon") {

            if (length (gt_p) + length (gt_mp) == 0) {
                message (
                    "No polygonal boundary for ", place_name,
                    ". Returning the bounding boxes."
                )
                ret_poly <- lapply (obj$boundingbox, function (x) {
                    x <- as.numeric (x)
                    bb_mat <- matrix (
                        c (x [3:4], x [1:2]),
                        nrow = 2, byrow = TRUE
                    )
                    mat2sf_poly (list (bb_mat))
                })
                ret_poly <- do.call (rbind, ret_poly)
                poly_id <- paste0 (obj$osm_type, "/", obj$osm_id)
            } else {
                ret_poly <- bb_as_sf_poly (gt_p, gt_mp)
                poly_id <- c (names (gt_p), names (gt_mp))
            }

            obj_id <- paste0 (obj$osm_type, "/", obj$osm_id)
            cols <- setdiff (names (obj), c ("boundingbox", "geotext"))
            ret <- obj [obj_id %in% poly_id, cols]
            obj_id <- intersect (obj_id, poly_id)

            utf8cols <- c ("licence", "name", "display_name")
            ret [, utf8cols] <- setenc_utf8 (ret [, utf8cols])

            # sort geometries following Nominatim order
            ord_poly <- match (obj_id, poly_id)
            geometry <- ret_poly$geometry [ord_poly]
            # sub-setting without 'sf' loaded removes attributes:
            attributes (geometry) <- attributes (ret_poly$geometry)

            ret <- make_sf (ret, geometry)
        }
    }

    return (ret)
}


#' getbb () result for empty queries
#'
#' @inheritParams getbb
#'
#' @returns Same structure as getbb () but empty results (0 lenght/nrows).
#' @noRd
#'
#' @examples
#' lapply (
#'     c (
#'         "matrix", "data.frame", "string",
#'         "polygon", "sf_polygon", "osm_type_id"
#'     ),
#'     getbb_empty
#' )
getbb_empty <- function (format_out) {
    ret <- switch (format_out,
        matrix = matrix (
            rep (NA_real_),
            nrow = 2, ncol = 2,
            dimnames = list (c ("x", "y"), c ("min", "max"))
        ),
        data.frame = {
            x <- data.frame (
                place_id = integer (), licence = character (),
                osm_type = character (), osm_id = integer (),
                lat = character (), lon = character (), class = character (),
                type = character (), place_rank = integer (),
                importance = numeric (), addresstype = character (),
                name = character (), display_name = character ()
            )
            x$boundingbox <- list ()
            x
        },
        string = character (),
        polygon = list (),
        sf_polygon = {
            geometry <- mat2sf_poly (list (matrix (rep (NA, 4), nrow = 2)))$geometry
            df <- data.frame (
                place_id = NA_integer_, licence = NA_character_,
                osm_type = NA_character_, osm_id = NA_integer_,
                lat = NA_character_, lon = NA_character_, class = NA_character_,
                type = NA_character_, place_rank = NA_integer_,
                importance = NA_real_, addresstype = NA_character_,
                name = NA_character_, display_name = NA_character_
            )
            x <- make_sf (df, geometry)
            x [integer (), ]
        },
        osm_type_id = character ()
    )

    return (ret)
}


# https://doc.wikimedia.org/Wikibase/master/js/rest-api/#/statements/getItemStatements
get_wikidata_P402 <- function (wikidata, silent = TRUE) {
    req <- httr2::request ("https://www.wikidata.org")
    req <- httr2::req_url_path (
        req, "w/rest.php/wikibase/v1/entities/items", wikidata, "statements"
    )
    req <- httr2::req_url_query (req, property = "P402")

    # Avoid error for responses missing items (status 400 or 404)
    req <- httr2::req_error (req, is_error = function (resp) FALSE)
    req <- httr2::req_retry (req, max_tries = 10L)

    if (!silent) {
        message (req$url)
    }

    resp <- httr2::req_perform (req)
    obj <- tryCatch (
        httr2::resp_body_json (resp, simplifyVector = TRUE),
        error = function (e) {
            # nocov start
            message (paste0 (
                "Wikidata did not respond as expected ",
                "(e.g. due to excessive use of their api). ",
                "Please try again.\n",
                "The url that failed was:\n", req$url
            ))
            # nocov end
        }
    )

    if (resp$status_code != 200) {
        warning (obj$message)
        rel_id <- NULL
    } else {
        rel_id <- obj$P402$value$content
    }

    return (rel_id)
}


# https://nominatim.org/release-docs/develop/api/Lookup/
get_nominatim_lookup <- function (osm_type, osm_id, is_polygon, base_url, silent = TRUE) {
    # https://nominatim.openstreetmap.org/lookup?osm_ids=[N|W|R]<value>,…,…,&<params>
    osm_type <- gsub ("^node$", "N", osm_type)
    osm_type <- gsub ("^way$", "W", osm_type)
    osm_type <- gsub ("^relation$", "R", osm_type)
    ids <- paste (paste0 (osm_type, osm_id), collapse = ",")

    req <- httr2::request (base_url)
    req <- httr2::req_url_path (req, "lookup")
    req <- httr2::req_url_query (req, osm_ids = ids)
    req <- httr2::req_url_query (req, format = "json", addressdetails = 0)

    if (is_polygon) {
        req <- httr2::req_url_query (req, polygon_text = 1)
    }

    req <- httr2::req_retry (req, max_tries = 10L)

    if (!silent) {
        message (req$url)
    }

    resp <- httr2::req_perform (req)
    obj <- tryCatch (
        httr2::resp_body_json (resp, simplifyVector = TRUE),
        error = function (e) {
            # nocov start
            message (paste0 (
                "Wikidata did not respond as expected ",
                "(e.g. due to excessive use of their api). ",
                "Please try again.\n",
                "The url that failed was:\n", req$url
            ))
            # nocov end
        }
    )
}


# https://nominatim.org/release-docs/develop/api/Search/
get_nominatim_query <- function (place_name,
                                 featuretype,
                                 is_polygon,
                                 display_name_contains,
                                 viewbox,
                                 key,
                                 limit,
                                 base_url,
                                 silent) {

    featuretype <- tolower (featuretype)

    if (base_url == "https://nominatim.openstreetmap.org") {
        base_url <- "https://nominatim.openstreetmap.org/search"
    }

    req <- httr2::request (base_url)
    req <- httr2::req_method (req, "GET")
    req <- httr2::req_url_query (req, format = "json")
    req <- httr2::req_url_query (req, q = place_name)
    req <- httr2::req_url_query (req, featuretype = featuretype)

    if (is_polygon) {
        req <- httr2::req_url_query (req, polygon_text = 1)
    }
    if (!is.null (viewbox)) {
        req <- httr2::req_url_query (
            req,
            viewbox = paste (viewbox, collapse = ",")
        )
    }
    if (!is.null (key)) {
        req <- httr2::req_url_query (req, key = key)
    }
    if (!is.null (limit)) {
        req <- httr2::req_url_query (req, limit = limit)
    }

    if (!silent) {
        message (req$url)
    }

    req <- httr2::req_retry (req, max_tries = 10L)

    resp <- httr2::req_perform (req)
    obj <- tryCatch (
        httr2::resp_body_json (resp, simplifyVector = TRUE),
        error = function (e) {
            # nocov start
            message (paste0 (
                "Nominatim did not respond as expected ",
                "(e.g. due to excessive use of their api).\n",
                "Please try again or use a different base_url\n",
                "The url that failed was:\n", req$url
            ))
            # nocov end
        }
    )

    # Code optionally select more things stored in obj...
    if (!is.null (display_name_contains)) {
        # nocov start
        obj <- obj [grepl (display_name_contains, obj$display_name), ]
        if (nrow (obj) == 0) {
            stop ("No locations include display name ", display_name_contains)
        }
        # nocov end
    }

    return (obj)
}


#' Get all polygons from a 'geojson' object
#'
#' @param obj A 'geojson' object
#' @return List of polygons. Each polygon is a list of matrices, the first
#'   defining the outer ring and the following ones, if present, define holes.
#' @noRd
get_geotext_poly <- function (obj) {

    . <- NULL # suppress R CMD check note

    index_final <- seq_len (nrow (obj))

    indx_multi <- grep ("MULTIPOLYGON", obj$geotext)
    gt_p <- NULL
    indx <- which (!(seq (nrow (obj)) %in% indx_multi))
    index_final <- index_final [indx]
    ptn <- "(POLYGON\\(\\()|(\\)\\))"
    gt_p <- gsub (ptn, "", obj$geotext [indx])
    gt_p <- strsplit (gt_p, split = ",")
    indx_na <- rev (which (is.na (gt_p)))
    for (i in indx_na) {
        gt_p [[i]] <- NULL
    }
    if (length (indx_na) > 0L) {
        index_final <- index_final [-indx_na]
    }

    # points and linestrings may be present in result, and will be prepended
    # by sf-standard prefixes, while (multi)polygons will have been stripped
    # to numeric values only.
    # TDOD: Do the following lines need to be repeated for _mp?
    indx <- which (vapply (
        gt_p, function (i) {
            substring (i [1], 1, 1) %in% c ("L", "P")
        },
        logical (1)
    ))
    if (length (indx) > 0) {
        gt_p <- gt_p [-indx]
        index_final <- index_final [-indx]
    }

    if (length (gt_p) > 0) {
        gt_p <- lapply (gt_p, function (i) get1bdypoly (i))
        lens <- vapply (gt_p, length, integer (1))
        index_final <- rep (index_final, times = lens)
        gt_p <- do.call (c, gt_p)

        # Aggregate rings by polygon
        gt_p <- split (
            gt_p,
            paste0 (obj$osm_type [index_final], "/", obj$osm_id [index_final])
        )
        # Set names to the rings of the polygons
        gt_p <- lapply (gt_p, function (x) {
            if (length (x) > 1) {
                inner <- paste0 ("inner_", seq_len (length (x) - 1))
            } else {
                inner <- character ()
            }
            names (x) <- c ("outer", inner)
            x
        })
    }

    return (gt_p)
}

#' Get all multipolygons from a 'geojson' object
#'
#' See Issue #195
#'
#' @param obj A 'geojson' object
#' @return List of multipolygons. Each multipolygon is a list of polygons, and
#'   each polygon is a list of matrices where the first
#'   defines the outer ring and the following ones, if present, define holes.
#' @noRd
get_geotext_multipoly <- function (obj) {

    . <- NULL # suppress R CMD check note

    indx_multi <- grep ("MULTIPOLYGON", obj$geotext)
    gt_mp <- NULL
    index_final <- seq_len (nrow (obj)) [indx_multi]

    # nocov start
    # TODO: Test this
    if (length (indx_multi) > 0) {
        ptn <- "(MULTIPOLYGON\\(\\(\\()|(\\)\\)\\))"
        gt_mp <- gsub (ptn, "", obj$geotext [indx_multi])
        gt_mp <- strsplit (gt_mp, split = ",")
        indx_na <- rev (which (is.na (gt_mp)))
        for (i in indx_na) {
            gt_mp [[i]] <- NULL
        }
        if (length (indx_na) > 0L) {
            index_final <- index_final [-indx_na]
        }
    }
    # nocov end

    if (length (gt_mp) > 0) {
        gt_mp <- lapply (gt_mp, function (i) get1bdypoly (i))

        # Aggregate polygons by multipolygon
        gt_mp <- split (
            gt_mp,
            paste0 (obj$osm_type [index_final], "/", obj$osm_id [index_final])
        )
        # Set names to the polygons and rings of the multypolygons
        gt_mp <- lapply (gt_mp, function (x) {
            names (x) <- paste0 ("pol_", seq_len (length (x)))
            x <- lapply (x, function (y) {
                if (length (y) > 1) {
                    inner <- paste0 ("inner_", seq_len (length (y) - 1))
                } else {
                    inner <- character ()
                }
                names (y) <- c ("outer", inner)
                y
            })

            x
        })
    }

    return (gt_mp)
}

#' get1bdypoly
#'
#' Split lists of multiple char POLYGON objects returned by nominatim into lists
#' of coordinate matrices
#'
#' @param p One polygon returned by nominatim
#'
#' @return Equivalent list of coordinate matrices
#'
#' @noRd
get1bdypoly <- function (p) {
    rm_bracket <- function (i) {
        vapply (i, function (j) gsub ("\\)", "", j),
            character (1),
            USE.NAMES = FALSE
        )
    }

    # remove all opening brackets:
    p <- vapply (p, function (j) gsub ("\\(", "", j),
        character (1),
        USE.NAMES = FALSE
    )

    ret <- list ()
    i <- grep ("\\)", p)
    while (length (i) > 0) {
        ret [[length (ret) + 1]] <- rm_bracket (p [1:i [1]])
        p <- p [(i [1] + 1):length (p)]
        i <- grep ("\\)", p)
    }
    ret [[length (ret) + 1]] <- rm_bracket (p)

    ret <- lapply (ret, function (i) {
        apply (
            do.call (rbind, strsplit (i, split = " ")),
            2, as.numeric
        )
    })

    return (ret)
}

#' Convert a list of matrices to an sf polygon
#'
#' @param pol A list of matrices defining a polygon. First is the outer limit,
#'   other are holes.
#'
#' @return A `sf` object representing the polygon without using \pkg{sf}.
#' @noRd
mat2sf_poly <- function (pol) {
    if (length (pol) == 1L && nrow (pol [[1]]) == 2L) {
        # no polygon but a bounding box
        pol <- pol [[1]]
        x <- c (pol [1, 1], pol [1, 2], pol [1, 2], pol [1, 1], pol [1, 1])
        y <- c (pol [2, 2], pol [2, 2], pol [2, 1], pol [2, 1], pol [2, 2])
        pol <- list (cbind (x, y))
    }
    class (pol) <- c ("XY", "POLYGON", "sfg")
    pol_sf <- list (pol)
    attr (pol_sf, "class") <- c ("sfc_POLYGON", "sfc")
    attr (pol_sf, "precision") <- 0
    bb <- as.vector (t (apply (do.call (rbind, pol), 2, range)))
    names (bb) <- c ("xmin", "ymin", "xmax", "ymax")
    class (bb) <- "bbox"
    attr (pol_sf, "bbox") <- bb
    crs <- list (
        input = "EPSG:4326",
        wkt = wkt4326
    )
    class (crs) <- "crs"
    attr (pol_sf, "crs") <- crs
    attr (pol_sf, "n_empty") <- 0L
    pol_sf <- make_sf (pol_sf)
    names (pol_sf) <- "geometry"
    attr (pol_sf, "sf_column") <- "geometry"
    return (pol_sf)
}

#' convert a list of matrices to an sf mulipolygon
#'
#' @param x A list of matrices
#'
#' @return A list that can be converted into a simple features geometry
#' @noRd
mat2sf_multipoly <- function (x) {
    # get bbox from matrices
    bb <- as.vector (t (apply (
        do.call (rbind, unlist (x, recursive = FALSE)), 2, range
    )))
    names (bb) <- c ("xmin", "ymin", "xmax", "ymax")
    class (bb) <- "bbox"

    class (x) <- c ("XY", "MULTIPOLYGON", "sfg")
    xsf <- list (x)
    attr (xsf, "class") <- c ("sfc_MULTIPOLYGON", "sfc")
    attr (xsf, "precision") <- 0
    attr (xsf, "bbox") <- bb
    crs <- list (
        input = "EPSG:4326",
        wkt = wkt4326
    )
    class (crs) <- "crs"
    attr (xsf, "crs") <- crs
    attr (xsf, "n_empty") <- 0L
    xsf <- make_sf (xsf)
    names (xsf) <- "geometry"
    attr (xsf, "sf_column") <- "geometry"
    return (xsf)
}

bb_as_sf_poly <- function (gt_p, gt_mp) {

    if (!is.null (gt_p)) {
        gt_p <- lapply (gt_p, function (i) {
            mat2sf_poly (i)
        })
    }
    if (!is.null (gt_mp)) {
        gt_mp <- lapply (gt_mp, function (i) {
            mat2sf_multipoly (i)
        })
    }

    if (length (gt_p) == 0 && length (gt_mp) == 0) {
        stop ("Query returned no polygons")
    } else if (length (gt_mp) == 0) {
        ret <- do.call (rbind, gt_p)
    } else if (length (gt_p) == 0) {
        ret <- do.call (rbind, gt_mp)
    } else {
        ret <- do.call (
            rbind,
            c (polygon = gt_p, multipolygon = gt_mp)
        )
    }

    return (ret)
}
