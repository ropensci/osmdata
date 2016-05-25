#' get_ways
#'
#' Extracts ways from an overpass download.
#'
#' @param bbox the bounding box within which ways should be downloaded.  A
#' 2-by-2 matrix of 4 elements with columns of min and max values, and rows of x
#' and y values.
#'
#' @return A 'SpatialLinesDataFrame' object containing all the ways within
#' the given bounding box.
#' @export

get_ways <- function (bbox, key)
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

    dat <- httr::GET (query)
    if (dat$status_code != 200)
        warning (httr::http_status (dat)$message)
    # Encoding must be supplied to suppress warning
    txt <- httr::content (dat, "text", encoding='UTF-8')
    rcpp_get_ways (txt)
}
