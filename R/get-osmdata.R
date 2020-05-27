#' Get timestamp from system or optional OSM XML document
#'
#' @param doc OSM XML document. If missing, `Sys.time()` is used.
#'
#' @return An R timestamp object
#'
#' @note This defines the timestamp format for \pkg{osmdata} objects, which
#' includes months as text to ensure umambiguous timestamps
#'
#' @noRd
get_timestamp <- function (doc)
{
    if (!missing (doc))
    {
        tstmp <- xml2::xml_text (xml2::xml_find_all (doc, "//meta/@osm_base"))
        if (length (tstmp) > 0)
            tstmp <- as.POSIXct (tstmp, format = "%Y-%m-%dT%H:%M:%SZ")
    } else
        tstmp <- Sys.time ()

    if (length (tstmp) == 0)
        tstmp <- Sys.time ()

    wday_t <- lubridate::wday (tstmp, label = TRUE)
    wday <- lubridate::wday (tstmp, label = FALSE)
    mon <- lubridate::month (tstmp, label = TRUE)
    year <- lubridate::year (tstmp)

    hms <- strsplit (as.character (tstmp), ' ') [[1]] [2]
    paste ('[', wday_t, wday, mon, year, hms, ']')
}

#' Get OSM database version
#'
#' @param doc OSM XML document
#'
#' @return Single number (as character string) representing OSM database version
#' @noRd
get_osm_version <- function (doc)
{
    xml2::xml_text (xml2::xml_find_all (doc, "//osm/@version"))
}

#' Get overpass version
#'
#' @param doc OSM XML document
#'
#' @return Single number (as character string) representing overpass version
#' @noRd
get_overpass_version <- function (doc)
{
    xml2::xml_text (xml2::xml_find_all (doc, "//osm/@generator"))
}

#' Return an OSM Overpass query in XML format
#' Read an (XML format) OSM Overpass response from a string, a connection,
#' or a raw vector.
#'
#' @param q An object of class `overpass_query` constructed with
#' \link{opq} and \link{add_osm_feature}.
#' @param filename If given, OSM data are saved to the named file
#' @param quiet suppress status messages.
#' @param encoding Unless otherwise specified XML documents are assumed to be
#'        encoded as UTF-8 or UTF-16. If the document is not UTF-8/16, and lacks
#'        an explicit encoding directive, this allows you to supply a default.
#' @return An object of class `XML::xml_document` containing the result of the
#'         overpass API query.
#'
#' @note Objects of class `xml_document` can be saved as `.xml` or
#' `.osm` files with `xml2::write_xml`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' q <- opq ("hampi india")
#' q <- add_osm_feature (q, key="historic", value="ruins")
#' osmdata_xml (q, filename="hampi.osm")
#' }
osmdata_xml <- function(q, filename, quiet=TRUE, encoding) {
    if (missing (encoding))
        encoding <- 'UTF-8'

    if (missing (q) & !quiet)
        message ('q missing: osmdata object will not include query')
    else if (is (q, 'overpass_query'))
        q <- opq_string_intern (q, quiet = quiet)
    else if (!is.character (q))
        stop ('q must be an overpass query or a character string')

    doc <- overpass_query (query = q, quiet = quiet, encoding = encoding)
    doc <- xml2::read_xml (doc, encoding = encoding)
    if (!missing (filename))
        xml2::write_xml (doc, file = filename)
    invisible (doc)
}

#' Return an OSM Overpass query as an \link{osmdata} object in \pkg{sp}
#' format.
#'
#' @param q An object of class `overpass_query` constructed with
#'      \link{opq} and \link{add_osm_feature}. May be be omitted,
#'      in which case the \link{osmdata} object will not include the
#'      query.
#' @param doc If missing, `doc` is obtained by issuing the overpass query,
#'        `q`, otherwise either the name of a file from which to read data,
#'        or an object of class \pkg{XML} returned from
#'        \link{osmdata_xml}.
#' @param quiet suppress status messages.
#'
#' @return An object of class `osmdata` with the OSM components (points, lines,
#'         and polygons) represented in \pkg{sp} format.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' hampi_sp <- opq ("hampi india") %>%
#'             add_osm_feature (key="historic", value="ruins") %>%
#'             osmdata_sp ()
#' }
osmdata_sp <- function(q, doc, quiet = TRUE)
{
    obj <- osmdata () # uses class def
    if (missing (q) & !quiet)
        message ('q missing: osmdata object will not include query')
    else if (is (q, 'overpass_query'))
    {
        obj$bbox <- q$bbox
        obj$overpass_call <- opq_string_intern (q, quiet = quiet)
    } else if (is.character (q))
        obj$overpass_call <- q
    else
        stop ('q must be an overpass query or a character string')

    temp <- fill_overpass_data (obj, doc, quiet = quiet)
    obj <- temp$obj
    doc <- temp$doc

    if (!quiet)
        message ('converting OSM data to sp format')
    res <- rcpp_osmdata_sp (doc)
    if (is.null (obj$bbox))
        obj$bbox <- paste (res$bbox, collapse = ' ')
    obj$osm_points <- res$points
    obj$osm_lines <- res$lines
    obj$osm_polygons <- res$polygons
    obj$osm_multilines <- res$multilines
    obj$osm_multipolygons <- res$multipolygons

    class (obj) <- c (class (obj), "osmdata_sp")

    return (obj)
}

#' fill osmdata object with overpass data and metadata, and return character
#' version of OSM xml document
#'
#' @param obj Initial \link{osmdata} object
#' @param doc Document contain XML-formatted version of OSM data
#' @inheritParams osmdata_sp
#' @return List of an \link{osmdata} object (`obj`), and XML
#'      document (`doc`)
#' @noRd
fill_overpass_data <- function (obj, doc, quiet = TRUE, encoding = "UTF-8")
{
    if (missing (doc))
    {
        doc <- overpass_query (query = obj$overpass_call, quiet = quiet,
                               encoding = encoding)

        docx <- xml2::read_xml (doc)
        obj <- get_metadata (obj, docx)
    } else
    {
        if (is.character (doc))
        {
            if (!file.exists (doc))
                stop ("file ", doc, " does not exist")
            doc <- xml2::read_xml (doc)
        }
        obj <- get_metadata (obj, doc)
        doc <- as.character (doc)
    }
    list (obj = obj, doc = doc)
}

get_metadata <- function (obj, doc)
{
    meta <- list (timestamp = get_timestamp (doc),
                  OSM_version = get_osm_version (doc),
                  overpass_version = get_overpass_version (doc))
    q <- obj$overpass_call

    # q is mostly passed as result of opq_string_intern, so date and diff query
    # metadata must be extracted from string
    if (is.character (q))
    {
        x <- strsplit (q, "\"") [[1]]
        if (grepl ("date", x [1]))
        {
            if (length (x) < 2)
                stop ("unrecongised query format")
            meta$datetime_to <- x [2]
            meta$query_type <- "date"
        } else if (grepl ("diff", x [1]))
        {
            if (length (x) < 4)
                stop ("unrecongised query format")
            meta$datetime_from <- x [2]
            meta$datetime_to <- x [4]
            meta$query_type <- "diff"
        }
    } else
    {
        if (!is.null (attr (q, "datetime2")))
        {
            meta$datetime_to <- attr (q, "datetime2")
            meta$datetime_from <- attr (q, "datetime")
            meta$query_type <- "diff"
        } else if (!is.null (attr (q, "datetime")))
        {
            meta$datetime_to <- attr (q, "datetime")
            meta$query_type <- "date"
        }
    }
    obj$meta <- meta
    attr (q, "datetime") <- attr (q, "datetime2") <- NULL

    obj$overpass_call <- q

    return (obj)
}

#' Make an 'sf' object from an 'sfc' list and associated data matrix returned
#' from 'rcpp_osmdata_sf'
#'
#' @param ... list of objects, at least one of which must be of class 'sfc'
#' @param stringsAsFactors Should character strings in 'sf' 'data.frame' be
#' coerced to factors?
#' @return An object of class `sf`
#'
#' @note Most of this code written by Edzer Pebesma, and taken from
#' <https://github.com/edzer/sfr/blob/master/R/agr.R> and
#' <https://github.com/edzer/sfr/blob/master/R/sfc.R>
#'
#' @noRd
make_sf <- function (..., stringsAsFactors = FALSE)
{
    x <- list (...)
    sf <- vapply(x, function(i) inherits(i, "sfc"),
                 FUN.VALUE = logical (1))
    sf_column <- which (sf)
    if (!is.null (names (x [[sf_column]])))
        row.names <- names (x [[sf_column]])
    else
        row.names <- seq_along (x [[sf_column]])
    df <- if (length(x) == 1) # ONLY sfc
        data.frame(row.names = row.names)
    else # create a data.frame from list:
        data.frame(x[-sf_column], row.names = row.names,
                   stringsAsFactors = stringsAsFactors)

    object <- as.list(substitute(list(...)))[-1L]
    arg_nm <- sapply(object, function(x) deparse(x)) # nolint
    sfc_name <- make.names(arg_nm[sf_column])
    #sfc_name <- "geometry"
    df [[sfc_name]] <- x [[sf_column]]
    attr(df, "sf_column") <- sfc_name
    f <- factor(rep(NA_character_, length.out = ncol(df) - 1),
                levels = c ("constant", "aggregate", "identity"))
    names(f) <- names(df)[-ncol (df)]
    attr(df, "agr") <- f
    class(df) <- c("sf", class(df))
    return (df)
}

sf_types <- c ("points", "lines", "polygons", "multilines", "multipolygons")

#' Return an OSM Overpass query as an \link{osmdata} object in \pkg{sf}
#' format.
#'
#' @inheritParams osmdata_sp
#' @param stringsAsFactors Should character strings in 'sf' 'data.frame' be
#' coerced to factors?
#' @return An object of class `osmdata` with the OSM components (points, lines,
#'         and polygons) represented in \pkg{sf} format.
#' @export
#'
#' @examples
#' \dontrun{
#' hampi_sf <- opq ("hampi india") %>%
#'             add_osm_feature (key="historic", value="ruins") %>%
#'             osmdata_sf ()
#' }
osmdata_sf <- function(q, doc, quiet=TRUE, stringsAsFactors = FALSE) {
    obj <- osmdata () # uses class def
    if (missing (q))
    {
        if (!quiet)
            message ('q missing: osmdata object will not include query')
    } else if (is (q, 'overpass_query'))
    {
        obj$bbox <- q$bbox
        obj$overpass_call <- opq_string_intern (q, quiet = quiet)
    } else if (is.character (q))
        obj$overpass_call <- q
    else
        stop ('q must be an overpass query or a character string')

    temp <- fill_overpass_data (obj, doc, quiet = quiet)
    obj <- temp$obj
    doc <- temp$doc

    if (!quiet)
        message ('converting OSM data to sf format')
    res <- rcpp_osmdata_sf (doc)
    # some objects don't have names. As explained in
    # src/osm_convert::restructure_kv_mat, these instances do not get an osm_id
    # column, so this is appended here:
    if (!"osm_id" %in% names (res$points_kv))
        res <- fill_kv (res, "points_kv", "points", stringsAsFactors)
    if (!"osm_id" %in% names (res$polygons_kv))
        res <- fill_kv (res, "polygons_kv", "polygons", stringsAsFactors)

    if (missing (q))
        obj$bbox <- paste (res$bbox, collapse = ' ')

    for (ty in sf_types)
        obj <- fill_objects (res, obj, type = ty,
                             stringsAsFactors = stringsAsFactors)
    class (obj) <- c (class (obj), "osmdata_sf")

    return (obj)
}

fill_kv <- function (res, kv_name, g_name, stringsAsFactors)
{
    if (!"osm_id" %in% names (res [[kv_name]]))
    {
        if (nrow (res [[kv_name]]) == 0)
        {
            res [[kv_name]] <- data.frame (osm_id = names (res [[g_name]]),
                                           stringsAsFactors = stringsAsFactors)
        } else {
            res [[kv_name]] <- data.frame (osm_id = rownames (res [[kv_name]]),
                                           res [[kv_name]],
                                           stringsAsFactors = stringsAsFactors)
        }
    }
    return (res)
}

fill_objects <- function (res, obj, type = "points",
                          stringsAsFactors = FALSE)
{
    if (!type %in% sf_types)
        stop ("type must be one of ", paste (sf_types, collapse = " "))

    geometry <- res [[type]]
    obj_name <- paste0 ("osm_", type)
    kv_name <- paste0 (type, "_kv")
    if (length (res [[kv_name]]) > 0)
    {
        if (!stringsAsFactors)
            res [[kv_name]] [] <- lapply (res [[kv_name]], as.character)
        obj [[obj_name]] <- make_sf (geometry, res [[kv_name]],
                                     stringsAsFactors = stringsAsFactors)
    } else if (length (obj [[obj_name]]) > 0)
        obj [[obj_name]] <- make_sf (geometry,
                                     stringsAsFactors = stringsAsFactors)

    return (obj)
}

#' Return an OSM Overpass query as an \link{osmdata} object in
#' `silicate` (`SC`) format.
#'
#' @inheritParams osmdata_sp
#' @return An object of class `osmdata` representing the original OSM hierarchy
#'      of nodes, ways, and relations.
#' @export
#'
#' @note The `silicate` format is currently highly experimental, and
#'      recommended for use only if you really know what you're doing.
#'
#' @examples
#' \dontrun{
#' hampi_sf <- opq ("hampi india") %>%
#'             add_osm_feature (key="historic", value="ruins") %>%
#'             osmdata_sc ()
#' }
osmdata_sc <- function(q, doc, quiet=TRUE) {

    obj <- osmdata () # class def used here to for fill_overpass_data fn
    if (missing (q) & !quiet)
        message ('q missing: osmdata object will not include query')
    else if (is (q, 'overpass_query'))
    {
        obj$bbox <- q$bbox
        obj$overpass_call <- opq_string_intern (q, quiet = quiet)
    } else if (is.character (q))
        obj$overpass_call <- q
    else
        stop ('q must be an overpass query or a character string')

    temp <- fill_overpass_data (obj, doc, quiet = quiet)
    obj <- temp$obj
    doc <- temp$doc

    if (!quiet)
        message ('converting OSM data to sc format')
    res <- rcpp_osmdata_sc (temp$doc)

    res$object_link_edge$native_ <- TRUE

    obj <- list () # SC **does not** use osmdata class definition
    obj$nodes <- tibble::as_tibble (res$nodes)
    obj$relation_members <- tibble::as_tibble (res$relation_members)
    obj$relation_properties <- tibble::as_tibble (res$relation_properties)
    obj$object <- tibble::as_tibble (res$object)
    obj$object_link_edge <- tibble::as_tibble (res$object_link_edge)
    obj$edge <- tibble::as_tibble (res$edge)
    obj$vertex <- tibble::as_tibble (res$vertex)
    obj$meta <- tibble::tibble (proj = NA_character_,
                                ctime = temp$obj$meta$timestamp,
                                OSM_version = temp$obj$meta$OSM_version,
                            overpass_version = temp$obj$meta$overpass_version)
    if (!missing (q))
        obj$meta$bbox <- q$bbox
    else
        obj$meta$bbox <- bbox_to_string (obj)

    attr (obj, "join_ramp") <- c ("nodes",
                                  "relation_members",
                                  "relation_properties",
                                  "object",
                                  "object_link_edge",
                                  "edge",
                                  "vertex")
    attr (obj, "class") <- c ("SC", "sc", "osmdata_sc")

    return (obj)
}

getbb_sc <- function (x)
{
    apply (x$vertex [, 1:2], 2, range) %>%
        bbox_to_string ()
}
