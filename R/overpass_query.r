#' Issue OSM Overpass Query
#'
#' @param query OSM Overpass query. Please note that the function is in ALPHA
#'        dev stage and needs YOU to specify that the output type is XML.
#'        However, you can use Overpass XML or Overpass QL formats.
#' @note wrap function with \code{httr::with_verbose} if you want to see the \code{httr}
#'       query (useful for debugging connection issues)
#' @return If the \code{query} result only has OSM \code{node}s then the function
#'         will return a \code{SpatialPointsDataFrame} with the \code{node}s.\cr\cr
#'         If the \code{query} result has OSM \code{way}s then the function
#'         will return a \code{SpatialLinesDataFrame} with the \code{way}s\cr\cr
#'         \code{relations}s are not handled yet.\cr\cr
#'         If you asked for a CSV, you will receive the text response back, suitable for
#'         processing by \code{read.table(text=..., sep=..., check.names=FALSE, stringsAsFactors=FALSE)}.
#' @export
overpass_query <- function(query) {

  # make a query, get the result, parse xml
  res <- POST(overpass_base_url, body=query)
  stop_for_status(res)

  if (res$headers$`content-type` == "text/csv") {
    return(content(res, as="text"))
  }

  doc <- read_xml(content(res, as="text"))

  # which types of OSM things do we have?
  has_nodes <- has_xpath(doc, "//node")
  has_ways <- has_xpath(doc, "//way")
  has_relations <- has_xpath(doc, "//relation")

  # start crunching
  if (has_nodes) {
    osm_nodes <- process_osm_nodes(doc)
    # if we only have nodes return a SpatialPointsDataFrame
    if (!has_ways) return(osm_nodes_to_sptsdf(osm_nodes))
  }

  if (has_ways) {
    # gotta have nodes to make ways
    if (!has_nodes) stop("Cannot make ways if query results do not have nodes", call.=FALSE)
    osm_ways <- process_osm_ways(doc, osm_nodes)
    # TODO if we have relations we need to do more things
    return(osm_ways_to_spldf(doc, osm_ways))
  }

  # if we got here something is really wrong
  return(NULL)

}
