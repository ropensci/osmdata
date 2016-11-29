# for CRAN checks until I switch to underscore versions of dplyr stuff
. <- k <- v <- way_id <- id <- lon <- lat <- NULL

# test if a given xpath exists in doc
has_xpath <- function(doc, xpath) {

  tryCatch(length(xml2::xml_find_all(doc, xpath)) > 0,
           error=function(err) { return(FALSE) },
           warning=function(wrn) { message(wrn$message) ; return(TRUE); })

}

#' process an OSM response document
#' 
#' @param doc Lines of data
#' @export
process_doc <- function(doc) {

  list (
        osm_nodes=rcpp_get_points (doc),
        osm_ways=rcpp_get_lines (doc),
        osm_polygons=rcpp_get_polygons (doc)
  )
}

#' Convert a named matrix or a named vector (or an unnamed vector) return a string
#'
#' This function converts a bounding box into a string for use in web apis
#' 
#' @param bbox bounding box as matrix or vector. Unnamed vectors will be sorted
#' appropriately and must merely be in the order (x, y, x, y).
#'
#' @export
bbox_to_string <- function(bbox) {

  if (missing (bbox)) stop ("bbox must be provided")
  #if (is.character(bbox)) {
  #  bbox <- tmap::bb (bbox)
  #}
  if (!is.numeric (bbox)) stop ("bbox must be numeric")
  if (length (bbox) < 4) stop ("bbox must contain four elements")
  if (length (bbox) > 4) message ("only the first four elements of bbox used")

  if (inherits(bbox, "matrix")) {
    if (all (rownames (bbox) %in% c("x", "y")    ) &
        all (colnames (bbox) %in% c("min", "max"))) {
      bbox <- c(bbox["x", "min"], bbox["y", "min"], 
                bbox["x", "max"], bbox["y", "max"])
    } else if (all (rownames (bbox) %in% c("coords.x1", "coords.x2")) &
               all (colnames (bbox) %in% c("min", "max"))) {
      bbox <- c (bbox["x", "coords.x1"], bbox["y", "coords.x1"], 
                 bbox["x", "coords.x2"], bbox["y", "coords.x2"])
    }
    bbox <- paste0 (bbox[c(2,1,4,3)], collapse=",")
  } else {
    if (!is.null (names (bbox)) & 
        all (names (bbox) %in% c("left", "bottom", "right", "top"))) {
      bbox <- paste0 (bbox[c ("bottom", "left", "top", "right")], collapse=",")
    } else {
      x <- sort (bbox [c (1, 3)])
      y <- sort (bbox [c (2, 4)])
      bbox <- paste0 (c (y [1], x[1], y [2], x [2]), collapse=",")
    }
  }
  return(bbox)
}
