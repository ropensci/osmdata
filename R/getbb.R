#' Convert a named matrix or a named vector (or an unnamed vector) return a string
#'
#' This function converts a bounding box into a string for use in web apis
#' 
#' @param bbox bounding box as character, matrix or vector. If character,
#' numeric bbox will be extracted with \code{getbb} Unnamed vectors will be
#' sorted appropriately and must merely be in the order (x, y, x, y).
#'
#' @export
#'
#' @examples
#' \dontrun{
#' bbox_to_string (getbb ("hampi india"))
#' }
bbox_to_string <- function(bbox) {

    if (missing (bbox)) stop ("bbox must be provided")

    if (is.character (bbox))
        bbox <- getbb (bbox)

    if (!is.numeric (bbox)) stop ("bbox must be numeric")
    if (length (bbox) < 4) stop ("bbox must contain four elements")
    if (length (bbox) > 4) message ("only the first four elements of bbox used")

    if (inherits(bbox, "matrix")) {
        if (all (c("x", "y") %in% rownames (bbox)) &
            all (c("min", "max") %in% colnames (bbox)))
        {
            bbox <- c(bbox["x", "min"], bbox["y", "min"],
                      bbox["x", "max"], bbox["y", "max"])
        } else if (all (c("coords.x1", "coords.x2") %in% rownames (bbox)) &
                   all (c("min", "max") %in% colnames (bbox)))
        {
            bbox <- c (bbox["coords.x1", "min"], bbox["coords.x2", "min"],
                       bbox["coords.x1", "max"], bbox["coords.x2", "max"])
        } # otherwise just presume (x,y) are rows and (min,max) are cols
        bbox <- paste0 (bbox[c(2, 1, 4, 3)], collapse = ",")
    } else
    {
        if (!is.null (names (bbox)) &
            all (names (bbox) %in% c("left", "bottom", "right", "top")))
        {
            bbox <- paste0 (bbox[c ("bottom", "left", "top", "right")],
                            collapse = ",")
        } else
        {
            x <- sort (bbox [c (1, 3)])
            y <- sort (bbox [c (2, 4)])
            bbox <- paste0 (c (y [1], x[1], y [2], x [2]), collapse = ",")
        }
    }
    return(bbox)
}

#' Get bounding box for a given place name
#' 
#' This function uses the free Nominatim API provided by OpenStreetMap to find
#' the bounding box (bb) associated with place names.
#' 
#' It was inspired by the functions
#' \code{bbox} from the \pkg{sp} package,
#' \code{bb} from the \pkg{tmaptools} package and
#' \code{bb_lookup} from the github package \pkg{nominatim} package,
#' which can be found at \url{https://github.com/hrbrmstr/nominatim}.
#' 
#' See \url{http://wiki.openstreetmap.org/wiki/Nominatim} for details.
#' 
#' @param place_name The name of the place you're searching for
#' @param display_name_contains Text string to match with display_name field
#' returned by \url{http://wiki.openstreetmap.org/wiki/Nominatim}
#' @param viewbox The bounds in which you're searching
#' @param format_out Character string indicating output format: matrix (default),
#' string (see \code{\link{bbox_to_string}}) or data.frame (all 'hits' returned
#' by Nominatim)
#' @param base_url Base website from where data is queried
#' @param featuretype The type of OSM feature (settlement is default)
#' @param limit How many results should the API return?
#' @param key The API key to use for services that require it
#' @param silent Should the API be printed to screen? FALSE by default
#'
#' @return Numeric bounding box as min and max of latitude and longitude
#' 
#' @export
#' 
#' @examples
#' \dontrun{
#' getbb("Salzburg")
#' place_name <- "Hereford"
#' getbb(place_name, silent = FALSE)
#' # return bb whose display_name contain text string "United States"
#' getbb(place_name, display_name_contains = "United States", silent = FALSE)
#' # top 3 matches as data frame
#' getbb(place_name, format_out = "data.frame", limit = 3)
#' # using an alternative service (locationiq requires an API key)
#' key <- Sys.getenv("LOCATIONIQ") # add LOCATIONIQ=type_your_api_key_here to .Renviron
#' if(nchar(key) ==  32) {
#'   getbb(place_name, base_url = "http://locationiq.org/v1/search.php", key = key)
#' }
#' }
getbb <- function(place_name,
                  display_name_contains = NULL,
                  viewbox = NULL,
                  format_out = "matrix",
                  base_url = "https://nominatim.openstreetmap.org",
                  featuretype = "settlement",
                  limit = 10,
                  key = NULL,
                  silent = TRUE) {

    query <- list(q = place_name,
                  viewbox = viewbox,
                  format = 'json',
                  featuretype = featuretype,
                  key = key,
                  # bounded = 1, # seemingly not working
                  limit = limit)
    
    q_url = httr::modify_url(base_url, query = query)

    if (!silent)
        print(q_url)

    res <- httr::GET (q_url)
    #res <- httr::POST(base_url, query = query, httr::timeout (100))
    txt <- httr::content(res, as = "text", encoding = "UTF-8",
                         type = "application/xml")
    obj <- tryCatch(expr = {
      jsonlite::fromJSON(txt)
    }, error = function(cond){
        message(paste0("Nominatim did respond as expected (e.g. due to excessive use of their api).\nPlease try again or use a different base_url\nThe url that failed was:\n", q_url))
    }
    )

    # Code optionally select more things stored in obj...
    if (!is.null(display_name_contains))
        obj <- obj[grepl(display_name_contains, obj$display_name), ]

    if (format_out == "data.frame")
        return(obj)

    bn <- as.numeric(obj$boundingbox[[1]])
    bb_mat <- matrix(c(bn[3:4], bn[1:2]), nrow = 2, byrow = TRUE)
    dimnames(bb_mat) <- list(c("x", "y"), c("min", "max"))
    if (format_out == "matrix")
    {
        return(bb_mat)
    } else if (format_out == "string")
    {
        bb_string <- osmdata::bbox_to_string(bbox = bb_mat)
        return(bb_string)
    }
}
