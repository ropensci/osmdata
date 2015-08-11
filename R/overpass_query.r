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
#'         processing by \code{read.table(text=..., sep=..., header=TRUE, check.names=FALSE, stringsAsFactors=FALSE)}.
#' @export
overpass_query <- function(query) {

  # make a query, get the result, parse xml
  res <- POST(overpass_base_url, body=query)
  stop_for_status(res)

  if (res$headers$`content-type` == "text/csv") {
    return(content(res, as="text"))
  }

  doc <- read_xml(content(res, as="text"))

  process_doc(doc)

}
