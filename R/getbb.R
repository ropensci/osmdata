#' Get bounding box for a given place name
#' 
#' Uses online services to convert a text string into a bounding box
#' 
#' @param place_name The name of the place you're searching for
#' @param viewbox The bounds in which you're searching
#' @param format_out The format of the output (a bbox matrix, as used by sp, by default)
#' @param base_url Base website from where data is queried
#' @param featuretype The type of OSM feature (settlement is default)
#' @param silent Should the API be printed to screen? FALSE by default
#' @export
#' @examples
#' if(curl::has_internet()){
#'   getbb("Salzburg")
#'   # refine the search to the USA
#'   place_name = "Hereford"
#'   getbb(place_name)
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
                limit=50)
  if(!silent)
    print(httr::modify_url(base_url, query = query))
  res <- httr::GET(base_url, query = query)
  txt <- httr::content(res, as = "text", encoding = "UTF-8")
  obj <- jsonlite::fromJSON(txt)
  
  # Code optionally select more things stored in obj...
  
  bn = as.numeric(obj$boundingbox[[1]])
  bb_mat = matrix(c(bn[3:4], bn[1:2]), nrow = 2, byrow = TRUE)
  dimnames(bb_mat) = list(c("x", "y"), c("min", "max"))
  bb_string = osmdata::bbox_to_string(bbox = bb_mat)
  if(format_out == "matrix") {
    return(bb_mat)
  } else {
    return(bb_string)
  }
}