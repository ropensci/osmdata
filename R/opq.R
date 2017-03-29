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
#' @param value value for feature key
#' @param exact If FALSE, \code{value} is not interpreted exactly; see
#' \url{http://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide#Non-exact_names}
#' @param bbox optional bounding box for the feature query; must be set if no
#'        opq query bbox has been set
#' @return \code{opq} object
#' 
#' @note Values can be negated by pre-pending \code{!}. The actual query
#' submitted to the overpass API can be obtained from \link{opq_to_string}
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
add_feature <- function (opq, key, value, exact=TRUE, bbox=NULL)
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

    if (exact)
        bind <- '='
    else
        bind <- '~'

    if (missing (value))
    {
        feature <- paste0 (sprintf (' ["%s"]', key))
    } else
    {
        if (substring (value, 1, 1) == "1")
        {
            bind <- paste0 ("!", bind)
            value <- substring (value, 2, nchar (value))
        }
        feature <- paste0 (sprintf (' ["%s"%s"%s"]', key, bind, value))
    }

    opq$features <- c(opq$features, feature)

    if (is.null (opq$suffix))
        opq$suffix <- ");\n(._;>);\nout body;"
    #opq$suffix <- ");\n(._;>);\nout qt body;"
    # qt option is not compatible with sf because GDAL requires nodes to be
    # numerically sorted

    opq
}

#' Convert an osmdata query of class \code{opq} to a character string query to
#' be submitted to the overpass API
#'
#' @param opq An \code{overpass_query} object
#' @return Character string to be submitted to the overpass API
#' 
#' @export
#'
#' @examples
#' q <- opq ("hampi india")
#' opq_to_string (q)
opq_to_string <- function (opq)
{
    features <- paste (opq$features, collapse = '')
    features <- paste0 (sprintf (' node %s (%s);\n', features, opq$bbox),
                        sprintf (' way %s (%s);\n', features, opq$bbox),
                        sprintf (' relation %s (%s);\n\n', features,
                                 opq$bbox))
    paste0 (opq$prefix, features, opq$suffix)
}
