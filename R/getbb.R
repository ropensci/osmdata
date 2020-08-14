#' Convert a named matrix or a named or unnamed vector to a string
#'
#' This function converts a bounding box into a string for use in web apis
#'
#' @param bbox bounding box as character, matrix or vector.
#' If character, the bbox will be found (geocoded) and extracted with
#' \link{getbb}. Unnamed vectors will be sorted appropriately and must merely be
#' in the order (x, y, x, y).
#'
#' @return A character string representing min x, min y, max x, and max y
#' bounds. For example: \code{"15.3152361,76.4406446,15.3552361,76.4806446"} is
#' the bounding box for Hampi, India.
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

    if (is.list (bbox))
        bbox <- bb_poly_to_mat (bbox)

    if (!is.numeric (bbox)) stop ("bbox must be numeric")

    if (inherits(bbox, "matrix"))
    {
        if (nrow (bbox) > 2)
        {
            bbox <- apply (bbox, 2, range)
        }

        if (all (c("x", "y") %in% tolower (rownames (bbox))) &
            all (c("min", "max") %in% tolower (colnames (bbox))))
        {
            bbox <- c(bbox["y", "min"], bbox["x", "min"],
                      bbox["y", "max"], bbox["x", "max"])
        } else if (all (c("coords.x1", "coords.x2") %in% rownames (bbox)) &
                   all (c("min", "max") %in% colnames (bbox)))
        {
            bbox <- c (bbox["coords.x2", "min"], bbox["coords.x1", "min"],
                       bbox["coords.x2", "max"], bbox["coords.x1", "max"])
        } else
        {
            # otherwise just presume (x,y) are columns and order the rows
            bbox <- c (min (bbox [, 2]), min (bbox [, 1]),
                       max (bbox [, 2]), max (bbox [, 1]))
        }
    } else
    {
        if (length (bbox) < 4)
            stop ("bbox must contain four elements")
        else if (length (bbox) > 4)
            message ("only the first four elements of bbox used")

        if (!is.null (names (bbox)) &
            all (names (bbox) %in% c("left", "bottom", "right", "top")))
        {
            bbox <- bbox[c ("bottom", "left", "top", "right")]
        } else
        {
            x <- sort (bbox [c (1, 3)])
            y <- sort (bbox [c (2, 4)])
            bbox <- c (y [1], x[1], y [2], x [2])
        }
    }
    return (paste0 (bbox, collapse = ","))
}

#' Get bounding box for a given place name
#'
#' This function uses the free Nominatim API provided by OpenStreetMap to find
#' the bounding box (bb) associated with place names.
#'
#' It was inspired by the functions
#' `bbox` from the \pkg{sp} package,
#' `bb` from the \pkg{tmaptools} package and
#' `bb_lookup` from the github package \pkg{nominatim} package,
#' which can be found at <https://github.com/hrbrmstr/nominatim>.
#'
#' See <https://wiki.openstreetmap.org/wiki/Nominatim> for details.
#'
#' @param place_name The name of the place you're searching for
#' @param display_name_contains Text string to match with display_name field
#' returned by <https://wiki.openstreetmap.org/wiki/Nominatim>
#' @param viewbox The bounds in which you're searching
#' @param format_out Character string indicating output format: matrix
#' (default), string (see [bbox_to_string()]), data.frame (all 'hits' returned
#' by Nominatim), sf_polygon (for polygons that work with the sf package) or
#' polygon (full polygonal bounding boxes for each match).
#' @param base_url Base website from where data is queried
#' @param featuretype The type of OSM feature (settlement is default; see Note)
#' @param limit How many results should the API return?
#' @param key The API key to use for services that require it
#' @param silent Should the API be printed to screen? TRUE by default
#'
#' @return Defaults to a matrix in the form:
#' \code{
#'   min   max
#' x ...   ...
#' y ...   ...
#' }
#' If `format_out = "polygon"`, one or more two-columns matrices of polygonal
#' longitude-latitude points. Where multiple `place_name` occurrences are found
#' within `nominatim`, each item of the list of coordinates may itself contain
#' multiple coordinate matrices where multiple exact matches exist. If one one
#' exact match exists with potentially multiple polygonal boundaries (for
#' example, "london uk" is an exact match, but can mean either greater London or
#' the City of London), only the first is returned. See examples below for
#' illustration.
#'
#' @note Specific values of `featuretype` include "street", "city",
#" "county", "state", and "country" (see
#' <https://wiki.openstreetmap.org/wiki/Nominatim> for details). The default
#' `featuretype = "settlement"` combines results from all intermediate
#' levels below "country" and above "streets". If the bounding box or polygon of
#' a city is desired, better results will usually be obtained with
#' `featuretype = "city"`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' getbb("Salzburg")
#' # select based on display_name, print query url
#' getbb("Hereford", display_name_contains = "USA", silent = FALSE)
#' # top 3 matches as data frame
#' getbb("Hereford", format_out = "data.frame", limit = 3)
#' # Examples of polygonal boundaries
#' bb <- getbb ("london uk", format_out = "polygon") # single match
#' dim(bb[[1]][[1]]) # matrix of longitude/latitude pairs
#' bb_sf = getbb("kathmandu", format_out = "sf_polygon")
#' # sf:::plot.sf(bb_sf) # can be plotted if sf is installed
#' getbb("london", format_out = "sf_polygon")
#' getbb("accra", format_out = "sf_polygon") # rectangular bb
#' # Using an alternative service (locationiq requires an API key)
#' # add LOCATIONIQ=type_your_api_key_here to .Renviron:
#' key <- Sys.getenv("LOCATIONIQ")
#' if(nchar(key) ==  32) {
#'   getbb(place_name,
#'         base_url = "https://locationiq.org/v1/search.php",
#'         key = key)
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
    is_polygon <- grepl("polygon", format_out)
    query <- list (q = place_name)
    featuretype <- tolower (featuretype)

    query <- c (query, list (featuretype = featuretype))

    if (is_polygon)
        query <- c (query, list (polygon_text = 1))

    query <- c (query, list (viewbox = viewbox,
                             format = 'json',
                             key = key,
                             # bounded = 1, # seemingly not working
                             limit = limit))

    q_url <- httr::modify_url(base_url, query = query)

    if (!silent)
        print(q_url)

    #res <- httr::POST(base_url, query = query, httr::timeout (100))
    res <- httr::RETRY("POST", q_url, times = 10)
    txt <- httr::content(res, as = "text", encoding = "UTF-8",
                         type = "application/xml")
    obj <- tryCatch(expr =
                    {
                        jsonlite::fromJSON(txt)
                    },
                    error = function(cond)
                    {
            # nocov start
            message(paste0("Nominatim did respond as expected ",
                           "(e.g. due to excessive use of their api).\n",
                           "Please try again or use a different base_url\n",
                           "The url that failed was:\n", q_url))
            # nocov end
                    }
    )

    # Code optionally select more things stored in obj...
    if (!is.null(display_name_contains))
    {
        # nocov start
        obj <- obj[grepl(display_name_contains, obj$display_name), ]
        if (nrow (obj) == 0)
            stop ("No locations include display name ", display_name_contains)
        # nocov end
    }

    if (format_out == "data.frame") {
      return(obj)
    }

    bn <- as.numeric(obj$boundingbox[[1]])
    bb_mat <- matrix(c(bn[3:4], bn[1:2]), nrow = 2, byrow = TRUE)
    dimnames(bb_mat) <- list(c("x", "y"), c("min", "max"))
    if (format_out == "matrix")
        ret <- bb_mat
    else if (format_out == "string")
        ret <- bbox_to_string (bbox = bb_mat)
    else if (is_polygon)
    {
        . <- NULL # suppress R CMD check note
        indx_multi <- grep ("MULTIPOLYGON", obj$geotext)
        gt_p <- gt_mp <- NULL
        # nocov start
        # TODO: Test this
        if (length (indx_multi) > 0)
        {
            gt_mp <- obj$geotext [indx_multi] %>%
                gsub ("MULTIPOLYGON\\(\\(\\(", "", .) %>%
                gsub ("\\)\\)\\)", "", .) %>%
                strsplit (split = ',')
            indx_na <- rev (which (is.na (gt_mp)))
            for (i in indx_na)
                gt_mp [[i]] <- NULL
        }
        # nocov end

        indx <- which (!(seq (nrow(obj)) %in% indx_multi))
        gt_p <- obj$geotext [indx] %>%
            gsub ("POLYGON\\(\\(", "", .) %>%
            gsub ("\\)\\)", "", .) %>%
            strsplit (split = ',')
        indx_na <- rev (which (is.na (gt_p)))
        for (i in indx_na)
            gt_p [[i]] <- NULL

        # points and linestrings may be present in result, and will be prepended
        # by sf-standard prefixes, while (multi)polygons will have been stripped
        # to numeric values only.
        # TDOD: Do the following lines need to be repeated for _mp?
        indx <- which (vapply (gt_p, function (i)
                               substring (i [1], 1, 1) %in% c ("L", "P"), logical (1)))
        if (length (indx) > 0)
            gt_p <- gt_p [-indx]

        if (length (gt_p) > 0)
            gt_p <- lapply (gt_p, function (i) get1bdypoly (i))
        # Extract all multipolygon components (see issue #195)
        if (length (gt_mp) > 0)
            gt_mp <- lapply (gt_mp, function (i) get1bdypoly (i))

        gt <- c (gt_p, gt_mp)
        # multipolys below are not strict SF MULTIPOLYGONs, rather just cases
        # where nominatim returns lists of multiple items
        if (length (gt) == 0)
        {
            message ('No polygonal boundary for ', place_name)
            ret <- bb_mat
        } else if (length (gt) == 1)
        {
                ret <- gt [[1]]
        } else
        {
            ret <- gt
        }
    } else
    {
        stop (paste0 ('format_out not recognised; please specify one of ',
                      '[data.frame, matrix, string, polygon]'))
    }

    if (format_out == "sf_polygon") {
        if (!is.null (gt_p))
            gt_p <- lapply (gt_p, function (i)
                            mat2sf_poly (i, pname = place_name))
        if (!is.null (gt_mp))
            gt_mp <- lapply (gt_mp, function (i)
                             mat2sf_multipoly (list (i), mpname = place_name))

        if (is.null (gt_p) & is.null (gt_mp))
            stop ("Query returned no polygons")
        else if (is.null (gt_mp))
            ret <- do.call (rbind, gt_p)
        else if (is.null (gt_p))
            ret <- do.call (rbind, gt_mp)
        else
            ret <- list ("polygon" = do.call (rbind, gt_p),
                         "multipolygon" = do.call (rbind, gt_mp))
    }

    return (ret)
}

#' get1bdypoly
#'
#' Split lists of multiple char POLYGON objects returned by nominatim into lists
#' of coordinate matrices
#'
#' @param p One polygon returned by nominatim
#'
#' @return Equivalent list of coordinate matrices
#'
#' @noRd
get1bdypoly <- function (p)
{
    rm_bracket <- function (i)
    {
        vapply (i, function (j) gsub ("\\)", "", j),
                character (1), USE.NAMES = FALSE)
    }

    # remove all opening brackets:
    p <- vapply (p, function (j) gsub ("\\(", "", j),
                 character (1), USE.NAMES = FALSE)

    ret <- list ()
    i <- grep ("\\)", p)
    while (length (i) > 0)
    {
        ret [[length (ret) + 1]] <- rm_bracket (p [1:i [1]])
        p <- p [(i [1] + 1):length (p)]
        i <- grep ("\\)", p)
    }
    ret [[length (ret) + 1]] <- rm_bracket (p)

    ret <- lapply (ret, function (i)
                   apply (do.call (rbind, strsplit (i, split = ' ')),
                          2, as.numeric))
    if (length (ret) == 1)
        ret <- ret [[1]]

    return (ret)
}

#' convert a matrix to an sf polygon
#'
#' @param mat A matrix
#' @param pname The name of the polygon
#'
#' @return A list that can be converted into a simple features geometry
#' @noRd
mat2sf_poly <- function (mat, pname)
{
  if (nrow(mat) == 2) {
    x <- c(mat[1, 1], mat[1, 2], mat[1, 2], mat[1, 1], mat[1, 1])
    y <- c(mat[2, 2], mat[2, 2], mat[2, 1], mat[2, 1], mat[2, 2])
    mat <- cbind(x, y)
  }
  mat_sf <- list (mat)
  class (mat_sf) <- c ("XY", "POLYGON", "sfg")
  mat_sf <- list (mat_sf)
  attr (mat_sf, "class") <- c ("sfc_POLYGON", "sfc")
  attr (mat_sf, "precision") <- 0
  bb <- as.vector (t (apply (mat, 2, range)))
  names (bb) <- c ("xmin", "ymin", "xmax", "ymax")
  class (bb) <- "bbox"
  attr (mat_sf, "bbox") <- bb
  crs <- list (epsg = 4326L,
               proj4string = "+proj=longlat +datum=WGS84 +no_defs")
  class (crs) <- "crs"
  attr (mat_sf, "crs") <- crs
  attr (mat_sf, "n_empty") <- 0L
  mat_sf <- make_sf (mat_sf)
  names (mat_sf) <- "geometry"
  attr (mat_sf, "sf_column") <- "geometry"
  return (mat_sf)
}

#' convert a list of matrices to an sf mulipolygon
#'
#' @param x A list of matrices
#' @param mpname The name of the multipolygon
#'
#' @return A list that can be converted into a simple features geometry
#' @noRd
mat2sf_multipoly <- function (x, mpname)
{
    # get bbox from matrices
    bb <- as.vector (t (apply (do.call (rbind, x [[1]]), 2, range)))
    names (bb) <- c ("xmin", "ymin", "xmax", "ymax")
    class (bb) <- "bbox"

    class (x) <- c ("XY", "MULTIPOLYGON", "sfg")
    xsf <- list (x)
    attr (xsf, "class") <- c ("sfc_MULTIPOLYGON", "sfc")
    attr (xsf, "precision") <- 0
    attr (xsf, "bbox") <- bb
    crs <- list (epsg = 4326L,
                 proj4string = "+proj=longlat +datum=WGS84 +no_defs")
    class (crs) <- "crs"
    attr (xsf, "crs") <- crs
    attr (xsf, "n_empty") <- 0L
    xsf <- make_sf (xsf)
    names (xsf) <- "geometry"
    attr (xsf, "sf_column") <- "geometry"
    return (xsf)
}
