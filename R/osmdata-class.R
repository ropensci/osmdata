#' osmdata class def
#'
#' @param bbox bounding box
#' @param overpass_call overpass_call
#' @param osm_points OSM nodes as \code{sf} Simple Features Collection of points
#'                   or \code{sp} SpatialPointsDataFrame
#' @param osm_lines OSM ways \code{sf} Simple Features Collection of linestrings
#'                  or \code{sp} SpatialLinesDataFrame
#' @param osm_polygons OSM ways as \code{sf} Simple Features Collection of
#'                     polygons or \code{sp} SpatialPolygonsDataFrame
#' @param osm_multilines OSM relations as \code{sf} Simple Features Collection
#'                       of multilinestrings or \code{sp} SpatialLinesDataFrame
#' @param osm_multipolygons OSM relations as \code{sf} Simple Features
#'                          Collection of multipolygons or \code{sp}
#'                          SpatialPolygonsDataFrame 
#' @param timestamp timestamp of OSM query
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
    msg <- NULL
    # print meta-data
    if (!all (sapply (x, is.null)))
        msg <- "Object of class 'osmdata' with:\n"

    msg <- c (msg, c (rep (' ', 17), '$bbox : ', x$bbox, '\n'))

    objs <- c ("overpass_call", "timestamp")
    prnts <- c ("The call submitted to the overpass API", x$timestamp)
    for (i in seq (objs))
        if (!is.null (x [objs [i]]))
        {
            nm <- c (rep (" ", 21 - nchar (objs [i])), "$", objs [i])
            msg <- c (msg, nm, ' : ', prnts [i], '\n')
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
                msg <- c (msg, nm, ' : NULL\n')
            else if (grepl ("line", i)) # sf "lines" -> "linestrings"
                msg <- c (msg, nm, 
                               " : 'sf' Simple Features Collection with ",
                               nrow (xi), ' ', strsplit (i, 'osm_')[[1]][2], 
                               'trings\n')
            else
                msg <- c (msg, nm, 
                               " : 'sf' Simple Features Collection with ",
                               nrow (xi), ' ', strsplit (i, 'osm_')[[1]][2], '\n')
        }
    } else
    {
        for (i in names (x) [indx])
        {
            xi <- x [[i]]
            nm <- c (rep (" ", 21 - nchar (i)), "$", i)
            if (is.null (xi))
                msg <- c (msg, nm, ' : NULL', '\n')
            else
                msg <- c (msg, nm, " : 'sp' Spatial", 
                               strsplit (i, 'osm_')[[1]][2], 'DataFrame with ',
                               nrow (xi), ' ', strsplit (i, 'osm_')[[1]][2],
                               '\n')
        }
    }

    message (msg)
    #invisible (x)
}

