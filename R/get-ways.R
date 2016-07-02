#' get_ways
#'
#' Extracts ways from an overpass download.
#'
#' @param bbox the bounding box within which ways should be downloaded.  A
#' 2-by-2 matrix of 4 elements with columns of min and max values, and rows of x
#' and y values.
#' @param key The OpenStreetMap key to be passed to the overpass API query, or
#' to be extracted from pre-downloaded data passed as \code{url_download}
#' @param value OSM value to match to key. If \code{NULL}, all keys will be
#' returned.  Negation is specified by \code{!value}.
#' @param extra_pairs A list of additional \code{key-value} pairs to be passed
#' to the overpass API.
#' @param raw_data If TRUE, \code{get_ways} returns unprocessed data as directly
#' returned from the overpass API query.
#' @param verbose If TRUE, provides notification of progress
#'
#' @return A \code{SpatialLinesDataFrame} object containing all the ways within
#' the given bounding box.
#' @export

get_ways <- function (bbox, key, value, extra_pairs, raw_data=FALSE,
                      verbose=FALSE)
{
    if (missing (bbox))
        stop ("bbox must be provided")

    bbox <- paste0 ('(', bbox [2,1], ',', bbox [1,1], ',',
                    bbox [2,2], ',', bbox [1,2], ')')

    if (missing (key))
        key <- value <- ''
    else
    {
        if (key == 'park')
        {
            key <- 'leisure'
            value <- 'park'
        } else if (key == 'grass')
        {
            key <- 'landuse'
            value <- 'grass'
        } else if (key == 'tree')
        {
            key <- 'natural'
            value <- 'tree'
        }
    
        # Construct the overpass query, starting with main key-value pair and
        # possible negation
        if (!missing (value))
        {
            if (substring (value, 1, 1) == '!')
                value <- paste0 ("['", key, "'!='", 
                                substring (value, 2, nchar (value)), "']")
            else if (key == 'name')
                value <- paste0 ("['", key, "'~'", value, "']")
            else
                value <- paste0 ("['", key, "'='", value, "']")
        } else
            value <- ''
        if (key == 'name')
            key <- ''
        else
            key <- paste0 ("['", key, "']")
    }

    if (!missing (extra_pairs))
    {
        if (!is.list (extra_pairs))
            extra_pairs <- list (extra_pairs)
        ep <- NULL
        for (i in extra_pairs)
            ep <- paste0 (ep, "['", i [1], "'~'", i [2], "']")
        extra_pairs <- ep
    } else
        extra_pairs <- ''
        
    query <- paste0 ('(node', key, value, extra_pairs, bbox,
                    ';way', key, value, extra_pairs, bbox,
                    ';rel', key, value, extra_pairs, bbox, ';')
    url_base <- 'http://overpass-api.de/api/interpreter?data='
    query <- paste0 (url_base, query, ');(._;>;);out;')

    if (verbose) cat ("Downloading data ...")
    dat <- httr::GET (query)

    count <- 1
    # code#429 = "Too Many Requests (RFC 6585)"
    while (dat$status_code == 429 && count < 10)
    {
        dat <- httr::GET (query)
        count <- count + 1
    }

    if (dat$status_code != 200)
        warning (httr::http_status (dat)$message)
    # Encoding must be supplied to suppress warning
    result <- httr::content (dat, "text", encoding='UTF-8')
    if (verbose) cat (" done\n")

    if (!raw_data)
    {
        if (verbose) cat ("Processing data ...")
        result <- rcpp_get_ways (result)
        if (verbose) cat (" done\n")
    }
    return (result)
}
