#' unique_osmdata
#'
#' Reduce the components of an \code{osmdata} object to only unique items of
#' each type. That is, reduce \code{$osm_points} to only those points not
#' present in other objects (lines, polygons, etc.); reduce \code{$osm_lines} to
#' only those lines not present in multiline objects; and reduce
#' \code{$osm_polygons} to only those polygons not present in multipolygon
#' objects. This renders an \code{osmdata} object more directly compatible with
#' typical output of \code{sf}.
#'
#' @param dat An \code{osmdata} object
#' @return Equivalent object reduced to only unique objects of each type
#' @export
unique_osmdata <- function (dat)
{
    if (!is (dat, 'osmdata'))
        stop ('dat must be an osmdata object')

    if (!is (dat$osm_points, 'sf'))
        stop (paste0 ('unique_osmdata only currently implemented for ',
                      'sf objects;\nplease convert sp to sf via ',
                      'sf::as (., "Spatial")'))

    indx_pts <- unique_pts (dat)
    indx_lns <- unique_lines (dat)
    indx_poly <- unique_polygons (dat)

    dat$osm_points <- dat$osm_points [unique_points (dat), ]
    dat$osm_lines <- dat$osm_lines [unique_lines (dat), ]
    dat$osm_polygons <- dat$osm_polygons [unique_polygons (dat), ]

    return (dat)
}

#' unique_points
#' get index of unique points in the \code{$osm_points} object
#' @noRd
unique_points <- function (dat)
{
    pts <- paste0 (dat$osm_points$osm_id)

    lns_pts <- unlist (lapply (dat$osm_lines$geometry, function (i)
                               rownames (i)))
    names (lns_pts) <- NULL
    lns_pts <- unique (lns_pts)

    poly_pts <- unlist (lapply (dat$osm_polygons$geometry, function (i)
                                rownames (i [[1]])))
    names (poly_pts) <- NULL
    poly_pts <- unique (poly_pts)

    which (!pts %in% c (lns_pts, poly_pts))
}

#' unique_lines
#' get index of unique lines in the \code{$osm_lines} object
#' @noRd
unique_lines <- function (dat)
{
    lns <- paste0 (dat$osm_lines$osm_id)

    mlns <- unlist (lapply (dat$osm_multilines$geometry, names))
    names (mlns) <- NULL
    mlns <- unique (mlns)

    which (!lns %in% mlns)
}

#' unique_polygons
#' get index of unique polygons in the \code{$osm_polygons} object
#' @noRd
unique_polygons <- function (dat)
{
    polys <- paste0 (dat$osm_polygons$osm_id)

    mpolys <- unlist (lapply (dat$osm_multipolygons$geometry, function (i)
                              names (i [[1]])))
    names (mpolys) <- NULL
    mpolys <- unique (mpolys)

    which (!polys %in% mpolys)
}
