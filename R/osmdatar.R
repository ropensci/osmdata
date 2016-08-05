#' osmdatar
#'
#' Very fast download of OpenStreetMap (OSM) data into \code{sp} objects. OSM
#' data are extracted from the overpass API and processed with very fast C++
#' routines for return to R.
#'
#' @section Functions:
#' \tabular{ll}{
#' \code{get_points}\tab Extract points (such as nodes) from OSM data and return as
#' \code{SpatialPointsDataFrame}\cr
#' \code{get_lines}\tab Extract lines (such as highways) from OSM data and return as
#' \code{SpatialLinesDataFrame}\cr
#' \code{get_polygons}\tab Extract polygons from OSM data and return as
#' \code{SpatialPolygonsDataFrame}\cr
#' }
#'
#' @name osmdatar
#' @docType package
#' @import httr sp XML
#' @importFrom Rcpp evalCpp
#' @useDynLib osmdatar
NULL
