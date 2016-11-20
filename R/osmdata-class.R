osmdata <- function (bbox, overpass_call, 
                     osm_points, osm_lines, osm_polygons, timestamp, ...) 
{
  if (missing (bbox)) bbox <- NULL
  if (missing (overpass_call)) overpass_call <- NULL
  if (missing (osm_points)) osm_points <- NULL
  if (missing (osm_lines)) osm_lines <- NULL
  if (missing (osm_polygons)) osm_polygons <- NULL
  if (missing (timestamp)) timestamp <- NULL
  if (missing (timestamp)) timestamp <- NULL

  obj <- list (
               bbox=bbox,
               overpass_call=overpass_call,
               osm_points=osm_points,
               osm_lines=osm_lines,
               osm_polygons=osm_polygons,
               timestamp=timestamp)
  class (obj) <- append (class (obj), "osmdata")
  return (obj)
}

print.osmdata <- function (x, ...)
{
  if (!all (sapply (x, is.null)))
    message ("Object of class 'osmdata' with:")
  if (!is.null (x$bbox)) 
    message (paste ("  bbox          :", x$bbox))
  if (!is.null (x$timestamp)) 
    message (paste ("  timestamp     :", x$timestamp))
  if (!is.null (x$osm_points)) 
    message (paste ("  osm_points    : 'sp' SpatialPointsDataFrame   with",
                    length (x$osm_points), "points"))
  if (!is.null (x$osm_lines)) 
    message (paste ("  osm_lines     : 'sp' SpatialLinesDataFrame    with",
                    length (x$osm_lines), "lines"))
  if (!is.null (x$osm_polygons)) 
    message (paste ("  osm_polygons  : 'sp' SpatialPolygonsDataFrame with",
                    length (x$osm_polygons), "polygons"))
  if (!is.null (x$overpass_call))
    message ("  overpass_call : The call submitted to the overpass API")
    message ("  overpass_call : The call submitted to the overpass API")
}
