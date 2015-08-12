#' Tools to Work with the OpenStreetMap (OSM) Overpass API
#'
#' The Overpass API (or OSM3S) is a read-only API that serves up custom
#' selected parts of the OSM map data. It acts as a database over the web:
#' the client sends a query to the API and gets back the data set that
#' corresponds to the query.\cr
#' \cr
#' Unlike the main API, which is optimized for editing, Overpass API is
#' optimized for data consumers that need a few elements within a glimpse
#' or up to roughly 100 million elements in some minutes, both selected by
#' search criteria like e.g. location, type of objects, tag properties,
#' proximity, or combinations of them. It acts as a database backend for
#' various services.\cr
#' \cr
#' Overpass API has a powerful query language (language guide, language
#' reference, an IDE) beyond XAPI, but also has a compatibility layer to
#' allow a smooth transition from XAPI.
#'
#' @name overpass
#' @docType package
#' @author Bob Rudis, Robin Lovelace
#' @import fastmatch pbapply sp xml2 httr tidyr
#' @importFrom rvest html html_attr html_nodes
#' @importFrom dplyr %>% select left_join filter arrange bind_rows mutate do group_by distinct data_frame
#' @importFrom utils read.table
NULL


#' overpass exported operators
#'
#' The following functions are imported and then re-exported
#' from the overpass package to enable use of the magrittr/dplyr
#' pipe operator with no additional library calls
#'
#' @name overpass-exports
NULL

#' @importFrom dplyr %>%
#' @name %>%
#' @export
#' @rdname overpass-exports
NULL
