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
#' @return An object of class `xml2::xml_document` containing the result of the
#'         overpass API query.
#'
#' @note Objects of class `xml_document` can be saved as `.xml` or
#' `.osm` files with `xml2::write_xml`.
#'
#' @family extract
#' @export
#'
#' @examples
#' \dontrun{
#' q <- opq ("hampi india")
#' q <- add_osm_feature (q, key = "historic", value = "ruins")
#' osmdata_xml (q, filename = "hampi.osm")
#' }
osmdata_xml <- function (q, filename, quiet = TRUE, encoding) {

    if (missing (encoding)) {
        encoding <- "UTF-8"
    }

    if (missing (q)) {
        stop ('argument "q" is missing, with no default.')
    } else if (is (q, "overpass_query")) {
        q <- opq_string_intern (q, quiet = quiet)
    } else if (!is.character (q)) {
        stop ("q must be an overpass query or a character string")
    }

    if (grepl ("\\[out:csv", q)) {
        stop ("out:csv queries only work with osmdata_data_frame().")
    }

    doc <- overpass_query (query = q, quiet = quiet, encoding = encoding)
    if (!missing (filename)) {
        xml2::write_xml (doc, file = filename)
    }

    invisible (doc)
}
