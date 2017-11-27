#' trim_osmdata
#'
#' Trim an \code{osmdata} object to within a bounding polygon
#'
#' @param dat An \code{osmdata} object returned from \code{osmdata_sf()} or
#' \code{osmdata_sp()}.
#' @param bb_poly A matrix representing a bounding polygon obtained with
#' \code{getbb (..., format_out = "polygon")} (and possibly selected from
#' resultant list where multiple polygons are returned).
#' @param exclude If TRUE, objects are trimmed exclusively, only retaining those
#' strictly within the bounding polygon; otherwise all objects which partly
#' extend within the bounding polygon are retained.
#'
#' @return A trimmed version of \code{dat}, reduced only to those components
#' lying within the bounding polygon.
#'
#' @export
trim_osmdata <- function (dat, bb_poly, exclude = TRUE)
{
    if (nrow (bb_poly) > 2)
    {
        dat <- trim_to_poly_pts (dat, bb_poly, exclude = exclude) %>%
            trim_to_poly (bb_poly = bb_poly, exclude = exclude) %>%
            trim_to_poly_multi (bb_poly = bb_poly, exclude = exclude)
    }
    return (dat)
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
#' @param g An \code{sfc} list of geometries
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
                cl <- class (dat [[g]]$geometry)
                dat [[g]] <- dat [[g]] [indx, ] # this strips sf class defs
                class (dat [[g]]$geometry) <- cl
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

                cl <- class (dat [[g]]$geometry)
                dat [[g]] <- dat [[g]] [indx, ]
                class (dat [[g]]$geometry) <- cl
            }
        }
    }

    return (dat)
}
