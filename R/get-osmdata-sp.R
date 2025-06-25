#' DEPRECATED: Return an OSM Overpass query as an \link{osmdata} object in \pkg{sp}
#' format.
#'
#' @inheritParams osmdata_sf
#'
#' @return An object of class `osmdata` with the OSM components (points, lines,
#'         and polygons) represented in \pkg{sp} format.
#'
#' @family extract
#' @export
#'
#' @examples
#' \dontrun{
#' query <- opq ("hampi india") |>
#'     add_osm_feature (key = "historic", value = "ruins")
#' # Then extract data from 'Overpass' API
#' hampi_sp <- osmdata_sp (query)
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

    .Deprecated (
        new = "osmdata_sf () or osmdata_sc ()",
        package = "osmdata",
        old = "osmdata_sp ()"
    )

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
