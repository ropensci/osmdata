#' get_ways
#'
#' Extracts ways from an overpass download.
#'
#' @param bbox the bounding box within which ways should be downloaded.  A
#' 2-by-2 matrix of 4 elements with columns of min and max values, and rows of x
#' and y values.
#' @param key The OpenStreetMap key to be passed to the overpass API query, or
#' to be extracted from pre-downloaded data passed as \code{url_download}
#' @param url_download Data as directly downloaded from the overpass API and
#' returned with \code{raw_data=TRUE}. This may be subsequently passed to
#' \code{get_ways} in order to extract particular \code{key-value} combinations
#' @param raw_data If TRUE, \code{get_ways} returns unprocessed data as directly
#' returned from the overpass API query.
#' @param verbose If TRUE, provides notification of progress
#'
#' @return A \code{SpatialLinesDataFrame} object containing all the ways within
#' the given bounding box.
#' @export

get_ways <- function (bbox, key, url_download, raw_data=FALSE,
                       verbose=FALSE)
{
    if (missing (url_download))
    {
        if (missing (bbox))
            stop ("bbox must be provided")

        bbox <- paste0 ('(', bbox [2,1], ',', bbox [1,1], ',',
                        bbox [2,2], ',', bbox [1,2], ')')

        if (missing (key))
            key <- ''
        else
            key <- paste0 ("['", key, "']")
        
        query <- paste0 ('(node', key, bbox,
                        ';way', key, bbox,
                        ';rel', key, bbox, ';')
        url_base <- 'http://overpass-api.de/api/interpreter?data='
        query <- paste0 (url_base, query, ');(._;>;);out;')

        if (verbose) cat ("Downloading data ...")
        dat <- httr::GET (query)
        if (dat$status_code != 200)
            warning (httr::http_status (dat)$message)
        # Encoding must be supplied to suppress warning
        result <- httr::content (dat, "text", encoding='UTF-8')
        if (verbose) cat (" done\n")
    } else
        result <- url_download 
    if (!raw_data)
    {
        if (verbose) cat ("Processing data ...")
        result <- rcpp_get_ways (result)
        if (verbose) cat (" done\n")
    }
    return (result)
}
