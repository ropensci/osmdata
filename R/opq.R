#' Build an Overpass query
#'
#' @param bbox Either (i) four numeric values specifying the maximal and minimal
#'             longitudes and latitudes; (ii) a character string passed to
#'             \link{getbb} to be converted to a numerical bounding box; or
#'             (iii) a matrix representing a bounding polygon as returned from
#'             \code{getbb(..., format_out = "polygon")}.
#' @param timeout It may be necessary to ncrease this value for large queries,
#'             because the server may time out before all data are delivered.
#' @param memsize The default memory size for the 'overpass' server; may need to
#'             be increased in order to handle large queries.
#'
#' @return An \code{overpass_query} object
#'
#' @note See
#' \url{https://wiki.openstreetmap.org/wiki/Overpass_API#Resource_management_options_.28osm-script.29}
#' for explanation of \code{timeout} and \code{memsize} (or \code{maxsize} in
#' overpass terms).
#'
#' @export
#'
#' @examples
#' \dontrun{
#' q <- getbb ("portsmouth", display_name_contains = "United States") %>%
#'             opq () %>% 
#'             add_osm_feature("amenity", "restaurant") %>%
#'             add_osm_feature("amenity", "pub") 
#' osmdata_sf (q) # all objects that are restaurants AND pubs (there are none!)
#' q1 <- getbb ("portsmouth", display_name_contains = "United States") %>%
#'                 opq () %>% 
#'                 add_osm_feature("amenity", "restaurant") 
#' q2 <- getbb ("portsmouth", display_name_contains = "United States") %>%
#'                 opq () %>% 
#'                 add_osm_feature("amenity", "pub") 
#' c (osmdata_sf (q1), osmdata_sf (q2)) # all objects that are restaurants OR pubs
#' }
opq <- function (bbox = NULL, timeout = 25, memsize)
{
    timeout <- format (timeout, scientific = FALSE)
    prefix <- paste0 ("[out:xml][timeout:", timeout, "]")
    if (!missing (memsize))
        prefix <- paste0 (prefix, "[maxsize:",
                          format (memsize, scientific = FALSE), "]")
    res <- list (bbox = bbox_to_string (bbox),
              prefix = paste0 (prefix, ";\n(\n"),
              suffix = ");\n(._;>);\nout body;", features = NULL)
    class (res) <- c (class (res), "overpass_query")
    return (res)
}

#' Add a feature to an Overpass query
#'
#' @param opq An \code{overpass_query} object
#' @param key feature key
#' @param value value for feature key; can be negated with an initial
#' exclamation mark, \code{value = "!this"}.
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
#' \code{available_features}. Setting \code{key_exact = FALSE} allows matching
#' of regular expressions on OSM keys, as described in Section 6.1.5 of
#' \url{http://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL}. The actual
#' query submitted to the overpass API can be obtained from
#' \link{opq_string}.
#'
#' @note \code{add_feature} is deprecated; please use \code{add_osm_feature}.
#'
#' @references \url{http://wiki.openstreetmap.org/wiki/Map_Features}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' q <- getbb ("portsmouth", display_name_contains = "United States") %>%
#'                 opq () %>% 
#'                 add_osm_feature("amenity", "restaurant") %>%
#'                 add_osm_feature("amenity", "pub") 
#' osmdata_sf (q) # all objects that are restaurants AND pubs (there are none!)
#' q1 <- getbb ("portsmouth", display_name_contains = "United States") %>%
#'                 opq () %>% 
#'                 add_osm_feature("amenity", "restaurant") 
#' q2 <- getbb ("portsmouth", display_name_contains = "United States") %>%
#'                 opq () %>% 
#'                 add_osm_feature("amenity", "pub") 
#' c (osmdata_sf (q1), osmdata_sf (q2)) # all objects that are restaurants OR pubs
#' # Use of negation to extract all non-primary highways
#' q <- opq ("portsmouth uk") %>%
#'         add_osm_feature (key="highway", value = "!primary") 
#' }
add_osm_feature <- function (opq, key, value, key_exact = TRUE,
                             value_exact = TRUE, match_case = TRUE, bbox = NULL)
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
        value <- NULL
    if (is.null (value))
    {
        feature <- paste0 (sprintf (' ["%s"]', key))
    } else
    {
        if (substring (value, 1, 1) == "!")
        {
            bind <- paste0 ("!", bind)
            value <- substring (value, 2, nchar (value))
            if (key_pre == "~")
            {
                message ("Value negation only possible for exact keys")
                key_pre <- ""
            }
        }
        feature <- paste0 (sprintf (' [%s"%s"%s"%s"',
                                    key_pre, key, bind, value))
        if (!match_case)
            feature <- paste0 (feature, ",i")
        feature <- paste0 (feature, "]")
    }

    opq$features <- c(opq$features, feature)

    if (is.null (opq$suffix))
        opq$suffix <- ");\n(._;>);\nout body;"
    #opq$suffix <- ");\n(._;>);\nout qt body;"
    # qt option is not compatible with sf because GDAL requires nodes to be
    # numerically sorted

    opq
}

#' @rdname add_osm_feature
#' @export
add_feature <- function (opq, key, value, key_exact = TRUE,
                             value_exact = TRUE, match_case = TRUE, bbox = NULL)
{
    message ('add_feature() is deprecated; please use add_osm_feature()')
    add_osm_feature (opq, key, value, key_exact = TRUE,
                     value_exact = TRUE, match_case = TRUE, bbox = NULL)
}

#' Convert an overpass query into a text string
#'
#' Convert an osmdata query of class opq to a character string query to
#' be submitted to the overpass API.
#'
#' @param opq An \code{overpass_query} object
#' @return Character string to be submitted to the overpass API
#' 
#' @export
#' @aliases opq_to_string
#'
#' @examples
#' q <- opq ("hampi india")
#' opq_string (q)
opq_string <- function (opq)
{
  features <- paste (opq$features, collapse = '')
  features <- paste0 (sprintf (' node %s (%s);\n', features, opq$bbox),
                      sprintf (' way %s (%s);\n', features, opq$bbox),
                      sprintf (' relation %s (%s);\n\n', features,
                               opq$bbox))
  paste0 (opq$prefix, features, opq$suffix)
}
