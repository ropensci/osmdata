#' Return an OSM Overpass query in XML format
#' Read an (XML format) OSM Overpass response from a string, a connection,
#' or a raw vector.
#'
#' @param q An object of class `overpass_query` constructed with
#'   \link{opq} and \link{add_osm_feature} or a string with a valid query, such
#'   as `"(node(39.4712701,-0.3841326,39.4713799,-0.3839475);); out;"`. See examples below.
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
#' query <- opq ("hampi india") |>
#'     add_osm_feature (key = "historic", value = "ruins")
#' # Then extract data from 'Overpass' API and save to local file:
#' osmdata_xml (query, filename = "hampi.osm")
#' }
#'
#' # Complex query as a string (not possible with regular osmdata functions)
#' q <- '[out:xml][timeout:50];
#'     area[name="Països Catalans"][boundary=political]->.boundaryarea;
#'
#'     rel(area.boundaryarea)[admin_level=8][boundary=administrative];
#'     map_to_area -> .all_level_8_areas;
#'
#'     ( nwr(area.boundaryarea)[amenity=townhall]; >; );
#'     is_in;
#'     area._[admin_level=8][boundary=administrative] -> .level_8_areas_with_townhall;
#'
#'     (.all_level_8_areas; - .level_8_areas_with_townhall;);
#'     rel(pivot);
#'     out tags;'
#'
#' \dontrun{
#' no_townhall <- osmdata_xml (q)
#' no_townhall
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
