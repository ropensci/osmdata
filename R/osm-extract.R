# get the sf geometry of the component with id from dat
get_geoms <- function (dat, id)
{
    indx <- which (grepl ('osm_', names (dat)))
    where <- indx [which (vapply (dat [indx], function (i)
                                  any (id %in% rownames (i)),
                                  FUN.VALUE = logical (1)))]
    lapply (where, function (i)
            {
                indx <- which (rownames (dat [[i]]) %in% id)
                nms <- rownames (dat [[i]]) [indx]
                ret <- dat [[i]] [indx, ]$geometry
                names (ret) <- nms
                return (ret)
            })
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
        ids <- as.character (unlist (lapply (ids, function (i)
                                             strsplit (i, '-'))))
    } else if (is (x [[1]], 'MULTILINESTRING'))
    {
        ids <- as.character (unlist (lapply (x, function (i) names (i))))
    } else if (is (x [[1]], 'POLYGON'))
    {
        # find all intersecting lines
        pts <- as.character (unlist (lapply (x, function (i)
                                             rownames (i [[1]]))))
        indx <- which (vapply (dat$osm_lines$geometry, function (i)
                               any (pts %in% rownames (i)),
                               FUN.VALUE = logical (1)))
        ids <- names (dat$osm_lines$geometry) [indx]
    } else if (is (x [[1]], 'LINESTRING'))
    {
        # find all intersecting lines
        pts <- do.call (rbind, x)
        pts <- as.character (rownames (pts))
        indx <- which (vapply (dat$osm_lines$geometry, function (i)
                               any (pts %in% rownames (i)),
                               FUN.VALUE = logical (1)))
        ids <- names (dat$osm_lines$geometry) [indx]
    } else if (is (x [[1]], 'POINT'))
    {
        # find all intersecting lines
        pts <- names (x)
        indx <- which (vapply (dat$osm_lines$geometry, function (i)
                               any (pts %in% rownames (i)),
                               FUN.VALUE = logical (1)))
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
        ids <- as.character (unlist (lapply (ids, function (i)
                                             strsplit (i, '-'))))
    } else if (is (x [[1]], 'MULTILINESTRING'))
    {
        stop ('MULTILINESTRINGS do not contain polygons by definition')
    } else if (is (x [[1]], 'POLYGON'))
    {
        # find all intersecting polygons
        pts <- do.call (rbind, lapply (x, function (i) i [[1]]))
        pts <- as.character (rownames (pts))
        indx <- which (vapply (dat$osm_polygons$geometry, function (i)
                               any (pts %in% rownames (i [[1]])),
                               FUN.VALUE = logical (1)))
        ids <- names (dat$osm_polygons$geometry) [indx]
    } else if (is (x [[1]], 'LINESTRING'))
    {
        # find all intersecting lines
        pts <- as.character (rownames (do.call (rbind, x)))
        indx <- which (vapply (dat$osm_polygons$geometry, function (i)
                               any (pts %in% rownames (i [[1]])),
                               FUN.VALUE = logical (1)))
        ids <- names (dat$osm_polygons$geometry) [indx]
    } else if (is (x [[1]], 'POINT'))
    {
        # find all intersecting lines
        pts <- names (x)
        indx <- which (vapply (dat$osm_polygons$geometry, function (i)
                               any (pts %in% rownames (i [[1]])),
                               FUN.VALUE = logical (1)))
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
        indx <- vapply (mls, function (i) any (ids %in% i),
                        FUN.VALUE = logical (1))
        ids <- names (indx) [which (indx)]
    } else if (is (x [[1]], 'POINT'))
    {
        # find all lines containing those points
        lns <- names (which (vapply (dat$osm_lines$geometry, function (i)
                                     any (rownames (i) %in% names (x)),
                                     FUN.VALUE = logical (1))))
        # then find all multilines containing those lines
        indx <- vapply (dat$osm_multilines$geometry, function (i)
                        any (names (i) %in% lns), FUN.VALUE = logical (1))
        ids <- names (indx) [which (indx)]
    }

    return (ids)
}

get_multipolygon_ids <- function (x, dat, id)
{
    ids <- NULL

    # get ids of all multipolygon components
    mps <- lapply (dat$osm_multipolygons$geometry, function (i)
                   names (i [[1]]))
    mps <- lapply (mps, function (i) unlist (strsplit (i, '-')))

    if (is (x [[1]], 'POLYGON') | is (x [[1]], 'LINESTRING'))
    {
        ids <- names (x)
        indx <- vapply (mps, function (i) any (ids %in% i),
                        FUN.VALUE = logical (1))
        ids <- names (indx) [which (indx)]
    } else if (is (x [[1]], 'POINT'))
    {
        # find all lines containing those points
        lns <- names (which (vapply (dat$osm_lines$geometry, function (i)
                                     any (rownames (i) %in% names (x)),
                                     FUN.VALUE = logical (1))))
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


#' Extract all `osm_points` from an osmdata object
#'
#' @param dat An object of class \link{osmdata}
#' @param id OSM identification of one or more objects for which points are to
#' be extracted
#'
#' @return An \pkg{sf} Simple Features Collection of points 
#'
#' @export
#'
#' @examples
#' \dontrun{
#' tr <- opq ("trentham australia") %>% osmdata_sf ()
#' coliban <- tr$osm_lines [which (tr$osm_lines$name == 'Coliban River'),]
#' pts <- osm_points (tr, rownames (coliban)) # all points of river
#' waterfall <- pts [which (pts$waterway == 'waterfall'),] # the waterfall point
#' }
osm_points <- function(dat, id) {
    if (missing (dat))
        stop ('osm_points can not be extracted without data')
    if (missing (id))
        stop ('id must be given to extract points')

    if (is.factor (id))
        id <- as.character (id)

    id <- sanity_check (dat, id)

    x <- get_geoms (dat, id)
    ids <- lapply (x, function (i) get_point_ids (i))
    ids <- unique (unlist (ids))

    dat$osm_points [which (rownames (dat$osm_points) %in% ids), ]
}

#' Extract all `osm_lines` from an osmdata object
#'
#' If `id` is of a point object, `osm_lines` will return all lines
#' containing that point. If `id` is of a line or polygon object,
#' `osm_lines` will return all lines which intersect the given line or
#' polygon.
#'
#' @param dat An object of class \link{osmdata}
#' @param id OSM identification of one or more objects for which lines are to be
#' extracted
#' @return An \pkg{sf} Simple Features Collection of linestrings 
#'
#' @export
#'
#' @examples
#' \dontrun{
#' dat <- opq ("hengelo nl") %>% add_osm_feature (key="highway") %>%
#'      osmdata_sf ()
#' bus <- dat$osm_points [which (dat$osm_points$highway == 'bus_stop'),] %>%
#'         rownames () # all OSM IDs of bus stops
#' osm_lines (dat, bus) # all highways containing bus stops
#'
#' # All lines which intersect with Piccadilly Circus in London, UK
#' dat <- opq ("Fitzrovia London") %>% add_osm_feature (key="highway") %>% 
#'     osmdata_sf ()
#' i <- which (dat$osm_polygons$name == "Piccadilly Circus")
#' id <- rownames (dat$osm_polygons [i,])
#' osm_lines (dat, id)
#' }
osm_lines <- function(dat, id) {
    if (missing (dat))
        stop ('osm_lines can not be extracted without data')
    if (missing (id))
        stop ('id must be given to extract lines')

    if (is.factor (id))
        id <- as.character (id)

    id <- sanity_check (dat, id)

    x <- get_geoms (dat, id)
    ids <- lapply (x, function (i) get_line_ids (i, dat, id))
    ids <- unique (unlist (ids))

    dat$osm_lines [which (rownames (dat$osm_lines) %in% ids), ]
}


#' Extract all `osm_polygons` from an osmdata object
#'
#' If `id` is of a point object, `osm_polygons` will return all
#' polygons containing that point. If `id` is of a line or polygon object,
#' `osm_polygons` will return all polygons which intersect the given line
#' or polygon.
#'
#'
#' @param dat An object of class \link{osmdata}
#' @param id OSM identification of one or more objects for which polygons are to
#' be extracted
#' @return An \pkg{sf} Simple Features Collection of polygons 
#'
#' @export
#'
#' @examples
#' \dontrun{
#' Extract polygons which intersect Conway Street in London
#' dat <- opq ("Marylebone London") %>% add_osm_feature (key="highway") %>% 
#'     osmdata_sf ()
#' conway <- which (dat$osm_lines$name == "Conway Street") 
#' id <- rownames (dat$osm_lines [conway,])
#' osm_polygons (dat, id)
#' }
osm_polygons <- function(dat, id) {
    if (missing (dat))
        stop ('osm_polygons can not be extracted without data')
    if (missing (id))
        stop ('id must be given to extract polygons')

    if (is.factor (id))
        id <- as.character (id)

    id <- sanity_check (dat, id)

    x <- get_geoms (dat, id)
    ids <- lapply (x, function (i) get_polygon_ids (i, dat, id))
    ids <- unique (unlist (ids))

    dat$osm_polygons [which (rownames (dat$osm_polygons) %in% ids), ]
}


#' Extract all `osm_multilines` from an osmdata object
#'
#' `id` must be of an `osm_points` or `osm_lines` object (and can
#' not be the `id` of an `osm_polygons` object because multilines by
#' definition contain no polygons.  `osm_multilines` returns any multiline
#' object(s) which contain the object specified by `id`.
#'
#'
#' @param dat An object of class \link{osmdata}
#' @param id OSM identification of one of more objects for which multilines are
#' to be extracted
#' @return An \pkg{sf} Simple Features Collection of multilines 
#'
#' @export
#'
#' @examples
#' \dontrun{
#' dat <- opq ("London UK") %>% 
#'     add_osm_feature (key="name", value="Thames", exact=FALSE) %>% osmdata_sf ()
#' # Get ids of lines called "The Thames":
#' id <- rownames (dat$osm_lines [which (dat$osm_lines$name == "The Thames"),])
#' # and find all multilinestring objects which include those lines:
#' osm_multilines (dat, id)
#' # Now note that
#' nrow (dat$osm_multilines) # = 24 multiline objects
#' nrow (osm_multilines (dat, id)) # = 1 - the recursive search selects the
#'                                 # single multiline containing "The Thames"
#' }
osm_multilines <- function(dat, id) {
    if (missing (dat))
        stop ('osm_multilines can not be extracted without data')
    if (missing (id))
        stop ('id must be given to extract multilines')

    if (is.factor (id))
        id <- as.character (id)

    id <- sanity_check (dat, id)

    x <- get_geoms (dat, id)
    ids <- lapply (x, function (i) get_multiline_ids (i, dat, id))
    ids <- unique (unlist (ids))

    dat$osm_multilines [which (rownames (dat$osm_multilines) %in% ids), ]
}

#' Extract all `osm_multipolygons` from an osmdata object
#'
#' `id` must be of an `osm_points`, `osm_lines`, or
#' `osm_polygons` object. `osm_multipolygons` returns any multipolygon
#' object(s) which contain the object specified by `id`.
#'
#'
#' @param dat An object of class \link{osmdata}
#' @param id OSM identification of one or more objects for which multipolygons
#' are to be extracted
#' @return An \pkg{sf} Simple Features Collection of multipolygons 
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # find all multipolygons which contain the single polygon called 
#' # "Chiswick Eyot" (which is an island).
#' dat <- opq ("London UK") %>% 
#'     add_osm_feature (key="name", value="Thames", exact=FALSE) %>% osmdata_sf ()
#' id <- rownames (dat$osm_polygons [which (dat$osm_polygons$name == "Chiswick Eyot"),])
#' osm_multipolygons (dat, id)
#' # That multipolygon is the Thames itself, but note that
#' nrow (dat$osm_multipolygons) # = 14 multipolygon objects
#' nrow (osm_multipolygons (dat, id)) # = 1 - the main Thames multipolygon
#' }
osm_multipolygons <- function(dat, id) {
    if (missing (dat))
        stop ('osm_multipolygons can not be extracted without data')
    if (missing (id))
        stop ('id must be given to extract multipolygons')

    if (is.factor (id))
        id <- as.character (id)

    id <- sanity_check (dat, id)

    x <- get_geoms (dat, id)
    ids <- lapply (x, function (i) get_multipolygon_ids (i, dat, id))
    ids <- unique (unlist (ids))

    dat$osm_multipolygons [which (rownames (dat$osm_multipolygons) %in% ids), ]
}
