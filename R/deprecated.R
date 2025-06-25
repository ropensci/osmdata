#' Deprecated functions and arguments in osmdata
#'
#' These functions and arguments have been deprecated and will be removed in a future release.
#'
#' @section Deprecated arguments:
#' \describe{
#'   \item{`nodes_only = TRUE` (in [`opq()`])}{
#'     This argument has been replaced by `osm_types = "node"`.
#'     Since version 0.3, using `nodes_only` will produce a deprecation warning.
#'   }
#' }
#'
#' @section Deprecated functions:
#' \describe{
#'   \item{`osmdata_sp()`}{
#'     Please use [`osmdata_sf()`] or [`osmdata_sc()`] instead.
#'     Since version 0.3, using [`osmdata_sp()`] will produce a deprecation warning.
#'   }
#' }
#'
#' @name osmdata-deprecated
#' @keywords internal
NULL
