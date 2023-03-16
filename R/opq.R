#' Build an Overpass query
#'
#' @param bbox Either (i) four numeric values specifying the maximal and minimal
#'      longitudes and latitudes, in the form \code{c(xmin, ymin, xmax, ymax)}
#'      or (ii) a character string in the form \code{xmin,ymin,xmax,ymax}. These
#'      will be passed to \link{getbb} to be converted to a numerical bounding
#'      box. Can also be (iii) a matrix representing a bounding polygon as
#'      returned from `getbb(..., format_out = "polygon")`. To search in an
#'      area, (iv) a character string with a relation or a (closed) way id in
#'      the format `"way(id:1)"`, `"relation(id:1, 2)"` or `"relation(id:1, 2,
#'      3); way(id:2)"` as returned by `getbb(..., format_out = "osm_type_id")`
#'      or \link{bbox_to_string} with a `data.frame` from `getbb(..., format_out
#'      = "data.frame")` to select all areas combined (relations and ways).
#' @param nodes_only WARNING: this parameter is equivalent to
#'      `osm_types = "node"` and will be DEPRECATED. If `TRUE`, query OSM nodes
#'      only. Some OSM structures such as `place = "city"` or
#'      `highway = "traffic_signals"` are represented by nodes only. Queries are
#'      built by default to return all nodes, ways, and relation, but this can
#'      be very inefficient for node-only queries. Setting this value to `TRUE`
#'      for such cases makes queries more efficient, with data returned in the
#'      `osm_points` list item.
#' @param osm_types A character vector with several OSM types to query: `node`,
#'      `way` and `relation` is the default. `nwr`, `nw`, `wr`, `nr` and `rel`
#'      are also valid types. Ignored if `nodes_only = TRUE`.
#'      `osm_types = "node"` is equivalent to `nodes_only = TRUE`.
#' @param out The level of verbosity of the overpass result: `body` (geometries
#'      and tags, the default), `tags` (tags without geometry), `meta` (like
#'      body + Timestamp, Version, Changeset, User, User ID of the last
#'      edition), `skel` (geometries only), `tags center` (tags without geometry
#'      + the coordinates of the center of the bounding box) and `ids` (type and
#'      id of the objects only).
#' @param datetime If specified, a date and time to extract data from the OSM
#'      database as it was up to the specified date and time, as described at
#'      \url{https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL#date}.
#'      This \emph{must} be in ISO8601 format ("YYYY-MM-DDThh:mm:ssZ"), where
#'      both the "T" and "Z" characters must be present.
#' @param datetime2 If specified, return the \emph{difference} in the OSM
#'      database between \code{datetime} and \code{datetime2}, where
#'      \code{datetime2 > datetime}. See
#'      \url{https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL#Difference_between_two_dates_(diff)}.
#' @param adiff If `TRUE`, query for [augmented
#'      difference](https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL#Augmented-difference_between_two_dates_(adiff)).
#'      The result indicates what happened to the modified and deleted OSM
#'      objects. Requires `datetime(2)*`.
#' @param timeout It may be necessary to increase this value for large queries,
#'      because the server may time out before all data are delivered.
#' @param memsize The default memory size for the 'overpass' server in *bytes*;
#'      may need to be increased in order to handle large queries.
#'
#' @return An `overpass_query` object
#'
#' @details The `out` statement for `tags`, `tags center`and `id`, do not return
#' geometries. Neither `out = "meta"` nor `adiff = TRUE` options are implemented
#' for all `osmdata_*` functions yet. Use [osmdata_xml] or [osmdata_data_frame]
#' to get the result of these queries. See the documentation of the [out
#' statement](https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL#out)
#' and [augmented
#' difference](https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL#Augmented-difference_between_two_dates_(adiff))
#' for more details about these options.
#'
#' @note See
#' \url{https://wiki.openstreetmap.org/wiki/Overpass_API#Resource_management_options_.28osm-script.29}
#' for explanation of `timeout` and `memsize` (or `maxsize` in overpass terms).
#' Note in particular the comment that queries with arbitrarily large `memsize`
#' are likely to be rejected.
#'
#' @family queries
#' @export
#'
#' @examples
#' \dontrun{
#' q <- getbb ("portsmouth", display_name_contains = "United States") %>%
#'     opq () %>%
#'     add_osm_feature ("amenity", "restaurant") %>%
#'     add_osm_feature ("amenity", "pub")
#' osmdata_sf (q) # all objects that are restaurants AND pubs (there are none!)
#' q1 <- getbb ("portsmouth", display_name_contains = "United States") %>%
#'     opq () %>%
#'     add_osm_feature ("amenity", "restaurant")
#' q2 <- getbb ("portsmouth", display_name_contains = "United States") %>%
#'     opq () %>%
#'     add_osm_feature ("amenity", "pub")
#' c (osmdata_sf (q1), osmdata_sf (q2)) # all restaurants OR pubs
#'
#' # Use nodes_only to retrieve single point data only, such as for central
#' # locations of cities.
#' opq <- opq (bbox, nodes_only = TRUE) %>%
#'     add_osm_feature (key = "place", value = "city") %>%
#'     osmdata_sf (quiet = FALSE)
#'
#' # Filter by a search area
#' qa1 <- getbb ("Catalan Countries", format_out = "osm_type_id") %>%
#'     opq (nodes_only = TRUE) %>%
#'     add_osm_feature (key = "capital", value = "4")
#' opqa1 <- osmdata_sf (qa1)
#' # Filter by a multiple search areas
#' bb <- getbb ("Vilafranca", format_out = "data.frame")
#' qa2 <- bbox_to_string (bb [bb$osm_type != "node", ]) %>%
#'     opq (nodes_only = TRUE) %>%
#'     add_osm_feature (key = "place")
#' opqa2 <- osmdata_sf (qa2)
#' }
opq <- function (bbox = NULL, nodes_only = FALSE,
                 osm_types = c ("node", "way", "relation"),
                 out = c ("body", "tags", "meta", "skel", "tags center", "ids"),
                 datetime = NULL, datetime2 = NULL, adiff = FALSE,
                 timeout = 25, memsize) {

    timeout <- format (timeout, scientific = FALSE)
    prefix <- paste0 ("[out:xml][timeout:", timeout, "]")

    if (nodes_only) {
        osm_types <- "node"
    } else {
        osm_types <- try (
            match.arg (osm_types,
                choices = c (
                    "node", "way", "rel", "relation",
                    "nwr", "nw", "wr", "nr"
                ),
                several.ok = TRUE
        ), silent = TRUE)
        if (inherits (osm_types, "try-error")) {
            stop ('osm_types parameter must be a vector with values from ',
                '"node", "way", "rel", "relation", ',
                '"nwr", "nw", "wr" and "nr".',
                call. = FALSE
            )
        }
    }

    out <- try (match.arg (out), silent = TRUE)
    if (inherits (out, "try-error")) {
        stop ("out parameter must be ",
            '"body", "tags", "meta", "skel", "tags center" or "ids".',
            call. = FALSE
        )
    }

    has_geometry <- !nodes_only && out %in% c ("body", "meta", "skel")
    if (has_geometry) {
        suffix <- paste0 (");\n(._;>;);\nout ", out, ";") # recurse down
    } else {
        suffix <- paste0 ("); out ", out, ";")
    }

    if (!missing (memsize)) {
        prefix <- paste0 (
            prefix, "[maxsize:", # nocov
            format (memsize, scientific = FALSE), "]"
        )
    } # nocov
    if (!is.null (datetime)) {

        if (!is_datetime (datetime)) {
            stop (
                "datetime must be in ISO8601 format ('YYYY-MM-DDThh:mm:ssZ')",
                call. = FALSE
            )
        }


        if (!is.null (datetime2)) {

            if (!is_datetime (datetime2)) {
                stop (
                    "datetime2 must be in ISO8601 format ('YYYY-MM-DDThh:mm:ssZ')",
                    call. = FALSE
                )
            }
            prefix <- paste0 (
                '[diff:\"', datetime, '\",\"', datetime2, '\"]',
                prefix
            )
        } else {

            prefix <- paste0 ('[date:\"', datetime, '\"]', prefix)
        }

        if (adiff) {
            prefix <- gsub ("^\\[(diff|date):", "[adiff:", prefix)
        }
    }

    res <- list (
        bbox = bbox_to_string (bbox),
        prefix = paste0 (prefix, ";\n(\n"),
        suffix = suffix,
        features = NULL,
        osm_types = osm_types
    )

    class (res) <- c (class (res), "overpass_query")
    attr (res, "datetime") <- datetime
    attr (res, "datetime2") <- datetime2
    attr (res, "nodes_only") <- nodes_only

    return (res)
}

# used in the following add_osm_feature fn
paste_features <- function (key, value, key_pre = "", bind = "=",
                            match_case = FALSE, value_exact = FALSE) {
    if (is.null (value)) {

        feature <- ifelse (substring (key, 1, 1) == "!",
                sprintf ('[!"%s"]', substring (key, 2, nchar (key))),
                sprintf ('["%s"]', key)
        )

    } else {

        if (length (value) > 1 || !match_case) {

            # convert to OR'ed regex:
            value <- paste (value, collapse = "|")
            if (value_exact) {
                value <- paste0 ("^(", value, ")$")
            }
            bind <- "~"
        } else if (substring (value, 1, 1) == "!") {

            bind <- paste0 ("!", bind)
            value <- substring (value, 2, nchar (value))

            if (key_pre == "~") {
                message ("Value negation only possible for exact keys")
                key_pre <- ""
            }
        }
        feature <- paste0 (sprintf (
            '[%s"%s"%s"%s"',
            key_pre, key, bind, value
        ))
        if (!match_case) {
            feature <- paste0 (feature, ",i")
        }
        feature <- paste0 (feature, "]")
    }

    return (feature)
}

#' Add a feature to an Overpass query
#'
#' @param opq An `overpass_query` object
#' @param key feature key; can be negated with an initial exclamation mark,
#' `key = "!this"`, and can also be a vector if `value` is missing.
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
#' @seealso [add_osm_features]
#'
#' @section `add_osm_feature` vs `add_osm_features`:
#' Features defined within an [add_osm_features] call are combined with a
#' logical OR.
#'
#' Chained calls to either [add_osm_feature] or `add_osm_features()` combines
#' features from these calls in a logical AND; this is analagous to chaining
#' `dplyr::filter()` on a data frame.
#'
#' `add_osm_features()` with only one feature is logically equivalent to
#' `add_osm_feature()`.
#'
#' @family queries
#' @export
#'
#' @examples
#' \dontrun{
#' q <- opq ("portsmouth usa") %>%
#'     add_osm_feature (
#'         key = "amenity",
#'         value = "restaurant"
#'     ) %>%
#'     add_osm_feature (key = "amenity", value = "pub")
#' osmdata_sf (q) # all objects that are restaurants AND pubs (there are none!)
#' q1 <- opq ("portsmouth usa") %>%
#'     add_osm_feature (
#'         key = "amenity",
#'         value = "restaurant"
#'     )
#' q2 <- opq ("portsmouth usa") %>%
#'     add_osm_feature (key = "amenity", value = "pub")
#' c (osmdata_sf (q1), osmdata_sf (q2)) # all restaurants OR pubs
#' # Use of negation to extract all non-primary highways
#' q <- opq ("portsmouth uk") %>%
#'     add_osm_feature (key = "highway", value = "!primary")
#'
#' # key negation without warnings
#' q3 <- opq ("Vinçà", osm_type="node") %>%
#'     add_osm_feature (key = c("name", "!name:ca"))
#' q4 <- opq ("el Carxe", osm_type="node") %>%
#'     add_osm_feature (key = "natural", value = "peak") %>%
#'     add_osm_feature (key = "!ele")
#' }
add_osm_feature <- function (opq,
                             key,
                             value,
                             key_exact = TRUE,
                             value_exact = TRUE,
                             match_case = TRUE,
                             bbox = NULL) {
    if (missing (key)) {
        stop ("key must be provided")
    }

    if (is.null (bbox) && is.null (opq$bbox)) {
        stop ("Bounding box has to either be set in opq or must be set here")
    }

    if (!is.null (bbox)) {
        bbox <- bbox_to_string (bbox)
        opq$bbox <- bbox
    }

    bind_key_pre <- set_bind_key_pre (key_exact, value_exact)

    if (missing (value)) {
        value <- NULL
    }

    feature <- paste_features (
        key, value, bind_key_pre$key_pre, bind_key_pre$bind,
        match_case, value_exact
    )
    feature<- paste (feature, collapse = " ")

    if (is.null (opq$features)) {
        opq$features <- feature
    } else {
        opq$features <- paste (opq$features, feature)
    }

    if (any (w <- !grepl("\\[(\\\"|~)", opq$features))) {
        warning(
            "The query will request objects whith only a negated key (",
            paste (opq$features[w], collapse = ", "), ") , which can be quite ",
            "expensive for overpass servers. Add other features or be shure ",
            "that that is what you want. To avoid this warning, reorder your ",
            "calls to add_osm_feature/s and leave key negations at the end."
        )
    }

    if (is.null (opq$suffix)) {
        opq$suffix <- ");\n(._;>;);\nout body;"
    }
    # opq$suffix <- ");\n(._;>);\nout qt body;"
    # qt option is not compatible with sf because GDAL requires nodes to be
    # numerically sorted

    opq
}

#' Get conditional operator/prefix values based on value_exact and key_exact
#'
#' @param bind Operator used to combine key and value. Options include "="
#'   (default - equivalent to `value_exact = TRUE`), "!=", "~" (equivalent to
#'   `value_exact = FALSE`), or "!~".
#' @param key_pre Prefix for key. Options include "" or "~".
#' @noRd
set_bind_key_pre <- function (key_exact = TRUE,
                              value_exact = TRUE,
                              features = NULL,
                              bind = "=",
                              key_pre = "") {
    if (!is.null (value_exact)) {
        value_exact <- check_value_exact (value_exact, key_exact)
    }

    check_bind_key_pre (bind, key_pre)

    if (!is.null (features)) {
        if (length (bind) == 1) {
            bind <- rep_len (bind, length (features))
        } else if (!identical_length (features, bind)) {
            stop (
                "bind must be length 1 or the same length as features"
            )
        }

        if (length (key_pre) == 1) {
            key_pre <- rep_len (key_pre, length (features))
        } else if (!identical_length (features, key_pre)) {
            stop (
                "key_pre must be length 1 or the same length as features"
            )
        }
    }

    features_len <- 1L
    if (!is.null (features)) {
        features_len <- length (features)
    }

    if (!is.null (value_exact) && !value_exact) {
        bind <- rep_len ("~", features_len)
    }

    if (!is.null (key_exact) && !key_exact) {
        key_pre <- rep_len ("~", features_len)
    }

    list (
        "bind" = bind,
        "key_pre" = key_pre
    )
}

#' Are x and y an identical length?
#'
#' @noRd
identical_length <- function (x, y) {
    identical (length (x), length (y))
}

#' Check that value_exact can be combined with key_exact
#'
#' @noRd
check_value_exact <- function (value_exact = TRUE, key_exact = TRUE) {
    if (value_exact && !key_exact) {
        message (
            "key_exact = FALSE can only combined with ",
            "value_exact = FALSE; setting value_exact = FALSE"
        )

        return (FALSE)
    }

    value_exact
}

#' Check for valid bind and key_pre values
#'
#' @noRd
check_bind_key_pre <- function (bind = "=", key_pre = "") {
    if (!all (bind %in% c ("=", "!=", "~", "!~"))) {
        stop ('bind must only include "=", "!=", "~", or "!~"')
    }

    if (!all (key_pre %in% c ("", "~"))) {
        stop ('key_pre must only include "" or "~"')
    }
}

#' Add multiple features to an Overpass query
#'
#' Alternative version of \link{add_osm_feature} for creating single queries
#' with multiple features. Key-value matching may be controlled by using the
#' filter symbols described in
#' \url{https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL#By_tag_.28has-kv.29}.
#'
#' @inheritParams add_osm_feature
#' @inheritSection add_osm_feature `add_osm_feature` vs `add_osm_features`
#' @param features A named list or vector with the format `list("<key>" =
#'      "<value>")` or `c("<key>" = "<value>")` or a character vector of
#'      key-value pairs with keys and values enclosed in escape-formatted
#'      quotations. See examples for details.
#' @param bbox optional bounding box for the feature query; must be set if no
#'      opq query bbox has been set.
#' @return \link{opq} object
#'
#' @references \url{https://wiki.openstreetmap.org/wiki/Map_Features}
#' @seealso [add_osm_feature]
#'
#' @family queries
#' @export
#'
#' @examples
#' \dontrun{
#' q <- opq ("portsmouth usa") %>%
#'     add_osm_features (features = list (
#'         "amenity" = "restaurant",
#'         "amenity" = "pub"
#'     ))
#'
#' q <- opq ("portsmouth usa") %>%
#'     add_osm_features (features = c (
#'         "\"amenity\"=\"restaurant\"",
#'         "\"amenity\"=\"pub\""
#'     ))
#' # This extracts in a single query the same result as the following:
#' q1 <- opq ("portsmouth usa") %>%
#'     add_osm_feature (
#'         key = "amenity",
#'         value = "restaurant"
#'     )
#' q2 <- opq ("portsmouth usa") %>%
#'     add_osm_feature (key = "amenity", value = "pub")
#' c (osmdata_sf (q1), osmdata_sf (q2)) # all restaurants OR pubs
#' }
add_osm_features <- function (opq,
                              features,
                              bbox = NULL,
                              key_exact = TRUE,
                              value_exact = TRUE) {
    if (is.null (bbox) && is.null (opq$bbox)) {
        stop ("Bounding box has to either be set in opq or must be set here")
    }

    if (!is.null (bbox)) {
        bbox <- bbox_to_string (bbox)
        opq$bbox <- bbox
    }

    if (is.null (opq$suffix)) {
        opq$suffix <- ");\n(._;>;);\nout body;"
    }

    check_features (features)

    if (is_named (features)) {
        bind_key_pre <-
            set_bind_key_pre (
                features = features,
                value_exact = value_exact,
                key_exact = key_exact
            )

        features <- mapply (function (key, value, key_pre, bind) {
                paste_features (key, value, key_pre = key_pre, bind = bind,
                    match_case = TRUE, value_exact = value_exact)
            },
            key = names (features), value = features,
            key_pre = bind_key_pre$key_pre, bind = bind_key_pre$bind,
            SIMPLIFY = FALSE
        )
        features <- as.character (features)

    }

    index <- which (!grepl ("^\\[", features))
    features [index] <- paste0 ("[", features [index])
    index <- which (!grepl ("\\]$", features))
    features [index] <- paste0 (features [index], "]")

    opq$features <- unique (c (opq$features, features))

    opq
}

#' Is features a named list or character vector?
#'
#' @noRd
is_named <- function (x) {
    !is.null (names (x)) && !any ("" %in% names (x))
}

#' Is features an escape-delimited string?
#'
#' @noRd
is_escape_delimited <- function (x) {
    length (which (!grepl ("\\\"", x))) > 0L
}

#' Check if features is provided and uses the required class and formatting
#'
#' @noRd
check_features <- function (features) {
    if (missing (features)) {
        stop ("features must be provided", call. = FALSE)
    }

    stopifnot (
        "features must be a list or character vector." =
            is.character (features) | is.list (features)
    )

    if (!is_named (features) && is_escape_delimited (features)) {
        stop (
            "features must be a named list or vector or a character vector ",
            "enclosed in escape delimited quotations (see examples)",
            call. = FALSE
        )
    }
}

#' Add a feature specified by OSM ID to an Overpass query
#'
#' @inheritParams opq
#' @param id One or more official OSM identifiers (long-form integers), which
#'      must be entered as either a character or *numeric* value (because R does
#'      not support long-form integers). id can also be a character string
#'      prefixed with the id type, e.g. "relation/11158003"
#' @param type Type of objects (recycled); must be either `node`, `way`, or
#'      `relation`. Optional if id is prefixed with the type.
#' @param open_url If `TRUE`, open the OSM page of the specified object in web
#'      browser. Multiple objects (`id` values) will be opened in multiple
#'      pages.
#' @return \link{opq} object
#'
#' @references
#' \url{https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL#By_element_id}
#'
#' @note Extracting elements by ID requires explicitly specifying the type of
#' element. Only elements of one of the three given types can be extracted in a
#' single query, but the results of multiple types can nevertheless be combined
#' with the \link{c} operation of \link{osmdata}.
#'
#' @family queries
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
#' # All in one (same result as dat)
#' id <- c (1489221200, 1489221321, 1489221491, 136190595, 136190596)
#' type <- c ("node", "node", "node", "way", "way")
#' datAiO <- opq_osm_id (id = id, type = type) %>%
#'     opq_string () %>%
#'     osmdata_sf ()
#' }
opq_osm_id <- function (id = NULL, type = NULL, open_url = FALSE,
                        out = "body", datetime = NULL, datetime2 = NULL,
                        adiff = FALSE, timeout = 25, memsize) {
    if (is.null (type)) {
        if (is.null (id)) {
            stop (
                "type must be specified: one of ",
                "node, way, or relation if id is 'NULL'",
                call. = FALSE
            )
        } else if (all (grepl ("^node/|^way/|^relation/", id))) {
            type <- dirname (id)
            id <- basename (id)
        }
    }

    type <- tolower (type)
    if (!all (type %in% c ("node", "way", "relation"))) {
        stop ('type items must be "node", "way" or "relation".')
    }

    if (is.null (id)) {
        stop ("id must be specified.")
    }
    if (!(is.character (id) || storage.mode (id) == "double")) {
        stop ("id must be character or numeric.")
    }
    if (length (id) %% length (type) != 0 || length (type) > length (id)) {
        stop ("id length must be a multiple of type length.")
    }

    if (!is.character (id)) {
        id <- as.character (id)
    }

    opq <- opq (
        bbox = 1:4, out = out, datetime = datetime, datetime2 = datetime2,
        adiff = adiff, timeout = timeout, memsize = memsize
    )

    opq$bbox <- NULL
    opq$features <- NULL
    opq$osm_types <- NULL
    opq$id <- list (type = type, id = id)

    if (open_url) {
        # nocov start
        u <- paste0 ("https://openstreetmap.org/", type [1], "/", id)
        for (i in u) {
            browseURL (i)
        }
        # nocov end
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
#' @family queries
#' @export
opq_enclosing <- function (lon = NULL, lat = NULL,
                           key = NULL, value = NULL,
                           enclosing = "relation", timeout = 25) {

    enclosing <- match.arg (tolower (enclosing), c ("relation", "way"))

    if (is.null (lon) || is.null (lat)) {
        stop ("'lon' and 'lat' must be provided.")
    }
    if (!(is.numeric (lon) && is.numeric (lat) &&
        length (lon) == 1L && length (lat) == 1L)) {
        stop ("'lon' and 'lat' must both be single numeric values.")
    }

    bbox <- bbox_to_string (c (lon, lat, lon, lat))
    timeout <- format (timeout, scientific = FALSE)
    prefix <- paste0 ("[out:xml][timeout:", timeout, "]")
    suffix <- ");\n(._;>;);\nout;"

    features <- paste_features (key,
        value,
        value_exact = TRUE,
        match_case = TRUE
    )
    res <- list (
        bbox = bbox,
        prefix = paste0 (prefix, ";\n(\n"),
        suffix = suffix,
        features = features
    )
    class (res) <- c (class (res), "overpass_query")
    attr (res, "datetime") <- attr (res, "datetime2") <- NULL
    attr (res, "nodes_only") <- FALSE
    attr (res, "enclosing") <- enclosing

    return (res)
}

#' opq_around
#'
#' Find all features around a given point, and optionally match specific
#' 'key'-'value' pairs. This function is \emph{not} intended to be combined with
#' \link{add_osm_feature}, rather is only to be used in the sequence
#' \link{opq_around} -> \link{osmdata_xml} (or other extraction function). See
#' examples for how to use.
#'
#' @param radius Radius in metres around the point for which data should be
#' extracted. Queries with  large values for this parameter may fail.
#' @inheritParams opq_enclosing
#'
#' @examples
#' \dontrun{
#' # Get all benches ("amenity=bench") within 100m of a particular point
#' lat <- 53.94542
#' lon <- -2.52017
#' key <- "amenity"
#' value <- "bench"
#' radius <- 100
#' x <- opq_around (lon, lat, radius, key, value) %>%
#'     osmdata_sf ()
#' }
#' @family queries
#' @export
opq_around <- function (lon, lat, radius = 15,
                        key = NULL, value = NULL, timeout = 25) {

    timeout <- format (timeout, scientific = FALSE)
    prefix <- paste0 ("[out:xml][timeout:", timeout, "];(")
    suffix <- ");\n(._;>;);\nout;"

    kv <- NULL
    if (!is.null (key)) {
        if (!is.null (value)) {
            kv <- paste0 ("[", key, "=", value, "]")
        } else {
            kv <- paste0 ("[", key, "]")
        }
    }

    nodes <- paste0 ("node(around:", radius, ",", lat, ", ", lon, ")", kv, ";")
    ways <- paste0 ("way(around:", radius, ",", lat, ", ", lon, ")", kv, ";")
    rels <- paste0 (
        "relation(around:",
        radius, ",", lat, ", ", lon, ")", kv, ";"
    )

    res <- paste0 (prefix, nodes, ways, rels, suffix)

    return (res)
}

#' Transform an Overpass query to return the result in a csv format
#'
#' @param q A opq string or an object of class `overpass_query` constructed with
#'     \link{opq} or alternative opq builders (+ \link{add_osm_feature}/s).
#' @param fields a character vector with the field names.
#' @param header if \code{FALSE}, do not ask for column names.
#'
#' @return The `overpass_query` or string with the prefix changed to
#'     return a csv.
#'
#' @details The output format `csv`, ask for results in csv. See
#'  [CSV output mode](https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL#CSV_output_mode)
#'  for details. To get the data, use \link{osmdata_data_frame}.
#'
#' @note csv queries that reach the timeout will return a 0 row data.frame
#'    without any warning. Increase `timeout` in `q` if you don't see the
#'    expected result.
#'
#' @family queries
#' @export
#'
#' @examples
#' \dontrun{
#' q <- getbb ("Catalan Countries", format_out = "osm_type_id") %>%
#'     opq (out = "tags center", osm_type = "relation", timeout = 100) %>%
#'     add_osm_feature ("admin_level", "7") %>%
#'     add_osm_feature ("boundary", "administrative") %>%
#'     opq_csv (fields = c("name", "::type", "::id", "::lat", "::lon"))
#' comarques <- osmdata_data_frame (q) # without timeout parameter, 0 rows
#'
#' qid<- opq_osm_id (
#'     type = "relation",
#'     id = c ("341530", "1809102", "1664395", "343124"),
#'     out = "tags"
#' ) %>%
#'     opq_csv (fields = c ("name", "name:ca"))
#' cities <- osmdata_data_frame (qid)
#' }
opq_csv <- function (q, fields, header = TRUE) {

    if (!inherits (q, c("overpass_query", "character"))) {
        stop ("q must be an overpass query or a character string.")
    }
    if (!inherits (fields, "character")) {
        stop ("fields must be a character vector.")
    }

    fields <- vapply(fields, function (x) {
        if (substr(x, 1, 2) != "::") {
            x <- paste0("\"", x, "\"")
        }
        return (x)
    }, FUN.VALUE = character(1), USE.NAMES = FALSE)
    fields <- paste (fields, collapse=", ")

    csv_prefix <- paste0 (
        "[out:csv(", fields,
        if (!header) "; false",
        # if (!missing (sep)) paste0("; \"", sep, "\""),
        ")]"
    )

    if (inherits (q, "overpass_query")) {
        q$prefix <- gsub ("\\[out:xml\\]", csv_prefix, q$prefix)
    } else { # q is an opq_string
        q <- gsub ("\\[out:xml\\]", csv_prefix, q)
    }

    return (q)
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
#' @family queries
#' @aliases opq_to_string
#'
#' @examples
#' \dontrun{
#' q <- opq ("hampi india")
#' opq_string (q)
#' }
opq_string <- function (opq) {

    opq_string_intern (opq, quiet = TRUE)
}

# The quiet param is not exposed here, but is passed through by the various
# `osmdata_s*` functions, to issue messages when neither features nor ID
# specified.
opq_string_intern <- function (opq, quiet = TRUE) {

    lat <- lon <- NULL # suppress no visible binding messages

    if (attr (opq, "nodes_only")) {
        opq$osm_types <- "node"
    }

    map_to_area <- grepl ("(node|way|relation|rel)\\(id:[0-9, ]+\\)", opq$bbox)

    res <- NULL
    if (!is.null (opq$features)) { # opq with add_osm_feature

        features <- opq$features

        if (length (features) > 1L) { # from add_osm_features fn

            features <- vapply (features, function (i) {
                paste (i, collapse = "")
            },
            character (1),
            USE.NAMES = FALSE
            )
        }

        if (!is.null (attr (opq, "enclosing"))) {

            if (length (features) > 1) {
                stop ("enclosing queries can only accept one feature")
            }

            lat <- strsplit (opq$bbox, ",") [[1]] [1]
            lon <- strsplit (opq$bbox, ",") [[1]] [2]
            features <- paste0 (
                "is_in(", lat, ",",
                lon, ")->.a;",
                attr (opq, "enclosing"),
                "(pivot.a)",
                features,
                ";"
            )

        } else {

            types_features <- expand.grid (
                osm_types=opq$osm_types,
                features=features,
                stringsAsFactors = FALSE
            )

            if (!map_to_area) {
                features <-  c (sprintf ("  %s %s (%s);\n",
                                         types_features$osm_types,
                                         types_features$features,
                                         opq$bbox
                                )
                )

            } else {
                opq$prefix <- gsub ("\n$", "", opq$prefix)
                search_area <- paste0 (
                    opq$bbox,
                    "; map_to_area->.searchArea; );\n(\n"
                )
                features <- c (
                    search_area,
                    sprintf ("  %s %s (area.searchArea);\n",
                             types_features$osm_types,
                             types_features$features
                    )
                )
            }
        }

        res <- paste0 (
            opq$prefix,
            paste (features, collapse = ""),
            opq$suffix
        )

    } else if (!is.null (opq$id)) { # opq with opq_osm_id

        type_id <- data.frame (type = opq$id$type, id = opq$id$id)
        type_id <- split (type_id, type_id$type)
        id <- mapply (function (type, ids) {
            paste0 (" ", type, "(id:", paste (ids$id, collapse = ","), ");\n")
        }, type = names (type_id), ids = type_id)

        id <- paste (id, collapse = "")
        res <- paste0 (opq$prefix, id, opq$suffix)

    } else { # straight opq with neither features nor ID specified

        if (!quiet) {
            message (
                "The overpass server is intended to be used to extract ",
                "specific features;\nthis query may place an undue ",
                "burden on server resources.\nPlease consider specifying ",
                "features via 'add_osm_feature' or 'opq_osm_id'."
            )
        }

        if (!map_to_area) {
            bbox <- sprintf ("  %s (%s);\n", opq$osm_types, opq$bbox)
        } else {
                opq$prefix <- gsub ("\n$", "", opq$prefix)
            search_area <-
                paste0 (opq$bbox, "; map_to_area->.searchArea; );\n(\n")
            bbox <- c (
                search_area,
                sprintf ("  %s (area.searchArea);\n", opq$osm_types)
            )
        }

        res <- paste0 (opq$prefix, paste (bbox, collapse = ""), opq$suffix)
    }

    return (res)
}
