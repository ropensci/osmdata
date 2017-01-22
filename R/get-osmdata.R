#' Return an OSM Overpass query in XML format 
#' Read an (XML format) OSM Overpass response from a string, a connection,
#' or a raw vector.
#'
#' @param q An object of class `overpass_query` constructed with \code{opq} and
#'        \code{add_feature}.
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
osmdata_xml <- function(q, filename, quiet=TRUE, encoding) {
    if (missing (encoding))
        encoding <- 'UTF-8'

    #doc <- xml2::read_xml(osm_response, encoding=encoding)
    #rcpp_osmdata_sp (doc)
    doc <- overpass_query (q, quiet=quiet, encoding=encoding)
    doc <- xml2::read_xml (doc)
    if (!missing (filename))
        xml2::write_xml (doc, file=filename)
    invisible (doc)
}

#' Return an OSM Overpass query as an \code{osmdata} object in \code{sp} format.
#'
#' @param q An object of class `overpass_query` constructed with \code{opq} and
#'        \code{add_feature}.
#' @param doc If missing, \code{doc} is obtained by issuing the overpass query,
#'        \code{q}, otherwise either the name of a file from which to read data,
#'        or an object of class \code{XML} returned from \code{osmdata_xml}. 
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
        if (is.character (doc))
        {
            if (!file.exists (doc))
                stop ("file ", doc, " does not exist")
            doc <- xml2::read_xml (doc)
        }
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

#' Make an 'sf' object from an 'sfc' list and associated data matrix returned
#' from 'rcpp_osmdata_sf'
#'
#' @param ... list of objects, at least on of which must be of class 'sfc'
#' @return An object of class `sf` 
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

#' Restructure data matrix returned from 'rcpp_osmdata'
#'
#' @param dat A data matrix of OSM key-value pairs
#' @return Equivalent data matrix with added row of 'osm_id' and 'name' as
#' second column (equivalent to GDAL output)
order_data_mat <- function (dat)
{
    # Remove key columns with no values
    indx <- which (apply (dat, 2, function (i) length (unique (i))) > 1)
    dat <- dat [,indx]
    # Move name column to 2nd position, as GDAL does
    ni <- which (colnames (dat) == "name")
    if (length (ni) > 0) # should always happen
    {
        nms <- dat [,ni]
        indx <- which (!colnames (dat) %in% "name")
        nms1 <- colnames (dat) [indx]
        dat <- cbind (nms, dat [,indx])
        colnames (dat) <- c ("name", nms1)
    }
    # And cbind rownames = osm_id as first column
    cnames <- c ("osm_id", colnames (dat))
    dat <- cbind (rownames (dat), dat)
    colnames (dat) <- cnames
    return (dat)
}

#' Return an OSM Overpass query as an \code{osmdata} object in \code{sf} format.
#'
#' @param q An object of class `overpass_query` constructed with \code{opq} and
#'        \code{add_feature}.
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
        if (is.character (doc))
        {
            if (!file.exists (doc))
                stop ("file ", doc, " does not exist")
            doc <- xml2::read_xml (doc)
        }
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

    # Make sf points:
    geometry <- res$points
    points_kv <- order_data_mat (res$points_kv)
    sf_points <- make_sf (geometry, points_kv)

    # make sf lines:
    geometry <- res$lines
    lines_kv <- order_data_mat (res$lines_kv)
    sf_lines <- make_sf (geometry, lines_kv)

    obj$osm_points <- sf_points
    #obj$lines <- res$lines
    #obj$lines_kv <- res$lines_kv
    obj$osm_lines <- sf_lines
    obj$multipolygons <- res$multipolygons
    obj$polygons_kv <- res$polygons_kv
    obj$multilinestrings <- res$multilinestrings

    return (obj)
}
