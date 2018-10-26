#' osmdata class def
#'
#' @param bbox bounding box
#' @param overpass_call overpass_call
#' @param meta metadata of overpass query, including timestamps and version
#' numbers
#' @param osm_points OSM nodes as \code{sf} Simple Features Collection of points
#'                   or \code{sp} SpatialPointsDataFrame
#' @param osm_lines OSM ways \code{sf} Simple Features Collection of linestrings
#'                  or \code{sp} SpatialLinesDataFrame
#' @param osm_polygons OSM ways as \code{sf} Simple Features Collection of
#'                     polygons or \code{sp} SpatialPolygonsDataFrame
#' @param osm_multilines OSM relations as \code{sf} Simple Features Collection
#'                       of multilinestrings or \code{sp} SpatialLinesDataFrame
#' @param osm_multipolygons OSM relations as \code{sf} Simple Features
#'                          Collection of multipolygons or \code{sp}
#'                          SpatialPolygonsDataFrame 
#' @param ... other options ignored
#'
#' @note Class constructor should never be used directly, and is only exported
#' to provide access to the print method
#'
#' @export
osmdata <- function (bbox = NULL, overpass_call = NULL, meta = NULL,
                     osm_points = NULL, osm_lines = NULL, osm_polygons = NULL,
                     osm_multilines = NULL, osm_multipolygons = NULL)
{
    obj <- list (
                 bbox = bbox,
                 overpass_call = overpass_call,
                 meta = meta,
                 osm_points = osm_points,
                 osm_lines = osm_lines,
                 osm_polygons = osm_polygons,
                 osm_multilines = osm_multilines,
                 osm_multipolygons = osm_multipolygons)
    class (obj) <- append (class (obj), "osmdata")
    return (obj)
}
