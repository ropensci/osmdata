#' osmdata class def
#'
#' @param bbox bounding box
#' @param overpass_call overpass_call
#' @param osm_points \code{sf} Simple Features Collection of points
#' @param osm_lines \code{sf} Simple Features Collection of linestrings
#' @param osm_polygons \code{sf} Simple Features Collection of polygons
#' @param osm_multilines \code{sf} Simple Features Collection of multilinestrings
#' @param osm_multipolygons \code{sf} Simple Features Collection of multipolygons
#' @param timestamp timestamp
#' @param ... other options ignored
#'
#' @note Class constructor should never be used directly, and is only exported
#' to provide access to the print method
#'
#' @export
osmdata <- function (bbox, overpass_call, 
                     osm_points, osm_lines, osm_polygons, 
                     osm_multilines, osm_multipolygons, timestamp, ...) 
{
    if (missing (bbox)) bbox <- NULL
    if (missing (overpass_call)) overpass_call <- NULL
    if (missing (osm_points)) osm_points <- NULL
    if (missing (osm_lines)) osm_lines <- NULL
    if (missing (osm_polygons)) osm_polygons <- NULL
    if (missing (osm_multilines)) osm_multilines <- NULL
    if (missing (osm_multipolygons)) osm_multipolygons <- NULL
    if (missing (timestamp)) timestamp <- NULL
    if (missing (timestamp)) timestamp <- NULL

    obj <- list (
                 bbox = bbox,
                 overpass_call = overpass_call,
                 timestamp = timestamp,
                 osm_points = osm_points,
                 osm_lines = osm_lines,
                 osm_polygons = osm_polygons,
                 osm_multilines = osm_multilines,
                 osm_multipolygons = osm_multipolygons)
    class (obj) <- append (class (obj), "osmdata")
    return (obj)
}


#' @export
print.osmdata <- function (x, ...)
{
    # print meta-data
    if (!all (sapply (x, is.null)))
        message ("Object of class 'osmdata' with:")
    objs <- c ("bbox", "overpass_call", "timestamp")
    prnts <- c (x$bbox, "The call submitted to the overpass API", x$timestamp)
    for (i in 1:3)
        if (!is.null (x [objs [i]]))
        {
            nm <- c (rep (" ", 21 - nchar (objs [i])), "$", objs [i])
            message (nm, " : ", prnts [i])
        }

    # print geometry data
    indx <- which (grepl ("osm", names (x)))

    sf <- any (grep ("sf", sapply (x, class)))
    if (sf)
    {
        for (i in names (x) [indx])
        {
            xi <- x [[i]]
            nm <- c (rep (" ", 21 - nchar (i)), "$", i)
            if (is.null (xi))
                message (nm, " : NULL")
            else if (grepl ("line", i)) # sf "lines" -> "linestrings"
                message (nm, " : 'sf' Simple Features Collection with ",
                         nrow (xi), " ", strsplit (i, "osm_")[[1]][2], "trings")
            else
                message (nm, " : 'sf' Simple Features Collection with ",
                         nrow (xi), " ", strsplit (i, "osm_")[[1]][2])
        }
    } else
    {
        for (i in names (x) [indx])
        {
            xi <- x [[i]]
            nm <- c (rep (" ", 21 - nchar (i)), "$", i)
            if (is.null (xi))
                message (nm, " : NULL")
            else
                message (nm, " : 'sp' Spatial", strsplit (i, "osm_")[[1]][2],
                         "DataFrame with ", nrow (xi), " ", 
                         strsplit (i, "osm_")[[1]][2])
        }
    }
    #invisible (x)
}

