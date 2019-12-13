#' Build an Overpass query
#'
#' @param bbox Either (i) four numeric values specifying the maximal and minimal
#'      longitudes and latitudes, in the form \code{c(xmin, ymin, xmax, ymax)}
#'      or (ii) a character string in the form \code{xmin,ymin,xmax,ymax}. These
#'      will be passed to \link{getbb} to be converted to a numerical bounding
#'      box. Can also be (iii) a matrix representing a bounding polygon as
#'      returned from `getbb(..., format_out = "polygon")`.
#' @param timeout It may be necessary to increase this value for large queries,
#'      because the server may time out before all data are delivered.
#' @param memsize The default memory size for the 'overpass' server in *bytes*;
#'      may need to be increased in order to handle large queries.
#'
#' @return An `overpass_query` object
#'
#' @note See
#' <https://wiki.openstreetmap.org/wiki/Overpass_API#Resource_management_options_.28osm-script.29>
#' for explanation of `timeout` and `memsize` (or `maxsize` in overpass terms).
#' Note in particular the comment that queries with arbitrarily large `memsize`
#' are likely to be rejected.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' q <- getbb ("portsmouth", display_name_contains = "USA") %>%
#'             opq () %>%
#'             add_osm_feature("amenity", "restaurant") %>%
#'             add_osm_feature("amenity", "pub")
#' osmdata_sf (q) # all objects that are restaurants AND pubs (there are none!)
#' q1 <- getbb ("portsmouth", display_name_contains = "USA") %>%
#'                 opq () %>%
#'                 add_osm_feature("amenity", "restaurant")
#' q2 <- getbb ("portsmouth", display_name_contains = "USA") %>%
#'                 opq () %>%
#'                 add_osm_feature("amenity", "pub")
#' c (osmdata_sf (q1), osmdata_sf (q2)) # all restaurants OR pubs
#' }
opq <- function (bbox = NULL, timeout = 25, memsize)
{
    timeout <- format (timeout, scientific = FALSE)
    prefix <- paste0 ("[out:xml][timeout:", timeout, "]")
    suffix <- ");\n(._;>;);\nout body;" # recurse down
    if (!missing (memsize))
        prefix <- paste0 (prefix, "[maxsize:",                          # nocov
                          format (memsize, scientific = FALSE), "]")    # nocov
    res <- list (bbox = bbox_to_string (bbox),
              prefix = paste0 (prefix, ";\n(\n"),
              suffix = suffix, features = NULL)
    class (res) <- c (class (res), "overpass_query")
    return (res)
}

#' Add a feature to an Overpass query
#'
#' @param opq An `overpass_query` object
#' @param key feature key
#' @param value value for feature key; can be negated with an initial
#' exclamation mark, `value = "!this"`, and can also be a vector,
#' `value = c ("this", "that")`.
#' @param key_exact If FALSE, `key` is not interpreted exactly; see
#' <https://wiki.openstreetmap.org/wiki/Overpass_API>
#' @param value_exact If FALSE, `value` is not interpreted exactly
#' @param match_case If FALSE, matching for both `key` and `value` is
#' not sensitive to case
#' @param bbox optional bounding box for the feature query; must be set if no
#'        opq query bbox has been set
#' @return \link{opq} object
#'
#' @note `key_exact` should generally be `TRUE`, because OSM uses a
#' reasonably well defined set of possible keys, as returned by
#' \link{available_features}. Setting `key_exact = FALSE` allows matching
#' of regular expressions on OSM keys, as described in Section 6.1.5 of
#' <https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL>. The actual
#' query submitted to the overpass API can be obtained from
#' \link{opq_string}.
#'
#' @note \link{add_feature} is deprecated; please use \link{add_osm_feature}.
#'
#' @references <https://wiki.openstreetmap.org/wiki/Map_Features>
#'
#' @export
#'
#' @examples
#' \dontrun{
#' q <- opq ("portsmouth usa") %>%
#'                 add_osm_feature(key = "amenity",
#'                                 value = "restaurant") %>%
#'                 add_osm_feature(key = "amenity", value = "pub")
#' osmdata_sf (q) # all objects that are restaurants AND pubs (there are none!)
#' q1 <- opq ("portsmouth usa") %>%
#'                 add_osm_feature(key = "amenity",
#'                                 value = "restaurant")
#' q2 <- opq ("portsmouth usa") %>%
#'                 add_osm_feature(key = "amenity", value = "pub")
#' c (osmdata_sf (q1), osmdata_sf (q2)) # all restaurants OR pubs
#' # Use of negation to extract all non-primary highways
#' q <- opq ("portsmouth uk") %>%
#'         add_osm_feature (key = "highway", value = "!primary")
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

    if (!key_exact & value_exact)
    {
        message ("key_exact = FALSE can only combined with ",
                 "value_exact = FALSE; setting value_exact = FALSE")
        value_exact <- FALSE
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
        if (length (value) > 1)
        {
            # convert to OR'ed regex:
            value <- paste0 (value, collapse = "|")
            if (value_exact)
                value <- paste0 ("^(", value, ")$")
            bind <- "~"
        } else if (substring (value, 1, 1) == "!")
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
        opq$suffix <- ");\n(._;>;);\nout body;"
    #opq$suffix <- ");\n(._;>);\nout qt body;"
    # qt option is not compatible with sf because GDAL requires nodes to be
    # numerically sorted

    opq
}

#' Add a feature specified by OSM ID to an Overpass query
#'
#' @param id One or more official OSM identifiers (long-form integers)
#' @param type Type of object; must be either `node`, `way`, or `relation`
#' @param open_url If `TRUE`, open the OSM page of the specified object in web
#' browser. Multiple objects (`id` values) will be opened in multiple pages.
#' @return \link{opq} object
#'
#' @references
#' <https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL#By_element_id>
#'
#' @note Extracting elements by ID requires explicitly specifying the type of
#' element. Only elements of one of the three given types can be extracted in a
#' single query, but the results of multiple types can neverthelss be combined
#' with the \link{c} operation of \link{osmdata}.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' id <- c (1489221200, 1489221321, 1489221491)
#' dat1 <- opq_osm_id (type = "node", id = id) %>%
#'     opq_string () %>%
#'     osmdata_sf ()
#' dat1$osm_points # the desired nodes
#' id <- c (136190595, 136190596)
#' dat2 <- opq_osm_id (type = "way", id = id) %>%
#'     opq_string () %>%
#'     osmdata_sf ()
#' dat2$osm_lines # the desired ways
#' dat <- c (dat1, dat2) # The node and way data combined
#' }
opq_osm_id <- function (id = NULL, type = NULL, open_url = FALSE)
{
    if (is.null (type))
        stop ('type must be specified: one of node, way, or relation')
    type <- match.arg (tolower (type), c ('node', 'way', 'relation'))

    opq <- opq (1:4)
    opq$bbox <- NULL
    opq$features <- NULL
    opq$id <- list (type = type, id = id)

    if (open_url)
    {
        u <- paste0 ("https://openstreetmap.org/", type [1], "/", id)
        for (i in u)
            browseURL (i)
    }

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
#' @param opq An `overpass_query` object
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
    opq_string_intern (opq, quiet = TRUE)
}

# The quiet param is not exposed here, but is passed through by the various
# `osmdata_s*` functions, to issue messages when neither features nor ID
# specified.
opq_string_intern <- function (opq, quiet = TRUE)
{
    res <- NULL
    if (!is.null (opq$features)) # opq with add_osm_feature
    {
        features <- paste (opq$features, collapse = '')
        features <- paste0 (sprintf (' node %s (%s);\n', features, opq$bbox),
                            sprintf (' way %s (%s);\n', features, opq$bbox),
                            sprintf (' relation %s (%s);\n\n', features,
                                     opq$bbox))
        res <- paste0 (opq$prefix, features, opq$suffix)
    } else if (!is.null (opq$id)) # opq with opq_osm_id
    {
        id <- paste (opq$id$id, collapse = ',')
        id <- sprintf(' %s(id:%s);\n', opq$id$type, id)
        res <- paste0 (opq$prefix, id, opq$suffix)
    } else # straight opq with neither features nor ID specified
    {
        if (!quiet)
            message ("The overpass server is intended to be used to extract ",
                     "specific features;\nthis query may place an undue ",
                     "burden on server resources.\nPlease consider specifying ",
                     "features via 'add_osm_feature' or 'opq_osm_id'.")
        bbox <- paste0 (sprintf (' node (%s);\n', opq$bbox),
                            sprintf (' way (%s);\n', opq$bbox),
                            sprintf (' relation (%s);\n', opq$bbox))
        res <- paste0 (opq$prefix, bbox, opq$suffix)
    }
    return (res)
}
