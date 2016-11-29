#' Read an XML OSM Overpass response from path
#'
#' Read an (XML format) OSM Overpass response from a string, a connection,
#' or a raw vector.
#'
#' @param osm_response file containing an OSM Overpass (XML) response. Can be
#'                     A string, a connection, or a raw vector.\cr
#'                     A string can be either a path, a url or literal xml.
#'                     Urls will be converted into connections either using
#'                     \code{base::url} or, if installed, \code{curl::curl}.
#'                     Local paths ending in \code{.gz}, \code{.bz2}, \code{.xz},
#'                     \code{.zip} will be automatically uncompressed.
#' @param encoding Specify a default encoding for the document. Unless otherwise
#'        specified XML documents are assumed to be in UTF-8 or UTF-16. If the
#'        document is not UTF-8/16, and lacks an explicit encoding directive,
#'        this allows you to supply a default.
#' @return If the \code{query} result only has OSM \code{node}s then the function
#'         will return a \code{SpatialPointsDataFrame} with the \code{node}s.\cr\cr
#'         If the \code{query} result has OSM \code{way}s then the function
#'         will return a \code{SpatialLinesDataFrame} with the \code{way}s\cr\cr
#'         \code{relations}s are not handled yet.\cr\cr
#' @export
#' @examples
#' \dontrun{
#' mammoth <- read_osm(system.file("osm/mammoth.osm", package="overpass"))
#' }
read_osm <- function(osm_response, encoding = "") {

  doc <- xml2::read_xml(osm_response, encoding=encoding)

  process_doc(doc)

}
