#' Return an OSM Overpass query as an \link{osmdata} object in \pkg{sp}
#' format.
#'
#' @param q An object of class `overpass_query` constructed with
#'      \link{opq} and \link{add_osm_feature} or a string with a valid query, such
#'      as `"(node(39.4712701,-0.3841326,39.4713799,-0.3839475);); out;"`.
#'      39.4712701,-0.3841326,39.4713799,-0.3839475
#'      May be be omitted, in which case the \link{osmdata} object will not
#'      include the query. See examples below.
#' @param doc If missing, `doc` is obtained by issuing the overpass query,
#'        `q`, otherwise either the name of a file from which to read data,
#'        or an object of class \pkg{xml2} returned from \link{osmdata_xml}.
#' @param quiet suppress status messages.
#'
#' @return An object of class `osmdata` with the OSM components (points, lines,
#'         and polygons) represented in \pkg{sp} format.
#'
#' @family extract
#' @export
#'
#' @examples
#' # Bounding box of "hampi india":
#' bb <- c (76.4410201, 15.3158, 76.4810201, 15.3558)
#' query <- opq (bb)
#' query <- add_osm_feature (query, key = "historic", value = "ruins")
#' # Equivalent to:
#' \dontrun{
#' query <- opq ("hampi india") |>
#'     add_osm_feature (key = "historic", value = "ruins")
#' }
#' # Then extract data from 'Overpass' API
#' \dontrun{
#' hampi_sp <- osmdata_sp ()
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
#'     (._; >;);
#'     out;'
#'
#' \dontrun{
#' no_townhall <- osmdata_sp (q)
#' no_townhall
#' }
osmdata_sp <- function (q, doc, quiet = TRUE) {

    obj <- osmdata () # uses class def
    if (missing (q)) {
        if (missing (doc)) {
            stop (
                'arguments "q" and "doc" are missing, with no default. ',
                "At least one must be provided."
            )
        }
        if (!quiet) {
            message ("q missing: osmdata object will not include query")
        }
    } else if (is (q, "overpass_query")) {
        obj$bbox <- q$bbox
        obj$overpass_call <- opq_string_intern (q, quiet = quiet)
    } else if (is.character (q)) {
        obj$overpass_call <- q
    } else {
        stop ("q must be an overpass query or a character string")
    }

    check_not_implemented_queries (obj)

    temp <- fill_overpass_data (obj, doc, quiet = quiet)
    obj <- temp$obj
    doc <- temp$doc

    if (isTRUE (obj$meta$query_type == "adiff")) {
        # return incorrect result
        stop ("adiff queries not yet implemented.")
    }

    if (!quiet) {
        message ("converting OSM data to sp format")
    }

    res <- rcpp_osmdata_sp (paste0 (doc))
    if (is.null (obj$bbox)) {
        obj$bbox <- paste (res$bbox, collapse = " ")
    }
    obj$osm_points <- res$points
    obj$osm_lines <- res$lines
    obj$osm_polygons <- res$polygons
    obj$osm_multilines <- res$multilines
    obj$osm_multipolygons <- res$multipolygons

    osm_items <- grep ("^osm_", names (obj))
    obj [osm_items] <- fix_columns_list (obj [osm_items])
    obj [osm_items] <- lapply (obj [osm_items], function (x) {
        x@data <- setenc_utf8 (x@data)
        x
    })
    class (obj) <- c (class (obj), "osmdata_sp")

    return (obj)
}
