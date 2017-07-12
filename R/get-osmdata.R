#' Get timestamp from system or optional OSM XML document
#'
#' @param doc OSM XML document. If missing, \code{Sys.time()} is used.
#'
#' @return An R timestamp object
#'
#' @note This defines the timestamp format for \code{osmdata} objects, which
#' includes months as text to ensure umambiguous timestamps 
#'
#' @noRd
get_timestamp <- function (doc)
{
    if (!missing (doc))
    {
        tstmp <- xml2::xml_text (xml2::xml_find_all (doc, "//meta/@osm_base"))
        tstmp <- as.POSIXct (tstmp, format = "%Y-%m-%dT%H:%M:%SZ")
    } else
        tstmp <- Sys.time ()
    wday_t <- lubridate::wday (tstmp, label = TRUE)
    wday <- lubridate::wday (tstmp, label = FALSE)
    mon <- lubridate::month (tstmp, label = TRUE)
    year <- lubridate::year (tstmp)

    hms <- strsplit (as.character (tstmp), ' ') [[1]] [2]
    paste ('[', wday_t, wday, mon, year, hms, ']')
}

#' Return an OSM Overpass query in XML format 
#' Read an (XML format) OSM Overpass response from a string, a connection,
#' or a raw vector.
#'
#' @param q An object of class `overpass_query` constructed with \code{opq} and
#'        \code{add_osm_feature}.
#' @param filename If given, OSM data are saved to the named file
#' @param quiet suppress status messages. 
#' @param encoding Unless otherwise specified XML documents are assumed to be
#'        encoded as UTF-8 or UTF-16. If the document is not UTF-8/16, and lacks
#'        an explicit encoding directive, this allows you to supply a default.
#' @return An object of class `XML::xml_document` containing the result of the
#'         overpass API query.  
#'
#' @note Objects of class \code{xml_document} can be saved as \code{.xml} or
#' \code{.osm} files with code{xml2::write_xml}.
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

    doc <- overpass_query (query = opq_string (q), quiet = quiet,
                           encoding = encoding)
    doc <- xml2::read_xml (doc, encoding = encoding)
    if (!missing (filename))
        xml2::write_xml (doc, file = filename)
    invisible (doc)
}

#' Return an OSM Overpass query in PBF (Protocol Buffer Format).
#'
#' @param q An object of class `overpass_query` constructed with \code{opq} and
#'        \code{add_osm_feature}.
#' @param filename If given, OSM data are saved to the named file
#' @param quiet suppress status messages. 
#'
#' @return An binary Protocol Buffer Format (PBF) object.
#'
#' @note This function is experimental, and \code{osmdata} can currently NOT do
#' anything with PBF files.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' q <- opq ("hampi india")
#' q <- add_osm_feature (q, key="historic", value="ruins")
#' osmdata_pdf (q, filename="hampi.pbf")
#' }
osmdata_pbf <- function(q, filename, quiet=TRUE) {
    q$prefix <- gsub ("xml", "pbf", q$prefix)
    q$suffix <- gsub ("body", "meta", q$suffix)

    pbf <- overpass_query (query = opq_string (q), quiet = quiet,
                           encoding = 'pbf')
    if (!missing (filename))
        write (pbf, file = filename)

    invisible (pbf)
}

#' Return an OSM Overpass query as an \code{osmdata} object in \code{sp} format.
#'
#' @param q An object of class `overpass_query` constructed with \code{opq} and
#'        \code{add_osm_feature}. May be be omitted, in which case the
#'        \code{osmdata} object will not include the query.
#' @param doc If missing, \code{doc} is obtained by issuing the overpass query,
#'        \code{q}, otherwise either the name of a file from which to read data,
#'        or an object of class \code{XML} returned from \code{osmdata_xml}. 
#' @param quiet suppress status messages. 
#' @param encoding Unless otherwise specified XML documents are assumed to be
#'        encoded as UTF-8 or UTF-16. If the document is not UTF-8/16, and lacks
#'        an explicit encoding directive, this allows you to supply a default.
#'
#' @return An object of class `osmdata` with the OSM components (points, lines,
#'         and polygons) represented in \code{sp} format.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' hampi_sp <- opq ("hampi india") %>%
#'             add_osm_feature (key="historic", value="ruins") %>%
#'             osmdata_sp ()
#' }
osmdata_sp <- function(q, doc, quiet=TRUE, encoding) {
    if (missing (encoding))
        encoding <- 'UTF-8'

    obj <- osmdata () # uses class def
    if (missing (q) & !quiet)
        message ('q missing: osmdata object will not include query')
    else if (is (q, 'overpass_query'))
    {
        obj$bbox <- q$bbox
        obj$overpass_call <- opq_string (q)
    } else if (is.character (q))
        obj$overpass_call <- q
    else
        stop ('q must be an overpass query or a character string')

    if (missing (doc))
    {
        doc <- overpass_query (query = obj$overpass_call, quiet = quiet,
                               encoding = encoding)

        obj$timestamp <- get_timestamp ()
    } else
    {
        if (is.character (doc))
        {
            if (!file.exists (doc))
                stop ("file ", doc, " does not exist")
            doc <- xml2::read_xml (doc)
        }
        obj$timestamp <- get_timestamp (doc)
        doc <- as.character (doc)
    }

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

    return (obj)
}

#' Make an 'sf' object from an 'sfc' list and associated data matrix returned
#' from 'rcpp_osmdata_sf'
#'
#' @param ... list of objects, at least on of which must be of class 'sfc'
#' @return An object of class `sf` 
#'
#' @note Most of this code written by Edzer Pebesma, and taken from 
#' \url{https://github.com/edzer/sfr/blob/master/R/agr.R} and 
#' \url{https://github.com/edzer/sfr/blob/master/R/sfc.R}
#'
#' @noRd
make_sf <- function (...)
{
    x <- list (...)
    sf <- sapply (x, function(i) inherits(i, "sfc")) #nolint (gp() re: sapply)
    sf_column <- which (sf)
    if (!is.null (names (x [[sf_column]])))
        row.names <- names (x [[sf_column]])
    else
        row.names <- seq_along (x [[sf_column]])
    df <- if (length(x) == 1) # ONLY sfc
        data.frame(row.names = row.names)
    else # create a data.frame from list:
        data.frame(x[-sf_column], row.names = row.names,
                   stringsAsFactors = TRUE)

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


#' Return an OSM Overpass query as an \code{osmdata} object in \code{sf} format.
#'
#' @param q An object of class `overpass_query` constructed with \code{opq} and
#'        \code{add_osm_feature}. May be be omitted, in which case the
#'        \code{osmdata} object will not include the query.
#' @param doc If missing, \code{doc} is obtained by issuing the overpass query,
#'        \code{q}, otherwise either the name of a file from which to read data,
#'        or an object of class \code{XML} returned from \code{osmdata_xml}. 
#' @param quiet suppress status messages. 
#' @param encoding Unless otherwise specified XML documents are assumed to be
#'        encoded as UTF-8 or UTF-16. If the document is not UTF-8/16, and lacks
#'        an explicit encoding directive, this allows you to supply a default.
#' @return An object of class `osmdata` with the OSM components (points, lines,
#'         and polygons) represented in \code{sf} format.
#' @export
#'
#' @examples
#' \dontrun{
#' hampi_sf <- opq ("hampi india") %>%
#'             add_osm_feature (key="historic", value="ruins") %>%
#'             osmdata_sf ()
#' }
osmdata_sf <- function(q, doc, quiet=TRUE, encoding) {
    if (missing (encoding))
        encoding <- 'UTF-8'

    obj <- osmdata () # uses class def
    if (missing (q) & !quiet)
        message ('q missing: osmdata object will not include query')
    else if (is (q, 'overpass_query'))
    {
        obj$bbox <- q$bbox
        obj$overpass_call <- opq_string (q)
    } else if (is.character (q))
        obj$overpass_call <- q
    else
        stop ('q must be an overpass query or a character string')

    if (missing (doc))
    {
        doc <- overpass_query (query = obj$overpass_call, quiet = quiet,
                               encoding = encoding)

        obj$timestamp <- get_timestamp ()
    } else
    {
        if (is.character (doc))
        {
            if (!file.exists (doc))
                stop ("file ", doc, " does not exist")
            doc <- xml2::read_xml (doc)
        }
        obj$timestamp <- get_timestamp (doc)
        doc <- as.character (doc)
    }


    if (!quiet)
        message ('converting OSM data to sf format')
    res <- rcpp_osmdata_sf (doc)
    if (missing (q))
        obj$bbox <- paste (res$bbox, collapse = ' ')

    # This is repetitive, but sf uses the allocated names, so get and assign can
    # not be used.
    # TODO: Find a way to loop this
    #nms <- c ("points", "lines", "polygons", "multilines", "multipolygons")
    #for (n in nms)
    #{
    #    onm <- paste0 ("osm_", n)
    #    if (length (res [[paste0 (n, "_kv")]]) > 0)
    #        obj [[onm]] <- make_sf (res [[n]], res [[paste0 (n, "_kv")]])
    #    else
    #        obj [[onm]] <- make_sf (res [[n]])
    #}

    geometry <- res$points
    if (length (res$points_kv) > 0)
        obj$osm_points <- make_sf (geometry, res$points_kv)
    else
        obj$osm_points <- make_sf (geometry)

    geometry <- res$lines
    if (length (res$lines_kv) > 0)
        obj$osm_lines <- make_sf (geometry, res$lines_kv)
    else
        obj$osm_lines <- make_sf (geometry)

    geometry <- res$polygons
    if (length (res$polygons_kv) > 0)
        obj$osm_polygons <- make_sf (geometry, res$polygons_kv)
    else
        obj$osm_polygons <- make_sf (geometry)

    geometry <- res$multilines
    if (length (res$multilines_kv) > 0)
        obj$osm_multilines <- make_sf (geometry, res$multilines_kv)
    else
        obj$osm_multilines <- make_sf (geometry)

    geometry <- res$multipolygons
    if (length (res$multipolygons_kv) > 0)
        obj$osm_multipolygons <- make_sf (geometry, res$multipolygons_kv)
    else
        obj$osm_multipolygons <- make_sf (geometry)

    return (obj)
}
