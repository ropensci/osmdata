#' Convert osmdata polygons into lines
#'
#' Street networks downloaded with \code{add_osm_object(key = "highway")} will
#' store any circular highways in \code{$osm_polygons}. this function combines
#' those with the \code${$osm_lines} component to yield a single \pkg{sf}
#' \code{data.frame} of all highways, whether polygonal or not.
#'
#' @param osmdat An \link{osmdata} object.
#' @return Modified version of same object with all \code{$osm_polygons}
#' objeccts merged into \code{$osm_lines}.
#'
#' @note The \code{$osm_polygons} field is retained, with those features also
#' repeated as \code`LINESTRING} objects in \code{$osm_lines}.
#'
#' @export
osm_poly2line <- function (osmdat)
{
    if (!is (osmdat, "osmdata_sf"))
        stop ("osm_poly2line only works for objects of class osmdata_sf")

    g <- lapply (dat$osm_polygons$geometry, function (i) {
                     p1 <- i [[1]]
                     class (p1) <- c ("XY", "LINESTRING", "sfg")
                     return (p1)
            })
    names (g) <- names (dat$osm_polygons$geometry)
    # then copy all attributes from the lines
    attrs  <- attributes (dat$osm_lines$geometry)
    attrs <- attrs [names (attrs) != "names"]
    attributes (g) <- c (attributes (g), attrs)
    attr (g, "bbox") <- attr (dat$osm_polygons$geometry, "bbox")
    polys <- dat$osm_polygons
    polys$geometry <- g

    # use osmdata.c method to join the two sets of lines
    newdat <- osmdata()
    newdat$osm_lines <- polys
    # This has to be put into newdat to ensure fields with no features are
    # retained as empty data frames rather than NULL objects
    newdat <- c (dat, newdat)
    dat$osm_lines <- newdat$osm_lines
    return (dat)
}
