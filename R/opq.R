#' Begin building an Overpass query
#'
#' @param bbox base bounding box to use with the features. Must set the individual
#'        feature bbox values if this value is not set. Can be a matrix (i.e. what
#'        \code{sp::bbox} returns), an string with values ("left,bottom,top,right"),
#'        a vector of length 4. If the vector is named, the names will be used,
#'        otherwise, you should ensure the vector is in \code{c(top, left, bottom, right)}
#'        order.
#'
#' @return \code{opq} object
#' @export
#' @examples
#' opq(bbox="43.0135509,-70.8229993,43.0996118,-70.7280563") %>%
#'   add_feature("amenity", "pub", ) %>%
#'   add_feature("amenity", "restaurant") %>%
#'   add_feature("amenity", "library") %>%
#'   issue_query() -> reading_noms
#'
#' sp::plot(reading_noms$osm_nodes)
opq <- function(bbox=NULL) {
  return(list(bbox=bbox_to_string(bbox),
              features=c("[out:xml][timeout:25];\n(\n")))
}

#' Add a feature to an Overpass query
#'
#' @param opq Overpass query object
#' @param key feature key
#' @param value value for feature key
#' @param exact If FALSE, \code{value} is not interpreted exactly; see
#' \url{http://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide#Non-exact_names}
#' @param bbox optional bounding box for the feature query; must be set if no
#'        opq query bbox has been set
#' @return \code{opq} object
#' @references \url{http://wiki.openstreetmap.org/wiki/Map_Features}
#' @export
add_feature <- function(opq, key, value, exact=TRUE, bbox=NULL) {

  if (is.null(bbox) & is.null(opq$bbox)) {
    stop("A base bounding box has to either be set in opq() or must be set here.", 
         call.=FALSE)
  }

  if (is.null(bbox)) bbox <- bbox_to_string(opq$bbox)

  if (missing (value))
  {
      paste0(sprintf(' node["%s"](%s);\n', key, bbox),
             sprintf('  way["%s"](%s);\n', key, bbox),
             sprintf('  relation["%s"](%s);\n\n', key, bbox)) -> thing
  } else
  {
      if (exact) bind <- '='
      else bind <- '~'
      paste0(sprintf(' node["%s"%s"%s"](%s);\n', key, bind, value, bbox),
             sprintf('  way["%s"%s"%s"](%s);\n', key, bind, value, bbox),
             sprintf('  relation["%s"%s"%s"](%s);\n\n', key, bind, 
                     value, bbox)) -> thing
  }

  opq$features <- c(opq$features, thing)

  opq

}

#' Finalize and issue an Overpass query
#'
#' @param opq Overpass query object
#' @export
issue_query <- function(opq) {
  #opq$features <- c(opq$features, ");\nout body;\n>;\nout skel qt;")
  # MP: The default set "_" must be referenced ("._") to be correctly output:
  # http://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide#The_default_set_.22_.22_and_recalling_the_default_set_.22._.22
  opq$features <- c(opq$features, ");\n(._;>);\nout qt body;")

  #overpass_query(paste0(opq$features))
  # MP: This is clearer and matches exactly what httr does - line#64 of
  # https://github.com/hadley/httr/blob/master/R/body.R
  overpass_query(paste0(opq$features, collapse="\n"))
}

