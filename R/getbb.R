#' Convert a named matrix or a named vector (or an unnamed vector) return a string
#'
#' This function converts a bounding box into a string for use in web apis
#' 
#' @param bbox bounding box as matrix or vector. Unnamed vectors will be sorted
#' appropriately and must merely be in the order (x, y, x, y).
#'
#' @export
bbox_to_string <- function(bbox) {

  if (missing (bbox)) stop ("bbox must be provided")
  #if (is.character(bbox)) {
  #  bbox <- tmap::bb (bbox)
  #}
  if (!is.numeric (bbox)) stop ("bbox must be numeric")
  if (length (bbox) < 4) stop ("bbox must contain four elements")
  if (length (bbox) > 4) message ("only the first four elements of bbox used")

  if (inherits(bbox, "matrix")) {
    if (all (rownames (bbox) %in% c("x", "y")    ) &
        all (colnames (bbox) %in% c("min", "max"))) {
      bbox <- c(bbox["x", "min"], bbox["y", "min"], 
                bbox["x", "max"], bbox["y", "max"])
    } else if (all (rownames (bbox) %in% c("coords.x1", "coords.x2")) &
               all (colnames (bbox) %in% c("min", "max"))) {
      bbox <- c (bbox["x", "coords.x1"], bbox["y", "coords.x1"], 
                 bbox["x", "coords.x2"], bbox["y", "coords.x2"])
    }
    bbox <- paste0 (bbox[c(2,1,4,3)], collapse=",")
  } else {
    if (!is.null (names (bbox)) & 
        all (names (bbox) %in% c("left", "bottom", "right", "top"))) {
      bbox <- paste0 (bbox[c ("bottom", "left", "top", "right")], collapse=",")
    } else {
      x <- sort (bbox [c (1, 3)])
      y <- sort (bbox [c (2, 4)])
      bbox <- paste0 (c (y [1], x[1], y [2], x [2]), collapse=",")
    }
  }
  return(bbox)
}

#' Get bounding box for a given place name
#' 
#' Uses online services to convert a text string into a bounding box
#' 
#' @param place_name The name of the place you're searching for
#' @param viewbox The bounds in which you're searching
#' @param format_out Character string indicating output format: matrix (default - see \code{\link{bbox}})
#' or string (see \code{\link{bbox_to_string}})
#' @param base_url Base website from where data is queried
#' @param featuretype The type of OSM feature (settlement is default)
#' @param silent Should the API be printed to screen? FALSE by default
#' @export
#' @examples
#' if(curl::has_internet()){
#'   getbb("Salzburg")
#'   # refine the search to the USA
#'   place_name = "Hereford"
#'   getbb(place_name, silent = FALSE)
#'   bb_usa = getbb("United States")
#'   viewbox = bbox_to_string(bb_usa)
#'   getbb(place_name, viewbox, silent = FALSE) # not working
#' }
#' 
getbb <- function(place_name, viewbox = NULL, format_out = "matrix",
                  base_url = "https://nominatim.openstreetmap.org", featuretype = "settlement",
                  silent = TRUE) {
  
  query <- list(q = place_name,
                viewbox = viewbox,
                format = 'json',
                featuretype = featuretype,
                # bounded = 1,
                limit = 50)
  if(!silent)
    print(httr::modify_url(base_url, query = query))
  res <- httr::GET(base_url, query = query)
  txt <- httr::content(res, as = "text", encoding = "UTF-8")
  obj <- jsonlite::fromJSON(txt)
  
  # Code optionally select more things stored in obj...
  
  bn = as.numeric(obj$boundingbox[[1]])
  bb_mat = matrix(c(bn[3:4], bn[1:2]), nrow = 2, byrow = TRUE)
  dimnames(bb_mat) = list(c("x", "y"), c("min", "max"))
  if(format_out == "matrix") {
    return(bb_mat)
  } else if(format_out == "string") {
    bb_string = osmdata::bbox_to_string(bbox = bb_mat)
    return(bb_string)
  }
}
