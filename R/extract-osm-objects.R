#' extract_osm_objects
#'
#' Stripped from 'osmplotr/extract_osm_objects' to extract highways only for
#' timing comparison.
#'
#' @param bbox the bounding box within which highways should be downloaded.  A
#' 2-by-2 matrix of 4 elements with columns of min and max values, and rows of x
#' and y values.
#'
#' @return A data frame of sp objects
#' @export
#'
#' @examples
#' bbox <- matrix (c (-0.13, 51.5, -0.11, 51.52), nrow=2, ncol=2)
#' obj <- extract_osm_objects (bbox=bbox)

extract_osm_objects <- function (bbox=NULL)
{
    stopifnot (is.numeric (bbox))
    stopifnot (length (bbox) == 4)
    bbox <- paste0 ('(', bbox [2,1], ',', bbox [1,1], ',',
                    bbox [2,2], ',', bbox [1,2], ')')

    key <- "['highway']"
    query <- paste0 ('(node', key, bbox,
                    ';way', key, bbox,
                    ';rel', key, bbox, ';')
    url_base <- 'http://overpass-api.de/api/interpreter?data='
    query <- paste0 (url_base, query, ');(._;>;);out;')

    message ("downloading OSM data ... ")
    dat <- httr::GET (query)
    if (dat$status_code != 200)
        warn <- httr::http_status (dat)$message
    # Encoding must be supplied to suppress warning
    dat <- XML::xmlParse (httr::content (dat, "text", encoding='UTF-8'))

    message ("converting OSM data to omsar format")
    dato <- osmar::as_osmar (dat)
    # A very important NOTE: It can arise the OSM relations have IDs which
    # duplicate IDs in OSM ways, even through the two may bear no relationship
    # at all. This causes the attempt in `osmar::as_sp` to force them to an `sp`
    # object to crash because 
    # # Error in validObject(.Object) :
    # #   invalid class "SpatialLines" object: non-unique Lines ID of slot values
    # The IDs are actually neither needed not used, so the next lines simply
    # modifies all relation IDs by pre-pending "r" to avoid such problems:
    for (i in seq (dato$relations))
        if (nrow (dato$relations [[i]]) > 0)
            dato$relations [[i]]$id <- paste0 ("r", dato$relations [[i]]$id)
    pids <- osmar::find (dato, osmar::way (osmar::tags(k == 'highway')))
    
    message ("converting osmar data to sp format")
    pids1 <- osmar::find_down (dato, osmar::way (pids))
    pids2 <- osmar::find_up (dato, osmar::way (pids))
    pids <- mapply (c, pids1, pids2, simplify=FALSE)
    pids <- lapply (pids, function (i) unique (i))
    nvalid <- sum (sapply (pids, length))
    if (nvalid <= 3) # (nodes, ways, relations)
        warn <- paste0 ('No valid data')
    else
    {
        obj <- subset (dato, ids = pids)
        obj <- osmar::as_sp (obj, 'lines')
    }

    return (obj)
}
