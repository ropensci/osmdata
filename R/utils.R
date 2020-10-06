#' unname_osmdata_sf
#'
#' Remove names from `osmdata` geometry objects, for cases in which these cause
#' issues, particularly with plotting, such as
#' \url{https://github.com/rstudio/leaflet/issues/631}, or
#' \url{https://github.com/r-spatial/sf/issues/1177}. Note that removing these
#' names also removes any ability to inter-relate the different components of an
#' `osmdata` object, so use of this function is only recommended to resolve
#' issues such as those linked to above.
#'
#' @param x An 'osmdata_sf' object returned from function of same name
#' @return Same object, yet with no row names on geometry objects.
#' @export
unname_osmdata_sf <- function (x)
{
    requireNamespace ("sf")

    x <- unname_osm_points (x)
    x <- unname_osm (x, "osm_lines")
    x <- unname_osm (x, "osm_polygons")
    x <- unname_osm (x, "osm_multilines")
    x <- unname_osm (x, "osm_multipolygons")

    return (x)
}

unname_osm_points <- function (x)
{
    if (nrow (x$osm_points) > 0)
        names (x$osm_points$geometry) <- NULL
    return (x)
}

unname_osm <- function (x, what = "osm_lines")
{
    if (is.null (x [[what]]))
        return (x)

    g <- lapply (x [[what]]$geometry, function (i) unname (i))
    names (g) <- NULL
    if (what == "osm_polygons")
        g <- lapply (g, function (i) {
                         rownames (i [[1]]) <- NULL
                         return (i) })
    else if (what == "osm_multilines")
        g <- lapply (g, function (i)
                     sf::st_multilinestring (lapply (i,
                            function (j) unname (j))))
    else if (what == "osm_multipolygons")
        g <- lapply (g, function (i)
                     sf::st_multipolygon (lapply (i, function (j) unname (j))))
    x [[what]]$geometry <- sf::st_sfc (g, crs = 4326)
    return (x)
}

