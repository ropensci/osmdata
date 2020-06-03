#' List recognized features in OSM 
#'
#' @return character vector of all known features
#'
#' @note requires internet access
#' @references <https://wiki.openstreetmap.org/wiki/Map_Features>
#'
#' @export
#'
#' @examples
#' \dontrun{
#' available_features()
#' }
available_features <- function() {

    url_ftrs <- "https://wiki.openstreetmap.org/wiki/Map_Features"
    if (curl::has_internet ())
    {
        pg <- xml2::read_html (httr::GET (url_ftrs))
        keys <- xml2::xml_attr (rvest::html_nodes (pg, "a[href^='/wiki/Key']"), #nolint
                                "href") %>% 
            strsplit ("/wiki/Key:") %>% 
            unlist ()
        keys [keys != ""] %>%
            sort () %>% 
            unique ()
    } else
    {
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
#' @references <https://wiki.openstreetmap.org/wiki/Map_Features>
#'
#' @export
#'
#' @examples
#' \dontrun{
#' available_tags("aerialway")
#' }
available_tags <- function(feature) {
    url_ftrs <- "https://wiki.openstreetmap.org/wiki/Map_Features"

    ret <- NULL
    if (curl::has_internet ())
    {
        if (missing (feature))
            stop ("Please specify feature")

        pg <- xml2::read_html (httr::GET (url_ftrs))
        taglists <- rvest::html_nodes (pg, "div[class='taglist']") %>%
            rvest::html_attr ("data-taginfo-taglist-tags")
        taglists <- lapply (taglists, function (i)
        {
            temp <- strsplit (i, "=") [[1]]
            res <- NULL
            if (length (temp) == 2)
            {
                res <- strsplit (temp [2], ",")
                names (res) <- temp [1]
            }
            return (res)
        })
        taglists [vapply (taglists, is.null, logical (1))] <- NULL
        keys <- unique (unlist (lapply (taglists, names)))
        
        if (!(feature %in% keys))
        {
            # try old style tables
            tags <- rvest::html_nodes (pg, sprintf ("a[title^='Tag:%s']", feature))
            tags <- vapply (strsplit (xml2::xml_attr (tags, "href"), "%3D"),
                            function (i) i [2], character (1))
            ret <- unique (sort (tags))
        } else 
        {
            taglists <- stats::setNames (do.call (mapply,
                              c (FUN = c, lapply (taglists, `[`, keys))), keys)

            taglists <- mapply (unique, taglists)
            ret <- taglists [[feature]] %>% sort ()
        }
    } else {
        message ("No internet connection")
    }
    return (ret)
}
