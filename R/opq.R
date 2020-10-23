#' Build an Overpass query
#'
#' @param bbox Either (i) four numeric values specifying the maximal and minimal
#'      longitudes and latitudes, in the form \code{c(xmin, ymin, xmax, ymax)}
#'      or (ii) a character string in the form \code{xmin,ymin,xmax,ymax}. These
#'      will be passed to \link{getbb} to be converted to a numerical bounding
#'      box. Can also be (iii) a matrix representing a bounding polygon as
#'      returned from `getbb(..., format_out = "polygon")`.
#' @param nodes_only If `TRUE`, query OSM nodes only. Some OSM structures such
#'      as `place = "city"` or `highway = "traffic_signals"` are represented by
#'      nodes only. Queries are built by default to return all nodes, ways, and
#'      relation, but this can be very inefficient for node-only queries.
#'      Setting this value to `TRUE` for such cases makes queries more
#'      efficient, with data returned in the `osm_points` list item.
#' @param datetime If specified, a date and time to extract data from the OSM
#'      database as it was up to the specified date and time, as described at
#'      \url{https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL#date}.
#'      This \emph{must} be in ISO8601 format ("YYYY-MM-DDThh:mm:ssZ"), where
#'      both the "T" and "Z" characters must be present.
#' @param datetime2 If specified, return the \emph{difference} in the OSM
#'      database between \code{datetime} and \code{datetime2}, where
#'      \code{datetime2 > datetime}. See
#'      \url{https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL#Delta_between_two_dates_.28.22diff.22.29}.
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
#' c (osmdata_sf (q1), osmdata_sf (q2)) # all restaurants OR pubs
#'
#' # Use nodes_only to retrieve single point data only, such as for central
#' # locations of cities.
#' opq <- opq (bbox, nodes_only = TRUE) %>%
#'     add_osm_feature (key = "place", value = "city") %>%
#'     osmdata_sf (quiet = FALSE)
#' }
opq <- function (bbox = NULL, nodes_only = FALSE,
                 datetime = NULL, datetime2 = NULL,
                 timeout = 25, memsize)
{
    timeout <- format (timeout, scientific = FALSE)
    prefix <- paste0 ("[out:xml][timeout:", timeout, "]")
    suffix <- ifelse (nodes_only,
                      "); out;", 
                      ");\n(._;>;);\nout body;") # recurse down
    if (!missing (memsize))
        prefix <- paste0 (prefix, "[maxsize:",                          # nocov
                          format (memsize, scientific = FALSE), "]")    # nocov
    if (!is.null (datetime))
    {
        datetime <- check_datetime (datetime)
        if (!is.null (datetime2))
        {
            datetime2 <- check_datetime (datetime2)
            prefix <- paste0 ('[diff:\"', datetime, '\",\"', datetime2, '\"]',
                              prefix)
        } else
        {
            prefix <- paste0 ('[date:\"', datetime, '\"]', prefix)
        }
    }

    res <- list (bbox = bbox_to_string (bbox),
              prefix = paste0 (prefix, ";\n(\n"),
              suffix = suffix, features = NULL)
    class (res) <- c (class (res), "overpass_query")
    attr (res, "datetime") <- datetime
    attr (res, "datetime2") <- datetime2
    attr (res, "nodes_only") <- nodes_only

    return (res)
}

check_datetime <- function (x)
{
    if (nchar (x) != 20 &
        substring (x, 5, 5) != "-" &
        substring (x, 8, 8) != "-" &
        substring (x, 11, 11) != "T" &
        substring (x, 14, 14) != ":" &
        substring (x, 17, 17) != ":" &
        substring (x, 20, 20) != "Z")
        stop ("x is not is ISO8601 format ('YYYY-MM-DDThh:mm:ssZ')")
    YY <- substring (x, 1, 4) # nolint
    MM <- substring (x, 6, 7) # nolint
    DD <- substring (x, 9, 10) # nolint
    hh <- substring (x, 12, 13)
    mm <- substring (x, 15, 16)
    ss <- substring (x, 18, 19)
    if (formatC (as.integer (YY), width = 4, flag = "0") != YY |
        formatC (as.integer (MM), width = 2, flag = "0") != MM |
        formatC (as.integer (DD), width = 2, flag = "0") != DD |
        formatC (as.integer (hh), width = 2, flag = "0") != hh |
        formatC (as.integer (mm), width = 2, flag = "0") != mm |
        formatC (as.integer (ss), width = 2, flag = "0") != ss)
        stop ("x is not is ISO8601 format ('YYYY-MM-DDThh:mm:ssZ')")
    invisible (x)
}

# used in the following add_osm_feature fn
paste_features <- function (key, value, key_pre = "", bind = "=",
                            match_case = FALSE, value_exact = FALSE) {
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

    return (feature)
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

    feature <- paste_features (key, value, key_pre, bind,
                               match_case, value_exact)

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

#' opq_enclosing
#'
#' Find all features which enclose a given point, and optionally match specific
#' 'key'-'value' pairs. This function is \emph{not} intended to be combined with
#' \link{add_osm_feature}, rather is only to be used in the sequence
#' \link{opq_enclosing} -> \link{opq_string} -> \link{osmdata_xml} (or other
#' extraction function). See examples for how to use.
#'
#' @param lon Longitude of desired point
#' @param lat Latitude of desired point
#' @param key (Optional) OSM key of enclosing data
#' @param value (Optional) OSM value matching 'key' of enclosing data
#' @param enclosing Either 'relation' or 'way' for whether to return enclosing
#' objects of those respective types (where generally 'relation' will correspond
#' to multipolygon objects, and 'way' to polygon objects).
#' @inheritParams opq
#'
#' @examples
#' \dontrun{
#' # Get water body surrounding a particular point:
#' lat <- 54.33601
#' lon <- -3.07677
#' key <- "natural"
#' value <- "water"
#' x <- opq_enclosing (lon, lat, key, value) %>%
#'     opq_string () %>%
#'     osmdata_sf ()
#' }
#' @export
opq_enclosing <- function (lon, lat, key = NULL, value = NULL,
                           enclosing = "relation", timeout = 25) {
    enclosing <- match.arg (tolower (enclosing), c ("relation", "way"))

    bbox <- bbox_to_string (c (lon, lat, lon, lat))
    timeout <- format (timeout, scientific = FALSE)
    prefix <- paste0 ("[out:xml][timeout:", timeout, "]")
    suffix <- ");\n(._;>;);\nout;"

    features <- paste_features (key, value, value_exact = TRUE, match_case = TRUE)
    res <- list (bbox = bbox,
                 prefix = paste0 (prefix, ";\n(\n"),
                 suffix = suffix,
                 features = features)
    class (res) <- c (class (res), "overpass_query")
    attr (res, "datetime") <- attr (res, "datetime2") <- NULL
    attr (res, "nodes_only") <- FALSE
    attr (res, "enclosing") <- enclosing

    return (res)
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
#' \dontrun{
#' q <- opq ("hampi india")
#' opq_string (q)
#' }
opq_string <- function (opq)
{
    opq_string_intern (opq, quiet = TRUE)
}

# The quiet param is not exposed here, but is passed through by the various
# `osmdata_s*` functions, to issue messages when neither features nor ID
# specified.
opq_string_intern <- function (opq, quiet = TRUE)
{
    lat <- lon <- NULL # suppress no visible binding messages

    res <- NULL
    if (!is.null (opq$features)) # opq with add_osm_feature
    {
        features <- paste (opq$features, collapse = '')
        if (attr (opq, "nodes_only"))
            features <- paste0 (sprintf (' node %s (%s);\n',
                                         features,
                                         opq$bbox))
        else if (!is.null (attr (opq, "enclosing")))
            features <- paste0 ("is_in(", lat, ",", lon, ")->.a;",
                                attr (opq, "enclosing"), "(pivot.a)",
                                features,
                                ";")
        else
            features <- paste0 (sprintf (' node %s (%s);\n',
                                         features,
                                         opq$bbox),
                                sprintf (' way %s (%s);\n',
                                         features,
                                         opq$bbox),
                                sprintf (' relation %s (%s);\n\n',
                                         features,
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
