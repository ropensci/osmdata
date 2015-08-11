#' Read OSM Overpass Response
#'
#' @param osm_response file containing an OSM Overpass XML response
#' @return If the \code{query} result only has OSM \code{node}s then the function
#'         will return a \code{SpatialPointsDataFrame} with the \code{node}s.\cr\cr
#'         If the \code{query} result has OSM \code{way}s then the function
#'         will return a \code{SpatialLinesDataFrame} with the \code{way}s\cr\cr
#'         \code{relations}s are not handled yet.\cr\cr
#' @export
read_osm <- function(osm_response) {

  doc <- read_xml(osm_response)

  process_doc(doc)

}
