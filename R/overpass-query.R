#' Retrieve status of the Overpass API
#'
#' @param quiet if \code{FALSE} display a status message
#' @param wait If status is unavailable, wait this long (in s)
#' @return an invisible list of whether the API is available along with the
#'         text of the message from Overpass and the timestamp of the
#'         next available slot
#' @export
overpass_status <- function (quiet=FALSE, wait=10)
{
    available <- FALSE
    slot_time <- status <- st_type <- NULL

    overpass_url <- get_overpass_url ()
    st_type <- 'status'
    if (grepl ('vi-di', overpass_url) | grepl ('rambler', overpass_url))
        st_type <- 'timestamp'

    status_url <- gsub ('interpreter', st_type, overpass_url)

    if (!curl::has_internet ())
    {
        status <- 'No internet connection'
        if (!quiet) message (status)
    } else
    {
        ntrials <- 0
        while (is.null (status) & ntrials < 10)
        {
            ntrials <- ntrials + 1
            status <- httr::GET (status_url, httr::timeout (100))
        }
        if (!is.null (status))
        {
            status <- httr::content (status, encoding = 'UTF-8')
            if (st_type == 'status')
                slt <- get_slot_time (status = status, quiet = quiet)
            else if (st_type == 'timestamp')
                slt <- get_slot_timestamp (status = status)

            available <- slt$available
            slot_time <- slt$slot_time
        } else
        {
            # status not even returned so pause the whole shebang for 10 seconds
            slot_time <- lubridate::ymd_hms (lubridate::now () + 10)
            slot_time <- lubridate::force_tz (slot_time, tz = Sys.timezone ())
        }
    }

    return (invisible (list (available = available, next_slot = slot_time,
                             msg = status)))

}

# for APIs with status messages
get_slot_time <- function (status, quiet)
{
    status_now <- strsplit (status, '\n')[[1]][3]
    if (!quiet) message (status_now)

    if (grepl ('after', status_now)) {
        available <- FALSE
        slot_time <- lubridate::ymd_hms (gsub ('Slot available after: ',
                                               '', status_now))
        slot_time <- lubridate::force_tz (slot_time,
                                          tz = Sys.timezone ())
    } else {
        available <- TRUE
        slot_time <- Sys.time ()
    }

    list ('available' = available, 'slot_time' = slot_time)
}

# For APIs with only timestamps but no status
get_slot_timestamp <- function (status)
{
    slot_time <- NA
    available <- FALSE
    if (nchar (status) > 1)
        available <- TRUE

    list ('available' = available, 'slot_time' = slot_time)
}

#' Check for error issued by overpass server, even though status = 200
#'
#' @param doc Character string returned by \code{httr::content} call in
#' following \code{overpass_query} function.
#' @param return Nothing; stops execution if error encountered.
#'
#' @noRd
check_for_error <- function (doc)
{
    # the nchar check uses an arbitrary value to avoid trying to `read_xml()`
    # read data, which would take forever.
    if (grepl ("error: ", doc, ignore.case = TRUE) &
        nchar (doc) < 10000)
    {
        docx <- xml2::read_xml (doc)
        if (xml2::xml_length (docx) < 10) # arbitrarily low value
        {
            remark <- xml2::xml_text (xml2::xml_find_all (docx, "remark"))
            if (length (remark) > 1)
                stop (paste0 ("overpass", remark))
            else
                stop ("General overpass server error; returned:\n",
                      xml2::xml_text (docx))
        }
    }
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
#' @param encoding Unless otherwise specified XML documents are assumed to be
#'        encoded as UTF-8 or UTF-16. If the document is not UTF-8/16, and lacks
#'        an explicit encoding directive, this allows you to supply a default.
#'
#' @noRd
overpass_query <- function (query, quiet = FALSE, wait = TRUE, pad_wait = 5,
                            encoding = 'UTF-8') {

    if (missing (query))
        stop ('query must be supplied', call. = FALSE)
    if (!is.character (query) | length (query) > 1)
        stop ('query must be a single character string')

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
        stop ('Overpass query unavailable without internet', call. = FALSE)

    if (!quiet) message('Issuing query to Overpass API ...')

    o_stat <- overpass_status (quiet)

    if (encoding != 'pbf')
        overpass_url <- get_overpass_url ()
    else
        overpass_url <- 'http://dev.overpass-api.de/test753/interpreter'

    if (o_stat$available) {
        res <- httr::POST (overpass_url, body = query)
    } else {
        if (wait) {
            wait <- max(0, as.numeric (difftime (o_stat$next_slot, Sys.time(),
                                                 units = 'secs'))) + pad_wait
            message (sprintf ('Waiting %s seconds', wait))
            Sys.sleep (wait)
            res <- httr::POST (overpass_url, body = query)
        } else {
            stop ('Overpass query unavailable', call. = FALSE)
        }
    }
    if (!quiet) message ('Query complete!')

    if (class (res) == 'result') # differs only for mock tests
        httr::stop_for_status (res)

    if (encoding == 'pbf')
        doc <- httr::content (res, as = 'raw')
    else if (class (res) == 'raw') # for mock tests
        doc <- rawToChar (res)
    else
        doc <- httr::content (res, as = 'text', encoding = encoding,
                              type = "application/xml")
    # TODO: Just return the direct httr::POST result here and convert in the
    # subsequent functions (`osmdata_xml/csv/sp/sf`)?
    if (encoding != 'pbf')
        check_for_error (doc)

    return (doc)
}
