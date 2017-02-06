get_geoms <- function (dat, id)
{
    indx <- which (grepl ('osm_', names (dat)))
    where <- indx [which (sapply (dat [indx], function (i) 
                                  any (id %in% rownames (i))))]
    lapply (where, function (i)
            dat [[i]] [which (rownames (dat [[i]]) %in% id),]$geometry)
}

# x is a list of sf objects all of same class
get_point_ids <- function (x)
{
    pts <- NULL
    if (is (x [[1]], 'MULTIPOLYGON'))
    {
        pts <- lapply (x, function (i) do.call (rbind, i [[1]]))
        pts <- do.call (rbind, pts)
    } else if (is (x [[1]], 'MULTILINESTRING'))
    {
        pts <- lapply (x, function (i) do.call (rbind, i))
        pts <- do.call (rbind, pts)
    } else if (is (x [[1]], 'POLYGON'))
    {
        pts <- lapply (x, function (i) do.call (rbind, i))
        pts <- do.call (rbind, pts)
    } else if (is (x [[1]], 'LINESTRING'))
        pts <- do.call (rbind, x)

    ids <- as.character (rownames (pts))

    return (unique (ids))
}

get_line_ids <- function (x, dat, id)
{
    ids <- NULL
    if (is (x [[1]], 'MULTIPOLYGON'))
    {
        ids <- lapply (x, function (i) names (i [[1]]))
        ids <- as.character (unlist (sapply (ids, function (i) strsplit (i, '-'))))
    } else if (is (x [[1]], 'MULTILINESTRING'))
    {
        ids <- as.character (unlist (lapply (x, function (i) names (i))))
    } else if (is (x [[1]], 'POLYGON'))
    {
        ids <- names (x)
    } else if (is (x [[1]], 'LINESTRING'))
    {
        # find all intersecting lines
        pts <- do.call (rbind, x)
        pts <- as.character (rownames (pts))
        indx <- which (sapply (dat$osm_lines$geometry, function (i) 
                               any (pts %in% rownames (i))))
        ids <- names (dat$osm_lines$geometry) [indx]
    } else if (is (x [[1]], 'POINT'))
    {
        # find all intersecting lines
        pts <- names (x)
        indx <- which (sapply (dat$osm_lines$geometry, function (i) 
                               any (pts %in% rownames (i))))
        ids <- names (dat$osm_lines$geometry) [indx]
    }
    return (ids)
}

get_polygon_ids <- function (x, dat, id)
{
    ids <- NULL
    if (is (x [[1]], 'MULTIPOLYGON'))
    {
        ids <- lapply (x, function (i) names (i [[1]]))
        ids <- as.character (unlist (sapply (ids, function (i) strsplit (i, '-'))))
    } else if (is (x [[1]], 'MULTILINESTRING'))
    {
        stop ('MULTILINESTRINGS do not contain polygons by definition')
    } else if (is (x [[1]], 'POLYGON'))
    {
        # find all intersecting polygons
        pts <- do.call (rbind, lapply (x, function (i) i [[1]]))
        pts <- as.character (rownames (pts))
        indx <- which (sapply (dat$osm_polygons$geometry, function (i) 
                               any (pts %in% rownames (i [[1]]))))
        ids <- names (dat$osm_polygons$geometry) [indx]
    } else if (is (x [[1]], 'LINESTRING'))
    {
        # find all intersecting lines
        pts <- as.character (rownames (do.call (rbind, x)))
        indx <- which (sapply (dat$osm_polygons$geometry, function (i) 
                               any (pts %in% rownames (i [[1]]))))
        ids <- names (dat$osm_polygons$geometry) [indx]
    } else if (is (x [[1]], 'POINT'))
    {
        # find all intersecting lines
        pts <- names (x)
        indx <- which (sapply (dat$osm_polygons$geometry, function (i) 
                               any (pts %in% rownames (i [[1]]))))
        ids <- names (dat$osm_polygons$geometry) [indx]
    }
    return (ids)
}

get_multiline_ids <- function (x, dat, id)
{
    ids <- NULL
    if (is (x [[1]], 'LINESTRING'))
    {
        ids <- names (x)
        mls <- lapply (dat$osm_multilines$geometry, function (i) names (i))
        indx <- sapply (mls, function (i) any (ids %in% i))
        ids <- names (indx) [which (indx)]
    } else if (is (x [[1]], 'POINT'))
    {
        # find all lines containing those points
        lns <- names (which (sapply (dat$osm_lines$geometry, function (i)
                                     any (rownames (i) %in% names (x)))))
        # then find all multilines containing those lines
        indx <- sapply (dat$osm_multilines$geometry, function (i)
                        any (names (i) %in% lns))
        ids <- names (indx) [which (indx)]
    }

    return (ids)
}

get_multipolygon_ids <- function (x, dat, id)
{
    ids <- NULL

    # get ids of multipolygons
    mps <- lapply (dat$osm_multipolygons$geometry, function (i) 
                   names (i [[1]]))
    mps <- lapply (mps, function (i) unlist (strsplit (i, '-')))

    if (is (x [[1]], 'POLYGON') | is (x [[1]], 'LINESTRING'))
    {
        ids <- names (x)
        indx <- sapply (mps, function (i) any (ids %in% i))
        ids <- names (indx) [which (indx)]
    } else if (is (x [[1]], 'POINT'))
    {
        # find all lines containing those points
        lns <- names (which (sapply (dat$osm_lines$geometry, function (i)
                                     any (rownames (i) %in% names (x)))))
        # then find all multipolygons containing those lines
        indx <- lapply (mps, function (i) any (lns %in% i))
        ids <- names (indx) [which (as.logical (indx))]
    }

    return (ids)
}

sanity_check <- function (dat, id)
{
    if (!is (dat, 'osmdata'))
        stop ('dat must be of class osmdata')
    if (!(is.character (id) | is.numeric (id)))
        stop ('id must be of class character or numeric')

    if (!is.character (id))
        id <- as.character (id)

    return (id)
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
    if (missing (id))
        stop ('id must be given to extract points')

    id <- sanity_check (dat, id)

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
    if (missing (id))
        stop ('id must be given to extract lines')

    id <- sanity_check (dat, id)

    x <- get_geoms (dat, id)
    ids <- lapply (x, function (i) get_line_ids (i, dat, id))
    ids <- unique (unlist (ids))

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
#' @param id OSM identification of one or more objects for which polygons are to
#' be extracted
#' @return An \code{sf} Simple Features Collection of polygons 
#'
#' @export
osm_polygons <- function(dat, id) {
    if (missing (dat))
        stop ('osm_polygons can not be extracted without data')
    if (missing (id))
        stop ('id must be given to extract polygons')

    id <- sanity_check (dat, id)

    x <- get_geoms (dat, id)
    ids <- lapply (x, function (i) get_polygon_ids (i, dat, id))
    ids <- unique (unlist (ids))

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
#' @param id OSM identification of one of more objects for which multilines are
#' to be extracted
#' @return An \code{sf} Simple Features Collection of multilines 
#'
#' @export
osm_multilines <- function(dat, id) {
    if (missing (dat))
        stop ('osm_multilines can not be extracted without data')
    if (missing (id))
        stop ('id must be given to extract multilines')

    id <- sanity_check (dat, id)

    x <- get_geoms (dat, id)
    ids <- lapply (x, function (i) get_multiline_ids (i, dat, id))
    ids <- unique (unlist (ids))

    dat$osm_multilines [which (rownames (dat$osm_multilines) %in% ids), ]
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
    if (missing (id))
        stop ('id must be given to extract multipolygons')

    id <- sanity_check (dat, id)

    x <- get_geoms (dat, id)
    ids <- lapply (x, function (i) get_multipolygon_ids (i, dat, id))
    ids <- unique (unlist (ids))

    dat$osm_multipolygons [which (rownames (dat$osm_multipolygons) %in% ids), ]
}
