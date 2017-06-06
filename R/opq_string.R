#' Convert an overpass query into a text string
#'
#' Convert an osmdata query of class opq to a character string query to
#' be submitted to the overpass API.
#'
#' @param opq An \code{overpass_query} object
#' @return Character string to be submitted to the overpass API
#' 
#' @export
#' @aliases opq_to_string
#'
#' @examples
#' q <- opq ("hampi india")
#' opq_string (q)
opq_string <- function (opq)
{
  features <- paste (opq$features, collapse = '')
  features <- paste0 (sprintf (' node %s (%s);\n', features, opq$bbox),
                      sprintf (' way %s (%s);\n', features, opq$bbox),
                      sprintf (' relation %s (%s);\n\n', features,
                               opq$bbox))
  paste0 (opq$prefix, features, opq$suffix)
}
