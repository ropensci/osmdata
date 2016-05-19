#' get_xml_doc3
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

get_xml_doc3 <- function (bbox=NULL)
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
    httr::content (dat, "text", encoding='UTF-8')
}

#' process_xml_doc3
#'
#' @param doc A text document extracted with 'get_xml_doc3'
#'
#' @return A SpatialLinesDataFrame
#' @export
#' 
#' @examples
#' bbox <- matrix (c (-0.13, 51.5, -0.11, 51.52), nrow=2, ncol=2)
#' doc <- get_xml_doc (bbox=bbox)
#' obj <- process_xml_doc (doc)

process_xml_doc3 <- function (txt)
{
    dat <- get_highways (txt)
    nd <- names (dat)
    # Duplicated OSM IDs do occur (rarely), and will crash sp
    while (any (duplicated (nd)))
    {
        indx <- which (duplicated (nd))
        nd [indx] <- paste0 (round (runif (length (indx)) * 1e6))
    }
    for (i in seq (dat)) 
    {
        di <- data.frame (do.call (rbind,  dat [[i]]))
        names (di) <- c ('x', 'y')
        dat [[i]] <- sp::Lines (sp::Line (di), ID=nd [i])
    }
    sp::SpatialLines (dat)
}
