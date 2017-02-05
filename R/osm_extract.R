#' Extract all \code{osm_points} from an osmdata object
#'
#' @param dat An object of class \code{osmdata}
#' @param id OMS identification of object for which points are to be extracted
#' @return An \code{sf} Simple Features Collection of points 
#'
#' @export
osm_points <- function(dat, id) {
    if (missing (dat))
        stop ('osm_oints can not be extracted without data')
    if (!is (dat, 'osmdata'))
        stop ('dat must be of class osmdata')
    if (missing (id))
        stop ('id must be given to extract points')
    if (!(is.character (id) | is.numeric (id)))
        stop ('id must be of class character or numeric')

    if (!is.character (id))
        id <- as.character (id)

    indx <- which (grepl ("osm_", names (dat)))
    where <- indx [which (sapply (dat [indx], function (i) id %in% rownames (i)))]
    x <- dat [[where]] [which (rownames (dat [[where]]) == id),]$geometry
    if (is (x, "sfc_MULTIPOLYGON"))
        x <- x [[1]]
    if (is (x, "sfc_LINESTRING"))
        ids <- unique (rownames (x [[1]]))
    else
        ids <- unique (rownames (do.call (rbind, x [[1]])))

    dat$osm_points [which (rownames (dat$osm_points) %in% ids), ]
}

