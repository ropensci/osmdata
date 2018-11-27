#' unique_osmdata
#'
#' Reduce the components of an \link{osmdata} object to only unique items of
#' each type. That is, reduce `$osm_points` to only those points not
#' present in other objects (lines, polygons, etc.); reduce `$osm_lines` to
#' only those lines not present in multiline objects; and reduce
#' `$osm_polygons` to only those polygons not present in multipolygon
#' objects. This renders an \link{osmdata} object more directly compatible with
#' typical output of \pkg{sf}.
#'
#' @param dat An \link{osmdata} object
#' @return Equivalent object reduced to only unique objects of each type
#' @export
unique_osmdata <- function (dat)
{
    if (!is (dat, 'osmdata'))
        stop ('dat must be an osmdata object')

    if (is (dat$osm_points, 'sf'))
    {
        indx_points <- unique_points_sf (dat)
        indx_lines <- unique_lines_sf (dat)
        indx_polys <- unique_polygons_sf (dat)
    } else
    {
        indx_points <- unique_points_sp (dat)
        indx_lines <- unique_lines_sp (dat)
        indx_polys <- unique_polygons_sp (dat)
    }

    dat$osm_points <- dat$osm_points [indx_points, ]
    dat$osm_lines <- dat$osm_lines [indx_lines, ]
    dat$osm_polygons <- dat$osm_polygons [indx_polys, ]

    return (dat)
}

#' unique_points_sf
#' get index of unique points in the `$osm_points` object
#' @noRd
unique_points_sf <- function (dat)
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

#' unique_points_sp
#' get index of unique points in the `$osm_points` object
#' @noRd
unique_points_sp <- function (dat)
{
    pts <- rownames (slot (dat$osm_points, "data"))

    lns <- slot (dat$osm_lines, "lines")
    lns_pts <- lapply (lns, function (i)
                       rownames (slot (slot (i, "Lines") [[1]], "coords")))
    lns_pts <- unlist (lns_pts)
    names (lns_pts) <- NULL
    lns_pts <- unique (lns_pts)

    polys <- slot (dat$osm_polygons, "polygons")
    poly_pts <- lapply (polys, function (i)
                        rownames (slot (slot (i, "Polygons") [[1]], "coords")))
    poly_pts <- unlist (poly_pts)
    names (poly_pts) <- NULL
    poly_pts <- unique (poly_pts)

    which (!pts %in% c (lns_pts, poly_pts))
}

#' unique_lines_sf
#' get index of unique lines in the `$osm_lines` object
#' @noRd
unique_lines_sf <- function (dat)
{
    lns <- paste0 (dat$osm_lines$osm_id)

    mlns <- unlist (lapply (dat$osm_multilines$geometry, names))
    names (mlns) <- NULL
    mlns <- unique (mlns)

    which (!lns %in% mlns)
}

#' unique_lines_sp
#' get index of unique lines in the `$osm_lines` object
#' @noRd
unique_lines_sp <- function (dat)
{
    lns <- rownames (slot (dat$osm_lines, "data"))

    mlns <- slot (dat$osm_multilines, "lines") [[1]]
    mlns <- names (slot (mlns, "Lines"))
    mlns <- unique (mlns)

    which (!lns %in% mlns)
}

#' unique_polygons_sf
#' get index of unique polygons in the `$osm_polygons` object
#' @noRd
unique_polygons_sf <- function (dat)
{
    polys <- paste0 (dat$osm_polygons$osm_id)

    mpolys <- unlist (lapply (dat$osm_multipolygons$geometry, function (i)
                              names (i [[1]])))
    names (mpolys) <- NULL
    mpolys <- unique (mpolys)

    which (!polys %in% mpolys)
}

#' unique_polygons_sp
#' get index of unique polygons in the `$osm_polygons` object
#' @noRd
unique_polygons_sp <- function (dat)
{
    polys <- rownames (slot (dat$osm_polygons, "data"))

    mpolys <- slot (dat$osm_multipolygons, "polygons")
    mpolys <- unlist (lapply (mpolys, function (i)
                              names (slot (i, "Polygons"))))
    names (mpolys) <- NULL
    mpolys <- unique (mpolys)

    which (!polys %in% mpolys)
}
