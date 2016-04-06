#' get_xml_doc
#'
#' Stripped from 'osmplotr/extract_osm_objects' to extract highways only for
#' timing comparison.
#'
#' @param bbox the bounding box within which highways should be downloaded.  A
#' 2-by-2 matrix of 4 elements with columns of min and max values, and rows of x
#' and y values.
#'
#' @return An XML 'XMLAbstractDocument'
#' @export

get_xml_doc <- function (bbox=NULL)
{
    bbox <- paste0 ('(', bbox [2,1], ',', bbox [1,1], ',',
                    bbox [2,2], ',', bbox [1,2], ')')

    key <- "['highway']"
    query <- paste0 ('(node', key, bbox,
                    ';way', key, bbox,
                    ';rel', key, bbox, ';')
    url_base <- 'http://overpass-api.de/api/interpreter?data='
    query <- paste0 (url_base, query, ');(._;>;);out;')

    dat <- httr::GET (query)
    if (dat$status_code != 200)
        warning (httr::http_status (dat)$message)
    # Encoding must be supplied to suppress warning
    XML::xmlParse (httr::content (dat, "text", encoding='UTF-8'))
}

#' process_xml_doc
#'
#' Adapted from 'osmplotr/extract_osm_objects' to extract SpatialLines from an
#' XML doc extracted with 'get_xml_doc'
#'
#' @param doc An XML document extracted with 'get_xml_doc'
#'
#' @return A SpatialLinesDataFrame
#' @export
#' 
#' @examples
#' bbox <- matrix (c (-0.13, 51.5, -0.11, 51.52), nrow=2, ncol=2)
#' doc <- get_xml_doc (bbox=bbox)
#' obj <- process_xml_doc (doc)

process_xml_doc <- function (doc)
{
    dato <- osmar::as_osmar (doc)
    # See 'extract_osm_objects' for explanation of the next 3 lines
    for (i in seq (dato$relations))
        if (nrow (dato$relations [[i]]) > 0)
            dato$relations [[i]]$id <- paste0 ("r", dato$relations [[i]]$id)
    pids <- osmar::find (dato, osmar::way (osmar::tags(k == 'highway')))
    
    pids1 <- osmar::find_down (dato, osmar::way (pids))
    pids2 <- osmar::find_up (dato, osmar::way (pids))
    pids <- mapply (c, pids1, pids2, simplify=FALSE)
    pids <- lapply (pids, function (i) unique (i))
    nvalid <- sum (sapply (pids, length))
    if (nvalid <= 3) # (nodes, ways, relations)
        stop ('No valid data')
    else
    {
        obj <- subset (dato, ids = pids)
        obj <- osmar::as_sp (obj, 'lines')
    }

    return (obj)
}
