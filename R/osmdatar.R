#' osmdata
#'
#' Very fast download of OpenStreetMap (OSM) data into 'sp' objects. OSM data
#' are extracted from the overpass API and processed with very fast C++ routines
#' for return to R.
#'
#' @section Functions:
#' \tabular{ll}{
#' 'get_nodes'\tab Extract nodes from OSM data and return as
#' SpatialPointsDataFrame\cr
#' 'get_ways'\tab Extract ways from OSM data and return as
#' SpatialLinesDataFrame\cr
#' 'get_polygons'\tab Extract polygons from OSM data and return as
#' SpatialPolygonsDataFrame\cr
#' }
#'
#' @name osmdatar
#' @docType package
#' @import httr sp XML
#' @importFrom Rcpp evalCpp
#' @useDynLib osmdatar
NULL
