#' trim_osmdata
#'
#' Trim an `osmdata` object to within a bounding polygon
#'
#' @param dat An `osmdata` object returned from [osmdata_sf()] or
#' [osmdata_sc()].
#' @param bb_poly An `sf` or `sfc` object, or matrix representing a bounding
#'    polygon. Can be obtained with `getbb (..., format_out = "polygon")` or
#'    `getbb (..., format_out = "sf_polygon")` (and possibly
#'    selected from resultant list where multiple polygons are returned).
#' @param exclude If `TRUE`, objects are trimmed exclusively, only retaining those
#' strictly within the bounding polygon; otherwise all objects which partly
#' extend within the bounding polygon are retained.
#'
#' @return A trimmed version of `dat`, reduced only to those components
#' lying within the bounding polygon.
#'
#' @note It will generally be necessary to pre-load the \pkg{sf} package for
#' this function to work correctly.
#' @note Caution is advised when using polygons obtained from Nominatim via
#' `getbb(..., format_out = "polygon"|"sf_polygon")`. These shapes can be
#' outdated and thus could cause the trimming operation to not give results
#' expected based on the current state of the OSM data.
#' @note To reduce the downloaded data from Overpass, you can do the trimming in
#' the server-side using `getbb(..., format_out = "osm_type_id")`
#' (see examples).
#'
#' @family transform
#'
#' @examples
#' \dontrun{
#' bb <- getbb ("colchester uk")
#' query <- opq (bb) |>
#'     add_osm_feature (key = "highway")
#' # Then extract data from 'Overpass' API
#' dat <- osmdata_sf (query, quiet = FALSE)
#' # Then get bounding *polygon* for Colchester, as opposed to rectangular
#' # bounding box, and use that to trim data within that polygon:
#' bb_pol <- getbb ("colchester uk", format_out = "polygon")
#' library (sf) # required for this function to work
#' dat_tr <- trim_osmdata (dat, bb_pol)
#' bb_sf <- getbb ("colchester uk", format_out = "sf_polygon")
#' class (bb_sf) # sf data.frame
#' dat_tr <- trim_osmdata (dat, bb_sf)
#' bb_sp <- as (bb_sf, "Spatial")
#' class (bb_sp) # SpatialPolygonsDataFrame
#' dat_tr <- trim_osmdata (dat, bb_sp)
#'
#' # Server-side trimming equivalent
#' bb <- getbb ("colchester uk", format_out = "osm_type_id")
#' query <- opq (bb) |>
#'     add_osm_feature (key = "highway")
#' dat <- osmdata_sf (query, quiet = FALSE)
#' }
#' @export
trim_osmdata <- function (dat, bb_poly, exclude = TRUE) {
    UseMethod ("trim_osmdata")
}

#' @export
trim_osmdata.default <- function (dat, bb_poly, exclude = TRUE) {

    stop (
        "unrecognised dat class: ", paste0 (class (dat), collapse = " "),
        ". trim_osmdata() implemented only for `osmdata_sf` or `osmdata_sc`."
    )
}


# ***************************************************************
# **********************   sf/sp methods   **********************
# ***************************************************************

#' @export
trim_osmdata.osmdata_sf <- function (dat, bb_poly, exclude = TRUE) {

    requireNamespace ("sf")
    if (!inherits (bb_poly, c ("sf", "sfc"), which = FALSE)) {
        bb_poly <- bb_poly_to_sf (bb_poly)
    }

    dat <- trim_to_poly_pts (dat, bb_poly, exclude = exclude)
    dat <- trim_to_poly (dat, bb_poly = bb_poly, exclude = exclude)
    dat <- trim_to_poly_multi (dat, bb_poly = bb_poly, exclude = exclude)

    return (dat)
}


#' @export
trim_osmdata.osmdata_sp <- function (dat, bb_poly, exclude = TRUE) {

    stop ("trim_osmdata() not implemented for `osmdata_sp` objects.")
}


bb_poly_to_mat <- function (x) {

    UseMethod ("bb_poly_to_mat")
}

#' Convert BB polygon to matrix
#'
#' These must be "exported", but that only registerss them for (in this case,
#' with generic not exported) package-internal use. The NAMESPACE file then has
#' these methods, but there is no equivalent exported function there. See
#' \url{https://github.com/r-lib/roxygen2/issues/1592}.
#'
#' @param x A bounding-box input to \link{getbb} or \link{opq}.
#'
#' @note About the need to export private methods
#'   github.com/r-lib/roxygen2/issues/1592
#' @export
#' @noRd
bb_poly_to_mat.default <- function (x) {

    stop ("bb_poly is of unknown class; please use matrix or a spatial class")
}


more_than_one <- function () {

    message ("bb_poly has more than one polygon; the first will be selected.")
}

#' @export
bb_poly_to_mat.matrix <- function (x) {
    x
}

#' @export
bb_poly_to_mat.sf <- function (x) {

    if (nrow (x) > 1) {

        more_than_one ()
        x <- x [1, ]
    }
    x <- x [[attr (x, "sf_column")]]
    bb_poly_to_mat.sfc (x)
}

#' @export
bb_poly_to_mat.sfc <- function (x) {

    if (length (x) > 1) {

        more_than_one ()
        x <- x [[1]]
    }
    as.matrix (x [[1]] [[1]])
}

#' @export
bb_poly_to_mat.SpatialPolygonsDataFrame <- function (x) { # nolint

    x <- slot (x, "polygons")
    if (length (x) > 1) {
        more_than_one ()
    }
    x <- slot (x [[1]], "Polygons")
    if (length (x) > 1) {
        more_than_one ()
    }
    slot (x [[1]], "coords")
}

#' @export
bb_poly_to_mat.list <- function (x) {

    if (length (x) > 1) {
        more_than_one ()
    }
    while (is.list (x)) {
        x <- x [[1]]
    }
    return (x)
}


bb_poly_to_sf <- function (bb_poly) {

    bb_poly <- bb_poly_to_mat (bb_poly)

    if (nrow (bb_poly) == 2) { # bbox corners

        bb_poly <- rbind (
            bb_poly [1, ],
            c (bb_poly [1, 1], bb_poly [2, 2]),
            bb_poly [2, ],
            c (bb_poly [2, 1], bb_poly [1, 2])
        )
    }

    if (!identical (
        as.numeric (utils::head (bb_poly, 1)),
        as.numeric (utils::tail (bb_poly, 1))
    )) { # Non-closed polygon
        bb_poly <- rbind (bb_poly, bb_poly [1, ])
    }

    bb_poly <- sf::st_sfc (sf::st_polygon (list (bb_poly)), crs = 4326)

    return (bb_poly)
}


#' Remove points outside bb_poly
#'
#' @param dat an object of class `osmdata_sf`
#' @param bb_poly an object of class `sf` or `sfc`
#' @param exclude If TRUE, only retaini points strictly within the bounding
#'   polygon and discard points in the vertex or boundaries; otherwise keep the
#'   points in the boundaries of the bb_poly.
#'
#' @noRd
trim_to_poly_pts <- function (dat, bb_poly, exclude = TRUE) {

    if (inherits (dat$osm_points, "sf")) {

        if (exclude) {
            # st_contains_properly assumes planar coordinates. No s2 method?
            g <- sf::st_transform (dat$osm_points, crs = .sph_merc ())
            bb_poly <- sf::st_transform (bb_poly, crs = .sph_merc ())
            indx <- sf::st_contains_properly (bb_poly, g, sparse = FALSE) [1, ]
        } else {
            indx <- sf::st_within (
                dat$osm_points, bb_poly,
                sparse = FALSE
            ) [, 1]
        }

        dat$osm_points <- dat$osm_points [indx, ]
    }

    return (dat)
}


#' get_trim_indx
#'
#' Index of finite objects (lines, polygons, multi*) in the list g which are
#' contained within the polygon bb
#'
#' @param g An `sf::sfc` list of geometries
#' @param bb Polygonal bounding box
#' @param exclude binary parameter determining exclusive or inclusive inclusion
#'      in polygon
#'
#' @return Vector index of items in g which are included in polygon
#'
#' @noRd
get_trim_indx <- function (g, bb, exclude) {

    if (exclude) {
        # st_contains_properly assumes planar coordinates. No s2 method?
        g <- sf::st_transform (g, crs = .sph_merc ())
        bb <- sf::st_transform (bb, crs = .sph_merc ())
        indx <- sf::st_contains_properly (bb, g, sparse = FALSE) [1, ]
    } else {
        indx <- sf::st_intersects (bb, g, sparse = FALSE) [1, ]
    }

    return (which (indx))
}

trim_to_poly <- function (dat, bb_poly, exclude = TRUE) {

    if (inherits (dat$osm_lines, "sf")) {
        gnms <- "osm_lines"
    } else {
        gnms <- character ()
    }
    if (inherits (dat$osm_polygons, "sf")) {
        gnms <- c (gnms, "osm_polygons")
    }

    for (g in gnms) {

        if (nrow (dat [[g]]) > 0) {

            indx <- get_trim_indx (
                g = dat [[g]]$geometry, bb = bb_poly, exclude = exclude
            )
            dat [[g]] <- dat [[g]] [indx, ]
        }
    }

    return (dat)
}

trim_to_poly_multi <- function (dat, bb_poly, exclude = TRUE) {

    if (inherits (dat$osm_multilines, "sf")) {
        gnms <- "osm_multilines"
    } else {
        gnms <- character ()
    }
    if (inherits (dat$osm_multipolygons, "sf")) {
        gnms <- c (gnms, "osm_multipolygons")
    }

    for (g in gnms) {

        if (nrow (dat [[g]]) > 0) {

            # if (g == "osm_multilines") {
            #     indx <- lapply (dat [[g]]$geometry, function (gi) {
            #         get_trim_indx (
            #             g = gi, bb = bb_poly,
            #             exclude = exclude
            #         )
            #     })
            # } else {
            #     indx <- lapply (dat [[g]]$geometry, function (gi) {
            #         get_trim_indx (
            #             g = gi [[1]], bb = bb_poly,
            #             exclude = exclude
            #         )
            #     })
            # }
            indx <- get_trim_indx (
                g = dat [[g]]$geometry, bb = bb_poly, exclude = exclude
            )
            # ilens <- vapply (indx, length, 1L, USE.NAMES = FALSE)
            # glens <- vapply (dat [[g]]$geometry, function (i) {
            #     length (i [[1]])
            # }, 1L, USE.NAMES = FALSE)
            # if (exclude) {
            #     indx <- which (ilens == glens)
            # } else {
            #     indx <- which (ilens > 0)
            # }

            dat [[g]] <- dat [[g]] [indx, ]
        }
    }

    return (dat)
}

# ***************************************************************
# ************************   sc methods   ***********************
# ***************************************************************

#' @export
trim_osmdata.osmdata_sc <- function (dat, bb_poly, exclude = TRUE) {

    v <- verts_in_bpoly (dat, bb_poly, exclude = exclude)
    # TODO: no geometries checked, only vertex

    if (exclude) {

        index <- which (dat$edge$.vx0 %in% v & dat$edge$.vx1 %in% v)
        edges_in <- dat$edge$edge_ [index]
        objs_in <- split (
            dat$object_link_edge,
            as.factor (dat$object_link_edge$object_)
        )
        objs_in <- lapply (objs_in, function (i) all (i$edge_ %in% edges_in))
        objs_in <- names (which (unlist (objs_in)))

    } else {

        index <- which (dat$edge$.vx0 %in% v | dat$edge$.vx1 %in% v)
        edges_in <- dat$edge$edge_ [index]
        index <- match (edges_in, dat$object_link_edge$edge_)
        objs_in <- unique (dat$object_link_edge$object_ [index])
    }

    rels_in <- dat$relation_ [which (dat$relations_members$member %in% objs_in)]

    index <- which (dat$object_link_edge$object_ %in% objs_in)
    dat$object_link_edge <- dat$object_link_edge [index, ]
    index <- which (dat$object$object_ %in% objs_in)
    dat$object <- dat$object [index, ]

    dat$edge <- dat$edge [dat$edge$edge_ %in% dat$object_link_edge$edge_, ]

    index <- which (dat$relation_members$member %in% objs_in)
    rels_in <- dat$relation_members$relation_ [index]
    index <- which (dat$relation_members$relation_ %in% rels_in)
    dat$relation_members <- dat$relation_members [index, ]
    index <- which (dat$relation_properties$relation_ %in% rels_in)
    dat$relation_properties <- dat$relation_properties [index, ]

    verts <- unique (c (dat$edge$.vx0, dat$edge$.vx1))
    dat$vertex <- dat$vertex [which (dat$vertex$vertex_ %in% verts), ]

    return (dat)
}

verts_in_bpoly <- function (dat, bb_poly, exclude) {

    requireNamespace ("sf")
    bb_poly <- bb_poly_to_sf (bb_poly)

    vert_to_sf <- function (dat) {

        v <- data.frame (dat$vertex) [, 1:2]
        sf::st_as_sf (v, coords = c ("x_", "y_"), crs = 4326)
    }

    if (exclude) {
        # st_contains_properly assumes planar coordinates. No s2 method?
        g <- sf::st_transform (vert_to_sf (dat), crs = .sph_merc ())
        bb_poly <- sf::st_transform (bb_poly, crs = .sph_merc ())
        w <- sf::st_contains_properly (bb_poly, g, sparse = FALSE) [1, ]
    } else {
        w <- sf::st_within (vert_to_sf (dat), bb_poly, sparse = FALSE) [, 1]
    }

    return (dat$vertex$vertex_ [which (w)])
}
