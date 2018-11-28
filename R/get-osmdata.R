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
        q <- opq_string (q)
    else if (!is.character (q))
        stop ('q must be an overpass query or a character string')

    doc <- overpass_query (query = q, quiet = quiet, encoding = encoding)
    doc <- xml2::read_xml (doc, encoding = encoding)
    if (!missing (filename))
        xml2::write_xml (doc, file = filename)
    invisible (doc)
}

#' Return an OSM Overpass query in PBF (Protocol Buffer Format).
#'
#' @inheritParams osmdata_xml
#'
#' @return An binary Protocol Buffer Format (PBF) object.
#'
#' @note This function is experimental, and \pkg{osmdata} can currently NOT do
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
#' @param encoding Unless otherwise specified XML documents are assumed to be
#'        encoded as UTF-8 or UTF-16. If the document is not UTF-8/16, and lacks
#'        an explicit encoding directive, this allows you to supply a default.
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
osmdata_sp <- function(q, doc, quiet = TRUE, encoding = 'UTF-8')
{
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
        obj$meta <- list (timestamp = get_timestamp (docx),
                      OSM_version = get_osm_version (docx),
                      overpass_version = get_overpass_version (docx))
    } else
    {
        if (is.character (doc))
        {
            if (!file.exists (doc))
                stop ("file ", doc, " does not exist")
            doc <- xml2::read_xml (doc)
        }
        obj$meta <- list (timestamp = get_timestamp (doc),
                      OSM_version = get_osm_version (doc),
                      overpass_version = get_overpass_version (doc))
        doc <- as.character (doc)
    }
    list (obj = obj, doc = doc)
}

#' Make an 'sf' object from an 'sfc' list and associated data matrix returned
#' from 'rcpp_osmdata_sf'
#'
#' @param ... list of objects, at least one of which must be of class 'sfc'
#' @return An object of class `sf` 
#'
#' @note Most of this code written by Edzer Pebesma, and taken from 
#' <https://github.com/edzer/sfr/blob/master/R/agr.R> and 
#' <https://github.com/edzer/sfr/blob/master/R/sfc.R>
#'
#' @noRd
make_sf <- function (...)
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

sf_types <- c ("points", "lines", "polygons", "multilines", "multipolygons")

#' Return an OSM Overpass query as an \link{osmdata} object in \pkg{sf}
#' format.
#'
#' @inheritParams osmdata_sp
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

    temp <- fill_overpass_data (obj, doc, quiet = quiet)
    obj <- temp$obj
    doc <- temp$doc

    if (!quiet)
        message ('converting OSM data to sf format')
    res <- rcpp_osmdata_sf (doc)
    if (missing (q))
        obj$bbox <- paste (res$bbox, collapse = ' ')

    for (ty in sf_types)
        obj <- fill_objects (res, obj, type = ty)
    class (obj) <- c (class (obj), "osmdata_sf")

    return (obj)
}

fill_objects <- function (res, obj, type = "points")
{
    if (!type %in% sf_types)
        stop ("type must be one of ", paste (sf_types, collapse = " "))

    geometry <- res [[type]]
    obj_name <- paste0 ("osm_", type)
    kv_name <- paste0 (type, "_kv")
    if (length (res [[kv_name]]) > 0)
        obj [[obj_name]] <- make_sf (geometry, res [[kv_name]])
    else
        obj [[obj_name]] <- make_sf (geometry)

    return (obj)
}

#' Return an OSM Overpass query as an \link{osmdata} object in
#' `silicate` (`SC`) format.
#'
#' @inheritParams osmdata_sp
#' @param directed Should edges be considered directed where not otherwise
#'      labelled?  (See Note).
#' @return An object of class `osmdata` representing the original OSM hierarchy
#'      of nodes, ways, and relations.
#' @export
#'
#' @note The `silicate` format is currently highly experimental, and
#'      recommended for use only if you really know what you're doing.
#' @note If `directed = TRUE`, all edges that are not explicitly designated
#'      as one-way are duplicated in the `sc$object_link_edge` table to
#'      represent bi-directional flow. This is useful for routing, for example
#'      through converting the result to an \pkg{igraph} or \pkg{dodgr} object.
#'      Note that other text values such as `directed = "bicycle"` are also
#'      acceptable, in which case values for the OSM key "oneway:bicycle" -
#'      rather than the generic "oneway" key - will be used to determine
#'      directionality of flow.
#'
#' @examples
#' \dontrun{
#' hampi_sf <- opq ("hampi india") %>%
#'             add_osm_feature (key="historic", value="ruins") %>%
#'             osmdata_sc ()
#' }
osmdata_sc <- function(q, doc, directed = FALSE, quiet=TRUE, encoding) {
    if (missing (encoding))
        encoding <- 'UTF-8'

    obj <- osmdata () # class def used here to for fill_overpass_data fn
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

    temp <- fill_overpass_data (obj, doc, quiet = quiet)
    obj <- temp$obj
    doc <- temp$doc

    if (!(is.logical (directed) | is.character (directed)))
        stop ("directed must be either logical or character")

    if (!quiet)
        message ('converting OSM data to sc format')
    res <- rcpp_osmdata_sc (temp$doc)

    # res has the $vertex, $edge and $object_link_edge tables ready to go.  The
    # $object table is mostly just key-val pairs, but the relations have
    # additional members - called "ref" and "role" entries. The key-val tables
    # are therefore expanded to add these two columns before rbind-ing the whole
    # lot to the one table:
    if (nrow (res$obj_rel) > 0)
        res$obj_rel$obj_type <- "relation"
        res$rel_kv$obj_type <- "relation"
    if (nrow (res$obj_way) > 0)
        res$obj_way$obj_type <- "way"
    if (nrow (res$obj_node) > 0)
        res$obj_node$obj_type <- "node"

    #if (nrow (res$rel) > 0)
    #{
    #    # Change res$rel from ("ref", "role") to ("value", "key")
    #    res$rel <- data.frame (object_ = res$rel$object,
    #                           key = paste0 ("rel_role_", res$rel$role),
    #                           value = res$rel$ref,
    #                           obj_type = "relation",
    #                           stringsAsFactors = FALSE)
    #}

    res$object_link_edge$native_ <- TRUE
    #res <- duplicate_twoway_edges (res, directed)

    obj <- list () # SC **does not** use osmdata class definition
    obj$object <- tibble::as.tibble (rbind (res$obj_rel,
                                            res$obj_way,
                                            res$obj_node))
    obj$object_link_edge <- tibble::as.tibble (res$object_link_edge)
    obj$edge <- tibble::as.tibble (res$edge)
    obj$vertex <- tibble::as.tibble (res$vertex)
    obj$meta <- tibble::tibble (proj = NA_character_,
                                ctime = temp$obj$meta$timestamp,
                                OSM_version = temp$obj$meta$OSM_version,
                                overpass_version = temp$obj$meta$overpass_version,
                                directed = directed)
    #if (missing (q)) # TODO: Implement this!
    #    obj$meta$bbox <- paste (res$bbox, collapse = ' ')

    attr (obj, "join_ramp") <- c ("object", "object_link_edge", "edge", "vertex")
    attr (obj, "class") <- c ("SC", "sc")

    return (obj)
}

duplicate_twoway_edges <- function (x, directed)
{
    if (is.logical (directed))
    {
        if (!directed)
            return (x)
        else
            directed <- "oneway"
    } else
    {
        directed <- paste0 ("oneway:", directed)
    }
    indx <- which (x$way_kv$key == directed)
    # Values for oneway tags are generally "yes" and "no", but the former can
    # also include specific directives such as "use_sidepath", so it's safer
    # here to set all ways with oneway != "no" as oneway
    oneway_objs <- x$way_kv$object_ [which (x$way_kv$value [indx] != "no")]
    if (length (oneway_objs) == 0)
    {
        message ("There are no oneway entries for key = [", directed, "]")
        return (x)
    }

    # A non-dplyr way to re-join the two object_link_edge tables by their
    # $object_ columns, retaining original sorting
    ole1 <- split (x$object_link_edge, f = x$object_link_edge$object_)

    ole2 <- x$object_link_edge
    ole2$native_ <- FALSE
    ole2 <- ole2 [which (!ole2$object_ %in% oneway_objs), ]
    ole2 <- split (ole2, f = ole2$object_)

    oles <- c (ole1, ole2)
    nms <- unique (names (oles))
    ole <- lapply (nms, function (i) do.call (rbind,
                                              oles [grep (i, names (oles))]))
    ole <- do.call (rbind, ole)
    rownames (ole) <- NULL

    x$object_link_edge <- ole

    return (x)
}
