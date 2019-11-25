#' Convert osmdata polygons into lines
#'
#' Street networks downloaded with `add_osm_object(key = "highway")` will
#' store any circular highways in `osm_polygons`. this function combines
#' those with the `osm_lines` component to yield a single \pkg{sf}
#' `data.frame` of all highways, whether polygonal or not.
#'
#' @param osmdat An \link{osmdata} object.
#' @return Modified version of same object with all `osm_polygons`
#' objeccts merged into `osm_lines`.
#'
#' @note The `osm_polygons` field is retained, with those features also
#' repeated as `LINESTRING` objects in `osm_lines`.
#'
#' @export
#' @examples
#' \dontrun{
#' dat <- opq ("colchester uk") %>%
#'             add_osm_feature (key="highway") %>%
#'             osmdata_sf ()
#' # colchester has lots of roundabouts, and these are stored in 'osm_polygons'
#' # rather than 'osm_lines'. The former can be merged with the latter by:
#' dat2 <- osm_poly2line (dat)
#' # 'dat2' will have more lines than 'dat', but the same number of polygons (they
#' # are left unchanged.) 
#' }
osm_poly2line <- function (osmdat)
{
    if (!is (osmdat, "osmdata_sf"))
        stop ("osm_poly2line only works for objects of class osmdata_sf")

    g <- lapply (osmdat$osm_polygons$geometry, function (i) {
                     p1 <- i [[1]]
                     class (p1) <- c ("XY", "LINESTRING", "sfg")
                     return (p1)
            })
    names (g) <- names (osmdat$osm_polygons$geometry)
    # then copy all attributes from the lines
    attrs  <- attributes (osmdat$osm_lines$geometry)
    attrs <- attrs [names (attrs) != "names"]
    attributes (g) <- c (attributes (g), attrs)
    attr (g, "bbox") <- attr (osmdat$osm_polygons$geometry, "bbox")
    polys <- osmdat$osm_polygons
    polys$geometry <- g

    # use osmdata.c method to join the two sets of lines
    newdat <- osmdata()
    newdat$osm_lines <- polys
    # This has to be put into newdat to ensure fields with no features are
    # retained as empty data frames rather than NULL objects
    newdat <- c (osmdat, newdat)
    osmdat$osm_lines <- newdat$osm_lines
    return (osmdat)
}
