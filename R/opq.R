#' Begin building an Overpass query
#'
#' @param bbox base bounding box to use with the features. Must set the individual
#'        feature bbox values if this value is not set.
#' @return \code{opq} object
#' @export
#' @examples
#' opq(bbox="43.0135509,-70.8229993,43.0996118,-70.7280563") %>%
#'   add_feature("amenity", "pub", ) %>%
#'   add_feature("amenity", "restaurant") %>%
#'   add_feature("amenity", "library") %>%
#'   issue_query() -> reading_noms
#'
#' plot(reading_noms)
opq <- function(bbox=NULL) {
  return(list(bbox=bbox,
              features=c("[out:xml][timeout:25];\n(\n")))
}

#' Add a feature to an Overpass query
#'
#' @param opq Overpass query object
#' @param key feature key
#' @param value value for feature key
#' @param bbox optional bounding box for the feature query; must be set if no
#'        opq query bbox has been set
#' @return \code{opq} object
#' @references \url{http://wiki.openstreetmap.org/wiki/Map_Features}
#' @export
add_feature <- function(opq, key, value, bbox=NULL) {

  if (is.null(bbox) & is.null(opq$bbox)) {
    stop("A base bounding box has to either be set in opq() or must be set here.", call.=FALSE)
  }

  if (is.null(bbox)) bbox <- opq$bbox

  paste0(sprintf(' node["%s"="%s"](%s);\n', key, value, bbox),
         sprintf('  way["%s"="%s"](%s);\n', key, value, bbox),
         sprintf('  relation["%s"="%s"](%s);\n\n', key, value, bbox)) -> thing

  opq$features <- c(opq$features, thing)

  opq

}

#' Finalize and issue an Overpass query
#'
#' @param opq Overpass query object
#' @export
issue_query <- function(opq) {
  opq$features <- c(opq$features, ");\nout body;\n>;\nout skel qt;")
  overpass_query(paste0(opq$features))
}

