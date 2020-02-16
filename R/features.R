#' List features in OSM 
#' 
#' List most commonly used features in OSM as described in OSM's
#' [Map Features page](https://wiki.openstreetmap.org/wiki/Map_Features).
#' Optionally return the full list of features via the
#' [`taginfo` API](https://taginfo.openstreetmap.org/).
#'
#' @param taginfo If TRUE retrieve the full list of OSM features.
#'                **NOTE**: it can be slow, ca. 60 seconds.
#' 
#' @return Character vector of OSM features.
#'
#' @note Requires internet access.
#' @references <https://wiki.openstreetmap.org/wiki/Map_Features>
#'
#' @export
#'
#' @examples
#' \dontrun{
#' available_features()
#' }
available_features <- function (taginfo = FALSE)
{
    if (curl::has_internet ())
    {
        if (taginfo == FALSE)
        {
            url_ftrs <- "https://wiki.openstreetmap.org/wiki/Map_Features"
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
            url <- "https://taginfo.openstreetmap.org/api/4/keys/all?sortname=key&sortorder=asc"
            g <- httr::GET (url)
            if (httr::status_code (g) == 200)
            {
                c <- httr::content (g, as = "text") %>% jsonlite::fromJSON ()
                k <- c [["data"]] [["key"]]
                if (is.null (k)) k <- character ()
                k
            } 
        }
    } else
    {
        message ("No internet connection")
    }
}

#' List tags associated with a feature
#'
#' List most commonly used tags asociated to a `feature` as described in OSM's
#' [Map Features page](https://wiki.openstreetmap.org/wiki/Map_Features).
#' Optionally return the full list of tags used for `feature` via the
#' [`taginfo` API](https://taginfo.openstreetmap.org/).
#'
#' @param feature feature to retrieve
#'
#' @param taginfo If TRUE retrieve the full list of OSM tags for `feature`.
#'                
#' @return Character vector of all known tags for a feature.
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
available_tags <- function(feature, taginfo = FALSE) 
{
    if (curl::has_internet ())
    {
        if (missing (feature) || is.null(feature))
            stop ("Please specify feature")

        if (taginfo == FALSE)
        {
            url_ftrs <- "https://wiki.openstreetmap.org/wiki/Map_Features"
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
                tags <- rvest::html_nodes (pg, sprintf("a[title^='Tag:%s']", feature))
                tags <- vapply (strsplit (xml2::xml_attr (tags, "href"), "%3D"),
                                function (i) i [2], character (1))
                unique (sort (tags))
            } else
            {
                taglists <- setNames (do.call (mapply, c(FUN=c, lapply (taglists, `[`, keys))), keys)
                taglists <- mapply (unique, taglists)
                taglists [[feature]] %>% sort ()
            }
        }
        else {
            url <- "https://taginfo.openstreetmap.org/api/4/tags/list"
            g <- httr::GET (url, query = list(key = feature))
            if (httr::status_code (g) == 200)
            {
                c <- httr::content (g, as = "text") %>% jsonlite::fromJSON ()
                t <- c [["data"]] [["value"]]
                if (is.null (t)) t <- character ()
                t
            }
        }
    } else {
        message ("No internet connection")
    }
}
