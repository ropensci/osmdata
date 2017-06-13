#' List recognized features in OSM 
#'
#' @return character vector of all known features
#'
#' @note requires internet access
#' @references \url{http://wiki.openstreetmap.org/wiki/Map_Features}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' available_features()
#' }
available_features <- function() {

    url_ftrs <- "http://wiki.openstreetmap.org/wiki/Map_Features"
    if (curl::has_internet ())
    {
        pg <- xml2::read_html (httr::GET (url_ftrs))
        keys <- xml2::xml_attr (rvest::html_nodes (pg, "a[href^='/wiki/Key']"), #nolint
                                "title")
        unique (sort (gsub ("^Key:", "", keys)))
    } else {
        message ("No internet connection")
    }
}

#' List tags associated with a feature
#'
#' @param feature feature to retrieve
#'
#' @return character vector of all known tags for a feature
#'
#' @note requires internet access
#' @references \url{http://wiki.openstreetmap.org/wiki/Map_Features}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' available_tags("aerialway")
#' }
available_tags <- function(feature) {
    url_ftrs <- "http://wiki.openstreetmap.org/wiki/Map_Features"

    if (curl::has_internet ())
    {
        if (missing (feature))
            stop ("Please specify feature")

        pg <- xml2::read_html (httr::GET (url_ftrs))
        tags <- xml2::xml_attr (rvest::html_nodes (pg,
                           sprintf("a[title^='Tag:%s']", feature)), "title")
        unique (sort (gsub (sprintf ("Tag:%s=", feature), "",
                            tags, fixed = TRUE)))
    } else {
        message ("No internet connection")
    }
}
