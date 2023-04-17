#' List recognized features in OSM
#'
#' @return character vector of all known features
#'
#' @note requires internet access
#' @references <https://wiki.openstreetmap.org/wiki/Map_Features>
#'
#' @family osminfo
#' @export
#'
#' @examples
#' \dontrun{
#' available_features ()
#' }
available_features <- function () {

    url_ftrs <- "https://wiki.openstreetmap.org/wiki/Map_Features"

    if (curl::has_internet ()) {

        req <- httr2::request (url_ftrs)
        resp <- httr2::req_perform (req)
        pg <- httr2::resp_body_html (resp)

        keys <- xml2::xml_attr (
            rvest::html_elements (pg, "a[href^='/wiki/Key']"), # nolint
            "href"
        ) %>%
            strsplit ("/wiki/Key:") %>%
            unlist ()
        keys [keys != ""] %>%
            sort () %>%
            unique ()
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
#' @references <https://wiki.openstreetmap.org/wiki/Map_Features>
#'
#' @family osminfo
#' @export
#'
#' @examples
#' \dontrun{
#' available_tags ("aerialway")
#' }
available_tags <- function (feature) {
    url_ftrs <- "https://wiki.openstreetmap.org/wiki/Map_Features"

    ret <- NULL
    if (curl::has_internet ()) {

        if (missing (feature)) {
            stop ("Please specify feature")
        }

        req <- httr2::request (url_ftrs)
        resp <- httr2::req_perform (req)
        pg <- httr2::resp_body_html (resp)

        tags <- get_all_tags (pg)

        if (!feature %in% tags$Key) {
            stop ("feature [", feature, "] not listed as Key in ",
                url_ftrs,
                call. = FALSE
            )
        }

        ret <- tags [which (tags$Key == feature), ]

    } else {
        message ("No internet connection")
    }
    return (ret)
}

#' Get all Key-Value pairs from wiki webpage
#'
#' @noRd
get_all_tags <- function (pg) {

    tags <- rbind (tags_from_tables (pg), tags_from_taglists (pg))

    tags <- tags [which (!duplicated (tags)), ]
    tags <- tags [which (!tags$Key == "Key"), ]
    # There are a couple of just entries with "Key" values beginning with "[[ <comment>":
    tags <- tags [which (!grepl ("^\\[\\[", tags$Key)), ]

    # Then a non-dplyr group_by and arrange:
    tags <- tags [order (tags$Key), ]
    tags <- lapply (
        split (tags, f = as.factor (tags$Key)),
        function (i) i [order (i$Value), ]
    )
    tags <- do.call (rbind, tags)

    return (tags)
}

#' Get tags from HTML taglist structures (not tables)
#'
#' The wiki page at \url{https://wiki.openstreetmap.org/wiki/Map_Features} now
#' has most data in tables (HTML "td"), but some is still present as older-style
#' "taglist" classes. This function extracts the latter information, to be added
#' to the majority of data extracted from tables.
#' @noRd
tags_from_taglists <- function (pg) {

    taglists <- rvest::html_elements (pg, "div[class='taglist']") %>%
        rvest::html_attr ("data-taginfo-taglist-tags")

    taglists <- lapply (taglists, function (i) {

        temp <- strsplit (i, "=") [[1]]
        res <- NULL

        if (length (temp) == 2) {
            res <- strsplit (temp [2], ",")
            names (res) <- temp [1]
        }

        return (res)
    })

    taglists [vapply (taglists, is.null, logical (1))] <- NULL

    taglists <- lapply (seq_along (taglists), function (i) {
        data.frame (
            Key = rep (names (taglists [[i]]), length (taglists [[i]])),
            Value = unlist (taglists [[i]])
        )
    })

    tags_df <- do.call (rbind, taglists)
    rownames (tags_df) <- NULL

    return (tags_df)
}

#' Get tags from HTML table structures (not taglists)
#'
#' The wiki page at \url{https://wiki.openstreetmap.org/wiki/Map_Features} now
#' has most data in tables (HTML "td"), but some is still present as older-style
#' "taglist" classes. This function extracts the former information, to be added
#' to the small remaining amount of data extracted from taglists.
#' @noRd
tags_from_tables <- function (pg) {

    tables <- rvest::html_table (pg, header = TRUE)
    tables <- lapply (tables, function (i) {
        if (identical (names (i) [1:2], c ("Key", "Value"))) {
            res <- i [, 1:2]
        } else {
            res <- do.call (rbind, strsplit (i [[1]], split = "="))
            res <- data.frame (res)
            names (res) <- c ("Key", "Value")
        }
        return (res)
    })

    tables <- do.call (rbind, tables)

    return (tables)
}
