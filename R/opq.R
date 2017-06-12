#' Build an Overpass query
#'
#' @param bbox Either four numeric values specifying the maximal and minimal
#'             longitudes and latitudes, or else a character string passed to
#'             \link{getbb} to be converted to a numerical bounding box.
#'
#' @return An \code{overpass_query} object
#'
#' @export
#'
#' @examples
#' \dontrun{
#' q <- getbb ("portsmouth", display_name_contains="United States") %>% opq () %>% 
#'         add_feature("amenity", "restaurant") %>%
#'         add_feature("amenity", "pub") 
#' osmdata_sf (q) # all objects that are restaurants AND pubs (there are none!)
#' q1 <- getbb ("portsmouth", display_name_contains="United States") %>% opq () %>% 
#'         add_feature("amenity", "restaurant") 
#' q2 <- getbb ("portsmouth", display_name_contains="United States") %>% opq () %>% 
#'         add_feature("amenity", "pub") 
#' c (osmdata_sf (q1), osmdata_sf (q1)) # all objects that are restaurants OR pubs
#' }
opq <- function (bbox=NULL)
{
    # TODO: Do we really need these [out:xml][timeout] specifiers?
    res <- list (bbox = bbox_to_string (bbox),
              prefix = "[out:xml][timeout:25];\n(\n",
              suffix = ");\n(._;>);\nout body;", features = NULL)
    class (res) <- c (class (res), "overpass_query")
    return (res)
}

#' Add a feature to an Overpass query
#'
#' @param opq An \code{overpass_query} object
#' @param key feature key
#' @param value value for feature key; can be negated with an initial
#' exclamation mark, \code{value="!this"}.
#' @param key_exact If FALSE, \code{key} is not interpreted exactly; see
#' \url{https://wiki.openstreetmap.org/wiki/Overpass_API}
#' @param value_exact If FALSE, \code{value} is not interpreted exactly
#' @param match_case If FALSE, matching for both \code{key} and \code{value} is
#' not sensitive to case
#' @param bbox optional bounding box for the feature query; must be set if no
#'        opq query bbox has been set
#' @return \code{opq} object
#' 
#' @note \code{key_exact} should generally be \code{TRUE}, because OSM uses a
#' reasonably well defined set of possible keys, as returned by
#' \code{available_features}. Setting \code{key_exact=FALSE} allows matching of
#' regular expressions on OSM keys, as described in Section 6.1.5 of
#' \url{http://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL}. The actual
#' query submitted to the overpass API can be obtained from
#' \link{opq_string}.
#'
#' @references \url{http://wiki.openstreetmap.org/wiki/Map_Features}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' q <- getbb ("portsmouth", display_name_contains="United States") %>% opq () %>% 
#'         add_feature("amenity", "restaurant") %>%
#'         add_feature("amenity", "pub") 
#' osmdata_sf (q) # all objects that are restaurants AND pubs (there are none!)
#' q1 <- getbb ("portsmouth", display_name_contains="United States") %>% opq () %>% 
#'         add_feature("amenity", "restaurant") 
#' q2 <- getbb ("portsmouth", display_name_contains="United States") %>% opq () %>% 
#'         add_feature("amenity", "pub") 
#' c (osmdata_sf (q1), osmdata_sf (q1)) # all objects that are restaurants OR pubs
#' # Use of negation to extract all non-primary highways
#' q <- opq ("portsmouth uk") %>% add_feature (key="highway", value="!primary") 
#' }
add_feature <- function (opq, key, value, key_exact=TRUE, value_exact=TRUE,
                         match_case=TRUE, bbox=NULL)
{
    if (missing (key))
        stop ('key must be provided')

    if (is.null (bbox) & is.null (opq$bbox))
        stop ('Bounding box has to either be set in opq or must be set here')

    if (is.null (bbox))
        bbox <- opq$bbox
    else
    {
        bbox <- bbox_to_string (bbox)
        opq$bbox <- bbox
    }

    if (value_exact)
        bind <- '='
    else
        bind <- '~'
    key_pre <- ""
    if (!key_exact)
        key_pre <- "~"

    if (missing (value))
    {
        feature <- paste0 (sprintf (' ["%s"]', key))
    } else
    {
        if (substring (value, 1, 1) == "!")
        {
            bind <- paste0 ("!", bind)
            value <- substring (value, 2, nchar (value))
        }
        feature <- paste0 (sprintf (' [%s"%s"%s"%s"', 
                                    key_pre, key, bind, value))
        if (!match_case)
            feature <- paste0 (feature, ",i")
        feature <- paste0 (feature, "]")
        #feature <- paste0 (sprintf (' ["%s"%s"%s"]', key, bind, value))
    }

    opq$features <- c(opq$features, feature)

    if (is.null (opq$suffix))
        opq$suffix <- ");\n(._;>);\nout body;"
    #opq$suffix <- ");\n(._;>);\nout qt body;"
    # qt option is not compatible with sf because GDAL requires nodes to be
    # numerically sorted

    opq
}
