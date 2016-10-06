#' Retrieve status of the Overpass API
#'
#' @param quiet if \code{FALSE} display a status message
#' @return an invisible list of whether the API is available along with the
#'         text of the message from Overpass and the timestamp of the
#'         next avaialble slot
#' @export
#' @author Maëlle Salmon
#' overpass_status()
overpass_status <- function(quiet=FALSE) {

  status <- httr::GET("http://overpass-api.de/api/status")
  status <- httr::content(status)
  status_now <- strsplit(status, "\n")[[1]][3]

  if (!quiet) message(status_now)

  if (grepl("after", status_now)) {
    slot_time <- lubridate::ymd_hms(gsub("Slot available after: ", "", status_now))
    slot_time <- slot_timeupdate(slot_time, hour = hour(slot_time) + 2)
    slot_time <- slot_timeforce_tz(slot_time, tz = Sys.timezone())
  } else {
    slot_time <- Sys.time()
  }

  return(invisible(list(available=TRUE, next_slot=slot_time, msg=status_now)))

}

make_query <- function(query, quiet=FALSE) {

  # make a query, get the result, parse xml
  res <- httr::POST(overpass_base_url, body=query)
  httr::stop_for_status(res)
  if (!quiet) message("Query complete!")

  if (res$headers$`content-type` == "text/csv") {
    return(httr::content(res, as="text", encoding="UTF-8"))
  }

  doc <- xml2::read_xml(httr::content(res, as="text", encoding="UTF-8"))

  process_doc(doc)

}

#' Issue OSM Overpass Query
#'
#' @param query OSM Overpass query. Please note that the function is in ALPHA
#'        dev stage and needs YOU to specify that the output type is XML.
#'        However, you can use Overpass XML or Overpass QL formats.
#' @param quiet suppress status messages. OSM Overpass queries may not return quickly. The
#'        package will display status messages by default showing when the query started/completed.
#'        You can disable these messages by setting this value to \code{TRUE}.
#' @param wait if \code{TRUE} and if there is a queue at the Overpass API server, should
#'        this function wait and try again at the next available slot time or should it
#'        throw a an exception?
#' @note wrap function with \code{httr::with_verbose} if you want to see the \code{httr}
#'       query (useful for debugging connection issues).\cr
#'       \cr
#'       You can disable progress bars by calling \code{pbapply::pboptions(type="none")} in your
#'       code. See \code{\link[pbapply]{pboptions}} for all the various progress bar settings.
#' @return If the \code{query} result only has OSM \code{node}s then the function
#'         will return a \code{SpatialPointsDataFrame} with the \code{node}s.\cr\cr
#'         If the \code{query} result has OSM \code{way}s then the function
#'         will return a \code{SpatialLinesDataFrame} with the \code{way}s\cr\cr
#'         \code{relations}s are not handled yet.\cr\cr
#'         If you asked for a CSV, you will receive the text response back, suitable for
#'         processing by \code{read.table(text=..., sep=..., header=TRUE, check.names=FALSE, stringsAsFactors=FALSE)}.
#' @export
#' @examples \dontrun{
#' only_nodes <- '[out:xml];
#' node
#'   ["highway"="bus_stop"]
#'   ["shelter"]
#'   ["shelter"!~"no"]
#'   (50.7,7.1,50.8,7.25);
#' out body;'
#'
#' pts <- overpass_query(only_nodes)
#' }
overpass_query <- function(query, quiet=FALSE, wait=TRUE) {

  if (!quiet) message("Issuing query to OSM Overpass...")

  o_stat <- overpass_status(quiet)

  if (o_stat$available) {
    make_query(query, quiet)
  } else {
    if (wait) {
       wait <- max(0, as.numeric(difftime(o_stat$next_slot, Sys.time(), units = "secs"))) + 5
       message(sprintf("Waiting %s seconds", wait))
       Sys.sleep(wait)
       make_query(query, quiet)
    } else {
      stop("Overpass query unavailable", call.=FALSE)
    }
  }

}
