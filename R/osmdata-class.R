#' osmdata class def
#'
#' @param bbox bounding box
#' @param overpass_call overpass_call
#' @param osm_points \code{sf} Simple Features Collection of points
#' @param osm_linestrings \code{sf} Simple Features Collection of multilinestrings
#' @param osm_polygons \code{sf} Simple Features Collection of polygons
#' @param osm_multilinestrings \code{sf} Simple Features Collection of multilinestrings
#' @param osm_multipolygons \code{sf} Simple Features Collection of multipolygons
#' @param timestamp timestamp
#' @param ... other options ignored
#'
#' @note Class constructor should never be used directly, and is only exported
#' to provide access to the print method
#'
#' @export
osmdata <- function (bbox, overpass_call, 
                     osm_points, osm_linestrings, osm_polygons, 
                     osm_multilinestrings, osm_multipolygons, timestamp, ...) 
{
  if (missing (bbox)) bbox <- NULL
  if (missing (overpass_call)) overpass_call <- NULL
  if (missing (osm_points)) osm_points <- NULL
  if (missing (osm_linestrings)) osm_linestrings <- NULL
  if (missing (osm_polygons)) osm_polygons <- NULL
  if (missing (osm_multilinestrings)) osm_multilinestrings <- NULL
  if (missing (osm_multipolygons)) osm_multipolygons <- NULL
  if (missing (timestamp)) timestamp <- NULL
  if (missing (timestamp)) timestamp <- NULL

  obj <- list (
               bbox = bbox,
               overpass_call = overpass_call,
               timestamp = timestamp,
               osm_points = osm_points,
               osm_linestrings = osm_linestrings,
               osm_polygons = osm_polygons,
               osm_multilinestrings = osm_multilinestrings,
               osm_multipolygons = osm_multipolygons)
  class (obj) <- append (class (obj), "osmdata")
  return (obj)
}



#' @export
print.osmdata <- function (x, ...)
{
  if (!all (sapply (x, is.null)))
    message ("Object of class 'osmdata' with:")
  if (!is.null (x$bbox)) 
    message (paste ("  $bbox          :", x$bbox))
  if (!is.null (x$overpass_call))
    message ("  $overpass_call : The call submitted to the overpass API")
  if (!is.null (x$timestamp)) 
    message (paste ("  $timestamp     :", x$timestamp))

  indx <- which (grepl ("osm", names (x)))
  sf <- any (grep ("sf", sapply (x, class)))
  if (sf)
  {
      for (i in names (x) [indx])
      {
          xi <- x [i]
      }
  } else
  {
      if (is.null (x$osm_points)) 
        message (       "  $osm_points           : NULL")
      else
        message (paste ("  $osm_points           : 'sp' SpatialPointsDataFrame   with",
                        nrow (x$osm_points), "points"))

      if (is.null (x$osm_linestrings)) 
        message (       "  $osm_linestrings      : NULL")
      else
        message (paste ("  $osm_linestrings      : 'sp' SpatialLinesDataFrame    with",
                        nrow (x$osm_linestrings), "linestrings"))

      if (is.null (x$osm_polygons)) 
        message (       "  $osm_polygons         : NULL")
      else
        message (paste ("  $osm_polygons         : 'sp' SpatialPolygonsDataFrame with",
                        nrow (x$osm_polygons), "polygons"))

      if (is.null (x$osm_multilinestrings)) 
        message (       "  $osm_multilinestrings : NULL")
      else
        message (paste ("  $osm_multilinestrings : 'sp' SpatialLinesDataFrame    with",
                        nrow (x$osm_multilinestrings), "multilinestrings"))

      if (is.null (x$osm_multipolygons)) 
        message ("  $osm_multipolygons  : NULL")
      else
        message (paste ("  $osm_multipolygons    : 'sp' SpatialPolygonsDataFrame with",
                        nrow (x$osm_multipolygons), "multipolygons"))
  }
  #invisible (x)
}

