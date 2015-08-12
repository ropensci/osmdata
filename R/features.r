#' List recognized features in OSM Overpass
#'
#' @return character vector of all known features
#' @note requires internet access
#' @references \url{http://wiki.openstreetmap.org/wiki/Map_Features}
#' @export
#' @examples
#' available_features()
available_features <- function() {

  pg <- html("http://wiki.openstreetmap.org/wiki/Map_Features")
  keys <- html_attr(html_nodes(pg, "a[href^='/wiki/Key']"), "title")
  unique(sort(gsub("^Key:", "", keys)))

}

#' List tags associated with a feature
#'
#' @return character vector of all known tags for a feature
#' @note requires internet access
#' @references \url{http://wiki.openstreetmap.org/wiki/Map_Features}
#' @export
#' @examples
#' available_tags("aerialway")
available_tags <- function(feature) {
  pg <- html("http://wiki.openstreetmap.org/wiki/Map_Features")
  tags <- html_attr(html_nodes(pg, sprintf("a[title^='Tag:%s']", feature)), "title")
  unique(sort(gsub(sprintf("Tag:%s=", feature), "", tags, fixed=TRUE)))
}


