#' Return an OSM Overpass query in XML format 
#' Read an (XML format) OSM Overpass response from a string, a connection,
#' or a raw vector.
#'
#' @param q An object of class `overpass_query` constructed with \code{opq} and
#'        \code{add_feature}.
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
osmdata_xml <- function(q, quiet=TRUE, encoding) {
    if (missing (encoding))
        encoding <- 'UTF-8'

    #doc <- xml2::read_xml(osm_response, encoding=encoding)
    #rcpp_osmdata_sp (doc)
    doc <- overpass_query (q, quiet=quiet, encoding=encoding)
    xml2::read_xml (doc)
}

#' Return an OSM Overpass query as an \code{osmdata} object in \code{sp} format.
#'
#' @param q An object of class `overpass_query` constructed with \code{opq} and
#'        \code{add_feature}.
#' @param doc An object of class \code{XML} returned from \code{osmdata_xml}. If
#'        missing, \code{doc} is obtained by issuing the overpass query,
#'        \code{q}.  
#' @param quiet suppress status messages. 
#' @param encoding Unless otherwise specified XML documents are assumed to be
#'        encoded as UTF-8 or UTF-16. If the document is not UTF-8/16, and lacks
#'        an explicit encoding directive, this allows you to supply a default.
#' @return An object of class `osmdata` with the OSM components (points, lines,
#'         and polygons) represented in \code{sp} format.
#' @export
osmdata_sp <- function(q, doc, quiet=TRUE, encoding) {
    if (missing (encoding))
        encoding <- 'UTF-8'

    obj <- osmdata () # uses class def
    obj$bbox <- q$bbox
    obj$overpass_call <- q

    if (missing (doc))
    {
        doc <- overpass_query (q, quiet=quiet, encoding=encoding)
        obj$timestamp <- timestamp (quiet=TRUE, prefix="[ ", suffix=" ]")
    } else
    {
        # Convert XML timestamp to `date()` format:
        tstmp <- xml2::xml_text (xml2::xml_find_all (doc, "//meta/@osm_base"))
        wday <- lubridate::wday (tstmp, label=TRUE)
        mon <- lubridate::month (tstmp, label=TRUE)
        day <- lubridate::day (tstmp)
        year <- lubridate::year (tstmp)
        # TODO: Get this reges to **exclude** 'T' and 'Z'
        hms <- regmatches (tstmp, regexpr ('T(.*?)Z', tstmp))
        hms <- substring (hms, 2, nchar (hms) - 1)
        obj$timestamp <- timestamp (paste (wday, mon, day, hms, year), quiet=TRUE)
        doc <- as.character (doc)
    }

    if (!quiet)
        message ('convertig OSM data to sp format')
    res <- rcpp_osmdata_sp (doc)
    obj$osm_points <- res$points
    obj$osm_lines <- res$lines
    obj$osm_polygons <- res$polygons

    return (obj)
}

make_sf <- function (...)
{
    x <- list (...)
    sf = sapply(x, function(i) inherits(i, "sfc"))
    sf_column <- which (sf)
    row.names <- seq_along (x [[sf_column]])
    df <- if (length(x) == 1) # ONLY sfc
                data.frame(row.names = row.names)
            else # create a data.frame from list:
                    data.frame(x[-sf_column], row.names = row.names, 
                           stringsAsFactors = TRUE)

    object = as.list(substitute(list(...)))[-1L] 
    arg_nm = sapply(object, function(x) deparse(x))
    sfc_name <- make.names(arg_nm[sf_column])
    df [[sfc_name]] <- x [[sf_column]]
    attr(df, "sf_column") = sfc_name
    f = factor(rep(NA_character_, length.out = ncol(df) - 1), 
               levels = c ("constant", "aggregate", "identity"))
    # The right way to do it - not yet in "sf"!
    names(f) = names(df)[-ncol (df)]
    # The current, wrong way as done in sf:
    #names(f) = names(df)[-sf_column]
    attr(df, "relation_to_geometry") = f
    class(df) = c("sf", class(df))
    return (df)
}

#' Return an OSM Overpass query as an \code{osmdata} object in \code{sf} format.
#'
#' @param q An object of class `overpass_query` constructed with \code{opq} and
#'        \code{add_feature}.
#' @param doc An object of class \code{XML} returned from \code{osmdata_xml}. If
#'        missing, \code{doc} is obtained by issuing the overpass query,
#'        \code{q}.  
#' @param quiet suppress status messages. 
#' @param encoding Unless otherwise specified XML documents are assumed to be
#'        encoded as UTF-8 or UTF-16. If the document is not UTF-8/16, and lacks
#'        an explicit encoding directive, this allows you to supply a default.
#' @return An object of class `osmdata` with the OSM components (points, lines,
#'         and polygons) represented in \code{sf} format.
#' @export
osmdata_sf <- function(q, doc, quiet=TRUE, encoding) {
    if (missing (encoding))
        encoding <- 'UTF-8'

    obj <- osmdata () # uses class def
    obj$bbox <- q$bbox
    obj$overpass_call <- q

    if (missing (doc))
    {
        doc <- overpass_query (q, quiet=quiet, encoding=encoding)
        obj$timestamp <- timestamp (quiet=TRUE, prefix="[ ", suffix=" ]")
    } else
    {
        # Convert XML timestamp to `date()` format:
        tstmp <- xml2::xml_text (xml2::xml_find_all (doc, "//meta/@osm_base"))
        wday <- lubridate::wday (tstmp, label=TRUE)
        mon <- lubridate::month (tstmp, label=TRUE)
        day <- lubridate::day (tstmp)
        year <- lubridate::year (tstmp)
        # TODO: Get this reges to **exclude** 'T' and 'Z'
        hms <- regmatches (tstmp, regexpr ('T(.*?)Z', tstmp))
        hms <- substring (hms, 2, nchar (hms) - 1)
        obj$timestamp <- timestamp (paste (wday, mon, day, hms, year), quiet=TRUE)
        doc <- as.character (doc)
    }

    if (!quiet)
        message ('convertig OSM data to sp format')
    res <- rcpp_osmdata (doc)
    xy <- res$points # sf geometry will then be labelled "xy"
    sf_points <- make_sf (xy, res$points_kv)
    obj$osm_points <- sf_points
    #obj$osm_lines <- res$lines
    #obj$osm_polygons <- res$polygons
    obj$lines <- res$lines
    obj$lines_kv <- res$lines_kv
    obj$polygons <- res$polygons
    obj$polygons_kv <- res$polygons_kv

    return (obj)
}
