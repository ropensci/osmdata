#' Retrieve status of the Overpass API
#'
#' @param quiet if `FALSE` display a status message
#' @return an invisible list of whether the API is available along with the
#'         text of the message from Overpass and the timestamp of the
#'         next available slot
#' @export
overpass_status <- function (quiet=FALSE)
{
    available <- FALSE
    slot_time <- status <- st_type <- NULL

    overpass_url <- get_overpass_url ()
    st_type <- 'status'
    if (grepl ('vi-di', overpass_url) | grepl ('rambler', overpass_url)) # nocov
        st_type <- 'timestamp'                                           # nocov

    status_url <- gsub ('interpreter', st_type, overpass_url)

    if (!curl::has_internet ())
    {
        status <- 'No internet connection'      # nocov
        if (!quiet) message (status)            # nocov
    } else
    {
        status <- httr::RETRY ("GET", status_url, timeout = 100,
                               times = 10)
        if (!is.null (status))
        {
            status <- httr::content (status, encoding = 'UTF-8')
            if (st_type == 'status')
                slt <- get_slot_time (status = status, quiet = quiet)
            else if (st_type == 'timestamp')                # nocov
                slt <- get_slot_timestamp (status = status) # nocov

            available <- slt$available
            slot_time <- slt$slot_time
        } else
        {
            # status not even returned so pause the whole shebang for 10 seconds
            # nocov start
            slot_time <- lubridate::ymd_hms (lubridate::now () + 10)
            slot_time <- lubridate::force_tz (slot_time, tz = Sys.timezone ())
            # nocov end
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
        # nocov start
        available <- FALSE
        slot_time <- lubridate::ymd_hms (gsub ('Slot available after: ',
                                               '', status_now))
        slot_time <- lubridate::force_tz (slot_time,
                                          tz = Sys.timezone ())
        # nocov end
    } else {
        available <- TRUE
        slot_time <- Sys.time ()
    }

    list ('available' = available, 'slot_time' = slot_time)
}

# For APIs with only timestamps but no status
get_slot_timestamp <- function (status)
{
    # nocov start
    slot_time <- NA
    available <- FALSE
    if (nchar (status) > 1)
        available <- TRUE

    list ('available' = available, 'slot_time' = slot_time)
    # nocov end
}

#' Check for error issued by overpass server, even though status = 200
#'
#' @param doc Character string returned by `httr::content` call in
#' following `overpass_query` function.
#' @param return Nothing; stops execution if error encountered.
#'
#' @noRd
check_for_error <- function (doc)
{
    # the nchar check uses an arbitrary value to avoid trying to `read_xml()`
    # read data, which would take forever.
    # nocov start
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
    # nocov end
}


#' Issue OSM Overpass Query
#'
#' @param query OSM Overpass query. Please note that the function is in ALPHA
#'        dev stage and needs YOU to specify that the output type is XML.
#'        However, you can use Overpass XML or Overpass QL formats.
#' @param quiet suppress status messages. OSM Overpass queries may not return
#'        quickly. The package will display status messages by default showing
#'        when the query started/completed.  You can disable these messages by
#'        setting this value to `TRUE`.
#' @param wait if `TRUE` and if there is a queue at the Overpass API
#'        server, should this function wait and try again at the next available
#'        slot time or should it throw a an exception?
#' @param pad_wait if there is a queue and `wait` is `TRUE`, pad the
#'        next query start time by `pad_wait` seconds (default = 5 seconds).
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
        stop ('Overpass query unavailable without internet',    # nocov
              call. = FALSE)                                    # nocov

    if (!quiet) message('Issuing query to Overpass API ...')

    o_stat <- overpass_status (quiet)

    overpass_url <- get_overpass_url ()

    if (o_stat$available) {
        res <- httr::RETRY ("POST", overpass_url, body = query)
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
        httr::stop_for_status (res)                             # nocov

    else if (class (res) == 'raw') # for mock tests
        doc <- rawToChar (res)
    else
        doc <- httr::content (res, as = 'text', encoding = encoding,
                              type = "application/xml")
    # TODO: Just return the direct httr::POST result here and convert in the
    # subsequent functions (`osmdata_xml/csv/sp/sf`)?
    check_for_error (doc)

    return (doc)
}
