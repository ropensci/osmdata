get_geoms <- function (dat, id)
{
    indx <- which (grepl ('osm_', names (dat)))
    where <- indx [which (sapply (dat [indx], function (i) 
                                  any (id %in% rownames (i))))]
    lapply (where, function (i)
            dat [[i]] [which (rownames (dat [[i]]) %in% id),]$geometry)
}

get_point_ids <- function (x)
{
    pts <- NULL
    if (is (x [[1]], 'MULTIPOLYGON'))
        pts <- lapply (x, function (i) do.call (rbind, i [[1]])) [[1]]
    else if (is (x [[1]], 'MULTILINESTRING'))
        pts <- lapply (x, function (i) do.call (rbind, i)) [[1]]
    else if (is (x [[1]], 'POLYGON'))
        pts <- do.call (rbind, x [[1]])
    else if (is (x [[1]], 'LINESTRING'))
        pts <- do.call (rbind, x)

    ids <- as.character (rownames (pts))

    return (unique (ids))
}

get_line_ids <- function (x, dat, id)
{
    ids <- NULL
    if (class (x) [1] %in% 
        c ('sfc_POINT', 'sfc_LINESTRING', 'sfc_POLYGON'))
    {
        if (is (x, 'sfc_POINT'))
            pts <- id
        else if (is (x, 'sfc_LINESTRING'))
            pts <- unique (rownames (x [[1]]))
        else # polygon
            pts <- unique (rownames (x [[1]] [[1]]))
        # find all intersecting lines
        indx <- which (sapply (dat$osm_lines$geometry, function (i) 
                               any (pts %in% rownames (i))))
        ids <- names (dat$osm_lines$geometry) [indx]
    } else 
    {
        if (is (x, 'sfc_MULTIPOLYGON'))
            x <- x [[1]]
        ids <- names (x [[1]])
        if (is (x, 'MULTIPOLYGON'))
        {
            ids <- unlist (sapply (ids, function (i) strsplit (i, '-')))
            names (ids) <- NULL
        }
    }
    return (ids)
}

get_polygon_ids <- function (x, dat, id)
{
    ids <- NULL
    if (class (x) [1] %in% c ('sfc_POINT', 'sfc_LINESTRING', 'sfc_POLYGON'))
    {
        if (is (x, 'sfc_POINT'))
            pts <- id
        else if (is (x, 'sfc_LINESTRING'))
            pts <- unique (rownames (x [[1]]))
        else # polygon
        {
            pts <- unlist (lapply (x, function (i) rownames (i [[1]])))
            names (pts) <- NULL
        }
        # find all intersecting polygons
        indx <- which (sapply (dat$osm_polygons$geometry, function (i) 
                                   any (pts %in% rownames (i[[1]]) )))
        ids <- names (dat$osm_polygons$geometry) [indx]
    } else 
    {
        if (is (x, 'sfc_MULTIPOLYGON'))
            x <- x [[1]]
        ids <- names (x [[1]])
        if (is (x, 'MULTIPOLYGON'))
        {
            ids <- unlist (sapply (ids, function (i) strsplit (i, '-')))
            names (ids) <- NULL
        }
    }
    return (ids)
}


#' Extract all \code{osm_points} from an osmdata object
#'
#' @param dat An object of class \code{osmdata}
#' @param id OSM identification of one or more objects for which points are to
#' be extracted
#' @return An \code{sf} Simple Features Collection of points 
#'
#' @export
osm_points <- function(dat, id) {
    if (missing (dat))
        stop ('osm_points can not be extracted without data')
    if (!is (dat, 'osmdata'))
        stop ('dat must be of class osmdata')
    if (missing (id))
        stop ('id must be given to extract points')
    if (!(is.character (id) | is.numeric (id)))
        stop ('id must be of class character or numeric')

    if (!is.character (id))
        id <- as.character (id)

    x <- get_geoms (dat, id)
    ids <- lapply (x, function (i) get_point_ids (i))
    ids <- unique (unlist (ids))

    dat$osm_points [which (rownames (dat$osm_points) %in% ids), ]
}

#' Extract all \code{osm_lines} from an osmdata object
#'
#' If \code{id} is of a point object, \code{osm_lines} will return all lines
#' containing that point. If \code{id} is of a line or polygon object,
#' \code{osm_lines} will return all lines which intersect the given line or
#' polygon.
#'
#' @param dat An object of class \code{osmdata}
#' @param id OSM identification of one or more objects for which lines are to be
#' extracted
#' @return An \code{sf} Simple Features Collection of linestrings 
#'
#' @export
osm_lines <- function(dat, id) {
    if (missing (dat))
        stop ('osm_lines can not be extracted without data')
    if (!is (dat, 'osmdata'))
        stop ('dat must be of class osmdata')
    if (missing (id))
        stop ('id must be given to extract lines')
    if (!(is.character (id) | is.numeric (id)))
        stop ('id must be of class character or numeric')

    if (!is.character (id))
        id <- as.character (id)

    x <- get_geoms (dat, id)
    ids <- lapply (x, function (i) get_line_ids (i, dat, id))

    dat$osm_lines [which (rownames (dat$osm_lines) %in% unlist (ids)), ]
}


#' Extract all \code{osm_polygons} from an osmdata object
#'
#' If \code{id} is of a point object, \code{osm_polygons} will return all
#' polygons containing that point. If \code{id} is of a line or polygon object,
#' \code{osm_polygons} will return all polygons which intersect the given line
#' or polygon.
#'
#'
#' @param dat An object of class \code{osmdata}
#' @param id OSM identification of one or more objects for which polygons are to
#' be extracted
#' @return An \code{sf} Simple Features Collection of polygons 
#'
#' @export
osm_polygons <- function(dat, id) {
    if (missing (dat))
        stop ('osm_polygons can not be extracted without data')
    if (!is (dat, 'osmdata'))
        stop ('dat must be of class osmdata')
    if (missing (id))
        stop ('id must be given to extract polygons')
    if (!(is.character (id) | is.numeric (id)))
        stop ('id must be of class character or numeric')

    if (!is.character (id))
        id <- as.character (id)

    x <- get_geoms (dat, id)
    ids <- lapply (x, function (i) get_polygon_ids (i, dat, id))

    dat$osm_polygons [which (rownames (dat$osm_polygons) %in% unlist (ids)), ]
}


#' Extract all \code{osm_multilines} from an osmdata object
#'
#' \code{id} must be of an \code{osm_point} or \code{osm_line} object (and can
#' not be the \code{id} of an \code{osm_polygon} object because multilines by
#' definition contain no polygons.  \code{osm_multilines} returns any multiline
#' object(s) which contain the object specified by \code{id}.
#'
#'
#' @param dat An object of class \code{osmdata}
#' @param id OSM identification of one of more objects for which multilines are
#' to be extracted
#' @return An \code{sf} Simple Features Collection of multilines 
#'
#' @export
osm_multilines <- function(dat, id) {
    if (missing (dat))
        stop ('osm_multilines can not be extracted without data')
    if (!is (dat, 'osmdata'))
        stop ('dat must be of class osmdata')
    if (missing (id))
        stop ('id must be given to extract multilines')
    if (!(is.character (id) | is.numeric (id)))
        stop ('id must be of class character or numeric')

    if (!is.character (id))
        id <- as.character (id)

    x <- get_geoms (dat, id)

    if (is (x, 'sfc_POLYGON'))
        stop ('multilines do not contain polygons')
    else if (any (grepl ('MULTI', class (x))))
        stop ('osm_multilines id must be of a point or line object')

    indx <- lapply (x, function (i)
                    {
                        ret <- NULL
                        if (is (i, 'sfc_POINT'))
                        { 
                            # find all lines containing that point
                            ret <- which (sapply (dat$osm_lines$geometry, 
                                                   function (j) 
                                                   any (rownames (j) %in% id)))
                            ids <- names (ret)
                            # then find all multilines containing those lines
                            ret <- which (sapply (dat$osm_multilines$geometry, 
                                                  function (j) 
                                                   any (names (j) %in% ids)))
                        } else if (is (i, 'sfc_LINESTRING'))
                            ret <- which (sapply (dat$osm_multilines$geometry, 
                                                  function (j) 
                                                   any (names (j) %in% id)))
                        return (ret)
                    })

    dat$osm_multilines [indx, ]
}

#' Extract all \code{osm_multipolygons} from an osmdata object
#'
#' \code{id} must be of an \code{osm_point}, \code{osm_line}, or
#' \code{osm_polygon} object. \code{osm_multipolygons} returns any multipolygon
#' object(s) which contain the object specified by \code{id}.
#'
#'
#' @param dat An object of class \code{osmdata}
#' @param id OSM identification of one or more objects for which multipolygons
#' are to be extracted
#' @return An \code{sf} Simple Features Collection of multipolygons 
#'
#' @export
osm_multipolygons <- function(dat, id) {
    if (missing (dat))
        stop ('osm_multipolygons can not be extracted without data')
    if (!is (dat, 'osmdata'))
        stop ('dat must be of class osmdata')
    if (missing (id))
        stop ('id must be given to extract multipolygons')
    if (!(is.character (id) | is.numeric (id)))
        stop ('id must be of class character or numeric')

    if (!is.character (id))
        id <- as.character (id)

    x <- get_geoms (dat, id)

    if (any (grepl ('MULTI', class (x))))
        stop ('osm_multipolygons id must be of a point, line, or polygon object')

    indx <- lapply (x, function (i)
                    {
                        ret <- NULL
                        if (is (i, 'sfc_POINT'))
                        { 
                            # find all lines containing that point
                            ret <- which (sapply (dat$osm_lines$geometry, 
                                                  function (j) 
                                                   any (rownames (j) %in% id)))
                            ids <- names (ret)
                            ret <- which (sapply (dat$osm_polygons$geometry, 
                                                  function (j) 
                                                      any (rownames (j [[1]]) 
                                                           %in% id)))
                            ids <- c (ids, names (ret))
                            # then find all multipolygons containing those lines
                            ret <- which (sapply (dat$osm_multipolygons$geometry, 
                                      function (j) 
                                      {
                                          ids_i <- unlist (sapply (names (j [[1]]), 
                                                    function (k) strsplit (k, '-')))
                                           names (ids_i) <- NULL
                                           any (ids_i %in% ids)
                                       }))
                        } else if (class (i) [1] %in% 
                                   c ('sfc_LINESTRING', 'sfc_POLYGON'))
                            ret <- which (sapply (dat$osm_multipolygons$geometry, 
                                                  function (j) 
                                                      any (names (j [[1]]) %in% id)))
                        return (ret)
                    })

    dat$osm_multipolygons [unlist (indx), ]
}

