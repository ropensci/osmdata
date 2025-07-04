#' trim_osmdata
#'
#' Trim an \link{osmdata} object to within a bounding polygon
#'
#' @param dat An \link{osmdata} object returned from \link{osmdata_sf} or
#' \link{osmdata_sp} (DEPRECATED).
#' @param bb_poly A matrix representing a bounding polygon obtained with
#' `getbb (..., format_out = "polygon")` (and possibly selected from
#' resultant list where multiple polygons are returned).
#' @param exclude If TRUE, objects are trimmed exclusively, only retaining those
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
#' }
#' @export
trim_osmdata <- function (dat, bb_poly, exclude = TRUE) {

    # safer than using method despatch, because these class defs are **NOT** the
    # first items
    if (methods::is (dat, "osmdata_sf") | methods::is (dat, "osmdata_sp")) {

        trim_osmdata_sfp (dat = dat, bb_poly = bb_poly, exclude = exclude)

    } else if (methods::is (dat, "osmdata_sc")) {

        trim_osmdata_sc (dat = dat, bb_poly = bb_poly, exclude = exclude)

    } else {
        stop ("unrecognised format: ", paste0 (class (dat), collapse = " "))
    }
}


# ***************************************************************
# **********************   sf/sp methods   **********************
# ***************************************************************

trim_osmdata_sfp <- function (dat, bb_poly, exclude = TRUE) {

    requireNamespace ("sf")
    if (!is (bb_poly, "matrix")) {
        bb_poly <- bb_poly_to_mat (bb_poly)
    }

    if (nrow (bb_poly) > 1) {

        # "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0":
        srcproj <- .lonlat ()
        # "+proj=merc +a=6378137 +b=6378137":
        crs <- .sph_merc ()
        bb_poly <- reproj::reproj (
            bb_poly,
            target = crs,
            source = srcproj
        ) [, 1:2]

        dat <- trim_to_poly_pts (dat, bb_poly, exclude = exclude)
        dat <- trim_to_poly (dat, bb_poly = bb_poly, exclude = exclude)
        dat <- trim_to_poly_multi (dat, bb_poly = bb_poly, exclude = exclude)
    } else {
        message (
            "bb_poly must be a matrix with > 1 row; ",
            " data will not be trimmed."
        )
    }
    return (dat)
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

trim_to_poly_pts <- function (dat, bb_poly, exclude = TRUE) {

    if (is (dat$osm_points, "sf")) {

        requireNamespace ("sp", quietly = TRUE)

        # "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0":
        srcproj <- .lonlat ()
        # "+proj=merc +a=6378137 +b=6378137":
        crs <- .sph_merc ()

        g <- do.call (rbind, dat$osm_points$geometry)
        g <- reproj::reproj (g, target = crs, source = srcproj)
        indx <- sp::point.in.polygon (
            g [, 1], g [, 2],
            bb_poly [, 1], bb_poly [, 2]
        )
        if (exclude) {
            indx <- which (indx == 1)
        } else {
            indx <- which (indx > 0)
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

    # "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0":
    srcproj <- .lonlat ()
    # "+proj=merc +a=6378137 +b=6378137":
    crs <- .sph_merc ()

    indx <- lapply (g, function (i) {

        if (is.list (i)) { # polygons
            i <- i [[1]]
        }
        i <- reproj::reproj (as.matrix (i), target = crs, source = srcproj)
        inp <- sp::point.in.polygon (
            i [, 1], i [, 2],
            bb [, 1], bb [, 2]
        )
        if ((exclude & all (inp > 0)) |
            (!exclude & any (inp > 0))) {
            return (TRUE)
        } else {
            return (FALSE)
        }
    })
    ret <- NULL # multi objects can be empty
    if (length (indx) > 0) {
        ret <- which (unlist (indx))
    }
    return (ret)
}

trim_to_poly <- function (dat, bb_poly, exclude = TRUE) {

    if (is (dat$osm_lines, "sf") | is (dat$osm_polygons, "sf")) {

        gnms <- c ("osm_lines", "osm_polygons")
        index <- vapply (
            gnms, function (i) !is.null (dat [[i]]),
            logical (1)
        )
        gnms <- gnms [index]
        for (g in gnms) {

            if (!is.null (dat [[g]]) & nrow (dat [[g]]) > 0) {

                indx <- get_trim_indx (dat [[g]]$geometry, bb_poly,
                    exclude = exclude
                )
                # cl <- class (dat [[g]]$geometry) # TODO: Delete
                attrs <- attributes (dat [[g]])
                attrs$row.names <- attrs$row.names [indx]
                attrs_g <- attributes (dat [[g]]$geometry)
                attrs_g$names <- attrs_g$names [indx]
                dat [[g]] <- dat [[g]] [indx, ] # this strips sf class defs
                # class (dat [[g]]$geometry) <- cl # TODO: Delete
                attributes (dat [[g]]) <- attrs
                attributes (dat [[g]]$geometry) <- attrs_g
            }
        }
    }

    return (dat)
}

trim_to_poly_multi <- function (dat, bb_poly, exclude = TRUE) {

    if (is (dat$osm_multilines, "sf") | is (dat$osm_multipolygons, "sf")) {

        gnms <- c ("osm_multilines", "osm_multipolygons")
        index <- vapply (
            gnms, function (i) !is.null (dat [[i]]),
            logical (1)
        )
        gnms <- gnms [index]
        for (g in gnms) {

            if (nrow (dat [[g]]) > 0) {

                if (g == "osm_multilines") {
                    indx <- lapply (dat [[g]]$geometry, function (gi) {
                        get_trim_indx (
                            g = gi, bb = bb_poly,
                            exclude = exclude
                        )
                    })
                } else {
                    indx <- lapply (dat [[g]]$geometry, function (gi) {
                        get_trim_indx (
                            g = gi [[1]], bb = bb_poly,
                            exclude = exclude
                        )
                    })
                }
                ilens <- vapply (indx, length, 1L, USE.NAMES = FALSE)
                glens <- vapply (dat [[g]]$geometry, function (i) {
                    length (i [[1]])
                }, 1L, USE.NAMES = FALSE)
                if (exclude) {
                    indx <- which (ilens == glens)
                } else {
                    indx <- which (ilens > 0)
                }

                # cl <- class (dat [[g]]$geometry) # TODO: Delete
                attrs <- attributes (dat [[g]])
                attrs$row.names <- attrs$row.names [indx]
                attrs_g <- attributes (dat [[g]]$geometry)
                attrs_g$names <- attrs_g$names [indx]
                dat [[g]] <- dat [[g]] [indx, ]
                # class (dat [[g]]$geometry) <- cl # TODO: Delete
                attributes (dat [[g]]) <- attrs
                attributes (dat [[g]]$geometry) <- attrs_g
            }
        }
    }

    return (dat)
}

# ***************************************************************
# ************************   sc methods   ***********************
# ***************************************************************

trim_osmdata_sc <- function (dat, bb_poly, exclude = TRUE) {

    v <- verts_in_bpoly (dat, bb_poly)

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

verts_in_bpoly <- function (dat, bb_poly) {

    bb_poly_to_sf <- function (bb_poly) {

        if (nrow (bb_poly) == 2) {

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
        )) {
            bb_poly <- rbind (bb_poly, bb_poly [1, ])
        }

        sf::st_sf (
            sf::st_sfc (
                sf::st_polygon (list (bb_poly)),
                crs = 4326
            )
        )
    }
    bb_poly <- bb_poly_to_sf (bb_poly)

    vert_to_sf <- function (dat) {

        v <- data.frame (dat$vertex) [, 1:2]
        sf::st_as_sf (v, coords = c ("x_", "y_"), crs = 4326)
    }

    # suppress message about st_intersection assuming planar coordinates,
    # because the inaccuracy may be ignored here
    suppressMessages (w <- sf::st_within (vert_to_sf (dat), bb_poly))

    dat$vertex$vertex_ [which (as.logical (w))]
}
