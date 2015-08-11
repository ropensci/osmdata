#' Tools to Work With the OpenStreetMap (OSM) Overpass API
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
#' @import fastmatch pbapply sp xml2 httr jsonlite dplyr tidyr
#' @importFrom utils read.table
NULL
