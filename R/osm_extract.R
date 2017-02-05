#' Extract all \code{osm_points} from an osmdata object
#'
#' @param dat An object of class \code{osmdata}
#' @param id OMS identification of object for which points are to be extracted
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

    indx <- which (grepl ('osm_', names (dat)))
    where <- indx [which (sapply (dat [indx], function (i) id %in% rownames (i)))]
    x <- dat [[where]] [which (rownames (dat [[where]]) == id),]$geometry

    if (is (x, 'sfc_MULTIPOLYGON'))
        x <- x [[1]]
    if (is (x, 'sfc_LINESTRING'))
        ids <- unique (rownames (x [[1]]))
    else
        ids <- unique (rownames (do.call (rbind, x [[1]])))

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
#' @param id OMS identification of object for which lines are to be extracted
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

    indx <- which (grepl ('osm_', names (dat)))
    where <- indx [which (sapply (dat [indx], function (i) id %in% rownames (i)))]
    x <- dat [[where]] [which (rownames (dat [[where]]) == id),]$geometry

    if (class (x) [1] %in% c ('sfc_POINT', 'sfc_LINESTRING', 'sfc_POLYGON'))
    {
        if (is (x, 'sfc_POINT'))
            pts <- id
        else if (is (x, 'sfc_LINESTRING'))
            pts <- unique (rownames (x [[1]]))
        else # polygon
            pts <- unique (rownames (x [[1]] [[1]]))
        # find all intersecting lines
        indx <- which (sapply (dat$osm_lines$geometry, function (i) any (pts %in% rownames (i))))
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

    dat$osm_lines [which (rownames (dat$osm_lines) %in% ids), ]
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
#' @param id OMS identification of object for which polygons are to be extracted
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

    indx <- which (grepl ('osm_', names (dat)))
    where <- indx [which (sapply (dat [indx], function (i) id %in% rownames (i)))]
    x <- dat [[where]] [which (rownames (dat [[where]]) == id),]$geometry

    if (class (x) [1] %in% c ('sfc_POINT', 'sfc_LINESTRING', 'sfc_POLYGON'))
    {
        if (is (x, 'sfc_POINT'))
            pts <- id
        else if (is (x, 'sfc_LINESTRING'))
            pts <- unique (rownames (x [[1]]))
        else # polygon
            pts <- unique (rownames (x [[1]] [[1]]))
        # find all intersecting polygons
        indx <- which (sapply (dat$osm_polygons$geometry, function (i) any (pts %in% rownames (i))))
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

    dat$osm_polygons [which (rownames (dat$osm_polygons) %in% ids), ]
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
#' @param id OMS identification of object for which multilines are to be extracted
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

    indx <- which (grepl ('osm_', names (dat)))
    where <- indx [which (sapply (dat [indx], function (i) id %in% rownames (i)))]
    x <- dat [[where]] [which (rownames (dat [[where]]) == id),]$geometry

    if (is (x, 'sfc_POLYGON'))
        stop ('multilines do not contain polygons')
    else if (any (grepl ('MULTI', class (x))))
        stop ('osm_multilines id must be of a point or line object')

    if (is (x, 'sfc_POINT'))
    { 
        # find all lines containing that point
        indx <- which (sapply (dat$osm_lines$geometry, function (i) 
                               any (rownames (i) %in% id)))
        ids <- names (indx)
        # then find all multilines containing those lines
        indx <- which (sapply (dat$osm_multilines$geometry, function (i) 
                               any (names (i) %in% ids)))
    } else if (is (x, 'sfc_LINESTRING'))
        indx <- which (sapply (dat$osm_multilines$geometry, function (i) 
                               any (names (i) %in% id)))

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
#' @param id OMS identification of object for which multipolygons are to be extracted
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

    indx <- which (grepl ('osm_', names (dat)))
    where <- indx [which (sapply (dat [indx], function (i) id %in% rownames (i)))]
    x <- dat [[where]] [which (rownames (dat [[where]]) == id),]$geometry

    if (any (grepl ('MULTI', class (x))))
        stop ('osm_multipolygons id must be of a point, line, or polygon object')

    if (is (x, 'sfc_POINT'))
    { 
        # find all lines containing that point
        indx <- which (sapply (dat$osm_lines$geometry, function (i) 
                               any (rownames (i) %in% id)))
        ids <- names (indx)
        indx <- which (sapply (dat$osm_polygons$geometry, function (i) 
                               any (rownames (i [[1]]) %in% id)))
        ids <- c (ids, names (indx))
        # then find all multipolygons containing those lines
        indx <- which (sapply (dat$osm_multipolygons$geometry, function (i) 
                               {
                                   ids_i <- unlist (sapply (names (i [[1]]), 
                                                            function (j) 
                                                                strsplit (j, '-')))
                                   names (ids_i) <- NULL
                                   any (ids_i %in% ids)
                               }))
    } else if (class (x) [1] %in% c ('sfc_LINESTRING', 'sfc_POLYGON'))
        indx <- which (sapply (dat$osm_multipolygons$geometry, function (i) 
                               any (names (i [[1]]) %in% id)))

    dat$osm_multipolygons [indx, ]
}

