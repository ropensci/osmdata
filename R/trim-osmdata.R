#' trim_osmdata
#'
#' Trim an \link{osmdata} object to within a bounding polygon
#'
#' @param dat An \link{osmdata} object returned from \link{osmdata_sf} or
#' \link{osmdata_sp}.
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
#'
#' @export
#' @examples
#' \dontrun{
#' dat <- opq ("colchester uk") %>%
#'             add_osm_feature (key="highway") %>%
#'             osmdata_sf (quiet = FALSE)
#' bb <- getbb ("colchester uk", format_out = "polygon")
#' library (sf) # required for this function to work
#' dat_tr <- trim_osmdata (dat, bb)
#' bb <- getbb ("colchester uk", format_out = "sf_polygon")
#' class (bb) # sf data.frame
#' dat_tr <- trim_osmdata (dat, bb)
#' bb <- as (bb, "Spatial")
#' class (bb) # SpatialPolygonsDataFrame
#' dat_tr <- trim_osmdata (dat, bb)
#' }
trim_osmdata <- function (dat, bb_poly, exclude = TRUE)
{
    is_sf_loaded ()
    if (!is (bb_poly, "matrix"))
        bb_poly <- bb_poly_to_mat (bb_poly)

    if (nrow (bb_poly) > 1)
    {
        dat <- trim_to_poly_pts (dat, bb_poly, exclude = exclude) %>%
            trim_to_poly (bb_poly = bb_poly, exclude = exclude) %>%
            trim_to_poly_multi (bb_poly = bb_poly, exclude = exclude)
    } else
        message ("bb_poly must be a matrix with > 1 row; ",
                 " data will not be trimmed.")
    return (dat)
}

is_sf_loaded <- function ()
{
    if (!any (grepl ("package:sf", search ())))
        message ("It is generally necessary to pre-load the sf package ",
                 "for this function to work correctly")
}

bb_poly_to_mat <- function (x)
{
    UseMethod ("bb_poly_to_mat")
}

bb_poly_to_mat.default <- function (x)
{
    stop ("bb_poly is of unknown class; please use matrix or a spatial class")
}

more_than_one <- function ()
{
    message ("bb_poly has more than one polygon; the first will be selected.")
}

bb_poly_to_mat.sf <- function (x)
{
    if (nrow (x) > 1)
    {
        more_than_one ()
        x <- x [1, ]
    }
    x <- x [[attr (x, "sf_column")]]
    bb_poly_to_mat.sfc (x)
}

bb_poly_to_mat.sfc <- function (x)
{
    if (length (x) > 1)
    {
        more_than_one ()
        x <- x [[1]]
    }
    as.matrix (x [[1]] [[1]])
}

bb_poly_to_mat.SpatialPolygonsDataFrame <- function (x)
{
    x <- slot (x, "polygons")
    if (length (x) > 1)
        more_than_one ()
    x <- slot (x [[1]], "Polygons")
    if (length (x) > 1)
        more_than_one ()
    slot (x [[1]], "coords")
}

bb_poly_to_mat.list <- function (x)
{
    if (length (x) > 1)
        more_than_one ()
    x [[1]]
}

trim_to_poly_pts <- function (dat, bb_poly, exclude = TRUE)
{
    if (is (dat$osm_points, 'sf'))
    {
        g <- do.call (rbind, dat$osm_points$geometry)
        indx <- sp::point.in.polygon (g [, 1], g [, 2],
                                      bb_poly [, 1], bb_poly [, 2])
        if (exclude)
            indx <- which (indx == 1)
        else
            indx <- which (indx > 0)
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
get_trim_indx <- function (g, bb, exclude)
{
    indx <- lapply (g, function (i)
                    {
                        if (is.list (i)) # polygons
                            i <- i [[1]]
                        inp <- sp::point.in.polygon (i [, 1], i [, 2],
                                                     bb [, 1], bb [, 2])
                        if ( (exclude & all (inp > 0)) |
                            (!exclude & any (inp > 0)))
                            return (TRUE)
                        else
                            return (FALSE)
                    })
    ret <- NULL # multi objects can be empty
    if (length (indx) > 0)
        ret <- which (unlist (indx))
    return (ret)
}

trim_to_poly <- function (dat, bb_poly, exclude = TRUE)
{
    if (is (dat$osm_lines, 'sf'))
    {
        gnms <- c ("osm_lines", "osm_polygons")
        for (g in gnms)
        {
            if (nrow (dat [[g]]) > 0)
            {
                indx <- get_trim_indx (dat [[g]]$geometry, bb_poly,
                                       exclude = exclude)
                #cl <- class (dat [[g]]$geometry) # TODO: Delete
                attrs <- attributes (dat [[g]])
                attrs$row.names <- attrs$row.names [indx]
                attrs_g <- attributes (dat [[g]]$geometry)
                attrs_g$names <- attrs_g$names [indx]
                dat [[g]] <- dat [[g]] [indx, ] # this strips sf class defs
                #class (dat [[g]]$geometry) <- cl # TODO: Delete
                attributes (dat [[g]]) <- attrs
                attributes (dat [[g]]$geometry) <- attrs_g
            }
        }
    }

    return (dat)
}

trim_to_poly_multi <- function (dat, bb_poly, exclude = TRUE)
{
    if (is (dat$osm_multilines, 'sf'))
    {
        gnms <- c ("osm_multilines", "osm_multipolygons")
        for (g in gnms)
        {
            if (nrow (dat [[g]]) > 0)
            {
                if (g == "osm_multilines")
                    indx <- lapply (dat [[g]]$geometry, function (gi)
                                    get_trim_indx (g = gi, bb = bb_poly,
                                                   exclude = exclude))
                else
                    indx <- lapply (dat [[g]]$geometry, function (gi)
                                    get_trim_indx (g = gi [[1]], bb = bb_poly,
                                                   exclude = exclude))
                ilens <- vapply (indx, length, 1L, USE.NAMES = FALSE)
                glens <- vapply (dat [[g]]$geometry, length,
                                 1L, USE.NAMES = FALSE)
                if (exclude)
                    indx <- which (ilens == glens)
                else
                    indx <- which (ilens > 0)

                #cl <- class (dat [[g]]$geometry) # TODO: Delete
                attrs <- attributes (dat [[g]])
                attrs$row.names <- attrs$row.names [indx]
                attrs_g <- attributes (dat [[g]]$geometry)
                attrs_g$names <- attrs_g$names [indx]
                dat [[g]] <- dat [[g]] [indx, ]
                #class (dat [[g]]$geometry) <- cl # TODO: Delete
                attributes (dat [[g]]) <- attrs
                attributes (dat [[g]]$geometry) <- attrs_g
            }
        }
    }

    return (dat)
}
