#' Return an OSM Overpass query as an \link{osmdata} object in
#' `silicate` (`SC`) format.
#'
#' @inheritParams osmdata_sp
#' @return An object of class `osmdata_sc` representing the original OSM hierarchy
#'      of nodes, ways, and relations.
#'
#' @note The `silicate` format is currently highly experimental, and
#'      recommended for use only if you really know what you're doing.
#'
#' @family extract
#' @export
#'
#' @examples
#' \dontrun{
#' hampi_sf <- opq ("hampi india") %>%
#'     add_osm_feature (key = "historic", value = "ruins") %>%
#'     osmdata_sc ()
#' }
osmdata_sc <- function (q, doc, quiet = TRUE) {

    obj <- osmdata () # class def used here to for fill_overpass_data fn

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
        stop ("adiff queries not yet implemented.")
    }

    if (!quiet) {
        message ("converting OSM data to sc format")
    }

    res <- rcpp_osmdata_sc (paste0 (doc))

    if (nrow (res$object_link_edge) > 0L) {
        res$object_link_edge$native_ <- TRUE
    }

    obj <- list () # SC **does not** use osmdata class definition
    obj$nodes <- tibble::as_tibble (res$nodes)
    obj$relation_members <- tibble::as_tibble (res$relation_members)
    obj$relation_properties <- tibble::as_tibble (res$relation_properties)
    obj$object <- tibble::as_tibble (res$object)
    obj$object_link_edge <- tibble::as_tibble (res$object_link_edge)
    obj$edge <- tibble::as_tibble (res$edge)
    obj$vertex <- tibble::as_tibble (res$vertex)
    obj$meta <- tibble::tibble (
        proj = NA_character_,
        ctime = temp$obj$meta$timestamp,
        OSM_version = temp$obj$meta$OSM_version,
        overpass_version = temp$obj$meta$overpass_version
    )

    if (!missing (q)) {
        if (!is.character (q)) {
            obj$meta$bbox <- q$bbox
        }
    } else {
        obj$meta$bbox <- getbb_sc (obj)
    }

    attr (obj, "join_ramp") <- c (
        "nodes",
        "relation_members",
        "relation_properties",
        "object",
        "object_link_edge",
        "edge",
        "vertex"
    )
    attr (obj, "class") <- c ("SC", "sc", "osmdata_sc")

    return (obj)
}


getbb_sc <- function (x) {

    apply (x$vertex [, 1:2], 2, range) %>%
        bbox_to_string ()
}
