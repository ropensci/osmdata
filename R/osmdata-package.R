#' Import OpenStreetMap data in 'sf', 'SC', 'sp', 'data.frame' and 'xml' formats
#'
#' Imports OpenStreetMap (OSM) data into R as 'sf', 'SC', 'sp', 'data.frame' or
#' 'xml_document' objects. OSM data are extracted from the overpass API and
#' processed with very fast C++ routines for return to R. The package enables
#' simple overpass queries to be constructed without the user necessarily
#' understanding the syntax of the overpass query language, while retaining the
#' ability to handle arbitrarily complex queries. Functions are also provided to
#' enable recursive searching between different kinds of OSM data (for example,
#' to find all lines which intersect a given point).
#'
#' @section Functions to Prepare Queries:
#' \itemize{
#' \item \link{getbb}: Get bounding box for a given place name
#' \item \link{bbox_to_string}: Convert a named matrix or a named vector
#' (or an unnamed vector) return a string
#' \item \link{overpass_status}: Retrieve status of the overpass API
#' \item \link{opq}: Build an overpass query
#' \item \link{add_osm_feature}: Add a feature to an overpass query
#' \item \link{opq_string}: Convert an osmdata query to overpass API
#' string
#' }
#'
#' @section Functions to Get Additional OSM Information:
#' \itemize{
#' \item \link{available_features}: List recognised features in OSM
#' \item \link{available_tags}: List tags associated with a feature
#' }
#'
#' @section Functions to Extract OSM Data:
#' \itemize{
#' \item \link{osmdata_data_frame}: Return OSM data in \code{\link{data.frame}}
#'     format
#' \item \link{osmdata_sc}: Return OSM data in \pkg{silicate} format
#' \item \link{osmdata_sf}: Return OSM data in \pkg{sf} format
#' \item \link{osmdata_sp}: Return OSM data in \pkg{sp} format
#' \item \link{osmdata_xml}: Return OSM data in \pkg{xml2} format
#' }
#'
#' @section Functions to Search Data:
#' \itemize{
#' \item `osm_points`: Extract all `osm_points` objects
#' \item `osm_lines`: Extract all `osm_lines` objects
#' \item `osm_polygons`: Extract all `osm_polygons` objects
#' \item `osm_multilines`: Extract all `osm_multilines` objects
#' \item `osm_multipolygons`: Extract all `osm_multipolygons` objects
#' }
#'
#' @name osmdata
#' @docType package
#' @family package
#' @author Mark Padgham, Bob Rudis, Robin Lovelace, Maëlle Salmon, Joan Maspons
#' @importFrom magrittr %>%
#' @importFrom methods is slot
#' @importFrom Rcpp evalCpp
#' @importFrom utils browseURL read.table
#' @useDynLib osmdata, .registration = TRUE
"_PACKAGE"

#' Pipe operator
#'
#' @name %>%
#' @rdname pipe
#' @keywords internal
#' @export
#' @importFrom magrittr %>%
#' @usage lhs \%>\% rhs
NULL
