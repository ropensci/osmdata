# for CRAN checks until I switch to underscore versions of dplyr stuff
. <- k <- v <- way_id <- id <- lon <- lat <- NULL

overpass_base_url <- "http://overpass-api.de/api/interpreter"

# "fastmatch" version of %in%
"%fmin%" <- function(x, table) { fmatch(x, table, nomatch = 0) > 0 }

# test if a given xpath exists in doc
has_xpath <- function(doc, xpath) {

  tryCatch(length(xml_find_all(doc, xpath)) > 0,
           error=function(err) { return(FALSE) },
           warning=function(wrn) { message(wrn$message) ; return(TRUE); })

}

# process an OSM response document
process_doc <- function(doc) {

  # which types of OSM things do we have?
  has_nodes <- has_xpath(doc, "//node")
  has_ways <- has_xpath(doc, "//way")
  has_relations <- has_xpath(doc, "//relation")

  # start crunching
  if (has_nodes) {
    osm_nodes <- process_osm_nodes(doc)
    # if we only have nodes return a SpatialPointsDataFrame
    if (!has_ways) return(osm_nodes_to_sptsdf(osm_nodes))
  }

  if (has_ways) {
    # gotta have nodes to make ways
    if (!has_nodes) stop("Cannot make ways if query results do not have nodes", call.=FALSE)
    osm_ways <- process_osm_ways(doc, osm_nodes)
    # TODO if we have relations we need to do more things
    return(osm_ways_to_spldf(doc, osm_ways))
  }

  if (has_relations) {

    # this inherently has to return a list structure of some kind

  }

  # if we got here something is really wrong
  return(NULL)

}

# give it a named matrix or a named vector (or an unnamed vector) return a string
bbox_to_string <- function(bbox) {
  if (!is.null(bbox)) {
    if (inherits(bbox, "matrix")) {
      if (all(rownames(bbox) %in% c("x", "y")    ) &
          all(colnames(bbox) %in% c("min", "max"))) {
        bbox <- c(bbox["x", "min"], bbox["y", "min"], bbox["x", "max"], bbox["y", "max"])
        bbox <- paste0(bbox, collapse=",")
      } else if (all(rownames(bbox) %in% c("coords.x1", "coords.x2")) &
                 all(colnames(bbox) %in% c("min", "max"))) {
        bbox <- c(bbox["x", "coords.x1"], bbox["y", "coords.x1"], bbox["x", "coords.x2"], bbox["y", "coords.x2"])
        bbox <- paste0(bbox, collapse=",")
      }
    } else {
      if (length(bbox) > 1 & length(bbox) == 4) {
        if (all(names(bbox) %in% c("left", "bottom", "right", "top"))) {
          bbox <- paste0(bbox[c("left", "bottom", "right", "top")], collapse=",")
        } else {
          bbox <- paste0(bbox, collapse=",")
        }
      }
    }
  }
  return(bbox)
}
