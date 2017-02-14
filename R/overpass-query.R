#' Retrieve status of the Overpass API
#'
#' @param quiet if \code{FALSE} display a status message
#' @return an invisible list of whether the API is available along with the
#'         text of the message from Overpass and the timestamp of the
#'         next available slot
#' @export
overpass_status <- function (quiet=FALSE) {

  available <- FALSE
  slot_time <- NULL
  if (!curl::has_internet ())
  {
    status <- 'No internet connection'
    if (!quiet) message (status)
  } else
  {
    status <- httr::GET ('http://overpass-api.de/api/status', 
                         httr::timeout (100)) # don't timeout this!
    status <- httr::content (status)
    status_now <- strsplit (status, '\n')[[1]][4]

    if (!quiet) message (status_now)

    if (grepl ('after', status_now)) {
      available <- FALSE
      slot_time <- lubridate::ymd_hms (gsub ('Slot available after: ', '', 
                                           status_now))
      slot_time <- lubridate::force_tz (slot_time, tz = Sys.timezone ())
    } else {
      available <- TRUE
      slot_time <- Sys.time ()
    }
  }

  return (invisible (list (available=available, next_slot=slot_time, msg=status)))

}

#' Issue OSM Overpass Query
#'
#' @param query OSM Overpass query. Please note that the function is in ALPHA
#'        dev stage and needs YOU to specify that the output type is XML.
#'        However, you can use Overpass XML or Overpass QL formats.
#' @param quiet suppress status messages. OSM Overpass queries may not return
#'        quickly. The package will display status messages by default showing
#'        when the query started/completed.  You can disable these messages by
#'        setting this value to \code{TRUE}.
#' @param wait if \code{TRUE} and if there is a queue at the Overpass API
#'        server, should this function wait and try again at the next available
#'        slot time or should it throw a an exception?
#' @param pad_wait if there is a queue and \code{wait} is \code{TRUE}, pad the
#'        next query start time by \code{pad_wait} seconds (default = 5 seconds).
#' @param base_url the url of the server running overpass to be queried, set to
#'        \url{http://overpass-api.de/api/interpreter} by default.
#' @param encoding Unless otherwise specified XML documents are assumed to be
#'        encoded as UTF-8 or UTF-16. If the document is not UTF-8/16, and lacks
#'        an explicit encoding directive, this allows you to supply a default.
#'
#' @note wrap function with \code{httr::with_verbose} if you want to see the
#'       \code{httr} query (useful for debugging connection issues).\cr \cr 
#'
#' @return If the \code{query} result only has OSM \code{node}s then the
#'         function will return a \code{SpatialPointsDataFrame} with the
#'         \code{node}s.\cr\cr
#'         If the \code{query} result has OSM \code{way}s then the function will
#'         return a \code{SpatialLinesDataFrame} with the \code{way}s\cr\cr
#'         \code{relations}s are not handled yet.\cr\cr
#'         If you asked for a CSV, you will receive the text response back,
#'         suitable for processing by \code{read.table(text=..., sep=...,
#'         header=TRUE, check.names=FALSE, stringsAsFactors=FALSE)}.
#'
#' @export
overpass_query <- function (query, quiet=FALSE, wait=TRUE, pad_wait=5,
                            base_url='http://overpass-api.de/api/interpreter',
                            encoding) {

  if (missing (query))
    stop ('query must be supplied', call.=FALSE)
  if (!is.character (query) | length (query) > 1)
      stop ('query must be a single character string')
  if (missing (encoding)) # TODO: Delete that once this function is no longer exported
    encoding <- 'UTF-8'
  
  if (!is.logical (quiet))
    quiet <- FALSE
  if (!is.logical (wait))
    wait <- TRUE
  if (!is.numeric (pad_wait))
  {
    message ('pad_wait must be numeric; setting to 5s')
    pad_wait <- 5
  }
  if (pad_wait < 0)
  {
    warning ('pad_wait must be positive; setting to 5s')
    pad_wait <- 5
  }

  if (!curl::has_internet ())
      stop ('Overpass query unavailable without internet', call.=FALSE)
    
  if (!quiet) message('Issuing query to Overpass API ...')

  o_stat <- overpass_status (quiet)

  if (o_stat$available) {
    res <- httr::POST (base_url, body=query)
  } else {
    if (wait) {
       wait <- max(0, as.numeric(difftime(o_stat$next_slot, Sys.time(), 
                                          units = 'secs'))) + pad_wait
       message (sprintf ('Waiting %s seconds', wait))
       Sys.sleep (wait)
       #make_query (query, quiet)
       res <- httr::POST (base_url, body=query)
    } else {
      stop ('Overpass query unavailable', call.=FALSE)
    }
  }
  if (!quiet) message ('Query complete!')

  if (class (res) == 'result') # differs only for mock tests
    httr::stop_for_status (res)

  if (class (res) == 'raw') # for mock tests
      doc <- rawToChar (res)  
  else
      doc <- httr::content (res, as='text', encoding=encoding)
  # TODO: Just return the direct httr::POST result here and convert in the
  # subsequent functions (`osmdata_xml/csv/sp/sf`).

  return (doc)
}
