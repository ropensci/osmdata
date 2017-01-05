context ("sf-construction")

# Needs these functions from `sf::sfg.R`:
getClassDim <- function(x, d, dim = "XYZ", type) {
    stopifnot(d > 1)
    type = toupper(type)
    if (d == 2)
        c("XY", type, "sfg")
    else if (d == 3) {
        stopifnot(dim %in% c("XYZ", "XYM"))
        c(dim, type, "sfg")
    } else if (d == 4)
        c("XYZM", type, "sfg")
    else stop(paste(d, "is an illegal number of columns for a", type))
}
Mtrx <- function(x, dim = "XYZ", type) {
    stopifnot(is.matrix(x) && is.numeric(x))
    structure(x, class = getClassDim(x, ncol(x), dim, type))
}

# And then these functions to construct `sf` objects:
make_sfc <- function (x, type) {
    xvals <- if (is.matrix (x)) x [,1] else x [1]
    yvals <- if (is.matrix (x)) x [,2] else x [2]
    bb <- structure(rep(NA_real_, 4), names = c("xmin", "ymin", "xmax", "ymax"))
    bb [1:4] <- c (min (xvals), min (yvals), max (xvals), max (yvals))
    n <- if (is.matrix (x))
            ncol (x)
        else
            length (x)
    if (length (n) > 1)
        stop ("Found multiple dimensions")
    x <- structure (x, class = getClassDim(x, n, type=type))
    x <- list (x)
    attr (x, "n_empty") = sum(sapply(x, function(x) length(x) == 0))
    class(x) = c(paste0("sfc_", class(x[[1L]])[2L]), "sfc")
    attr(x, "precision") = 0.0
    attr(x, "bbox") = bb
    NA_crs_ = structure(list(epsg = NA_integer_, proj4string = NA_character_), class = "crs")
    attr(x, "crs") = NA_crs_
    x
}

make_sf <- function (...)
{
    x <- list (...)
    sf = sapply(x, function(i) inherits(i, "sfc"))
    sf_column <- which (sf)
    row.names <- seq_along (x [[sf_column]])
    df <- if (length(x) == 1) # ONLY sfc
                data.frame(row.names = row.names)
            else # create a data.frame from list:
                    data.frame(x[-sf_column], row.names = row.names, 
                           stringsAsFactors = TRUE)

    object = as.list(substitute(list(...)))[-1L] 
    arg_nm = sapply(object, function(x) deparse(x))
    sfc_name <- make.names(arg_nm[sf_column])
    df [[sfc_name]] <- x [[sf_column]]
    attr(df, "sf_column") = sfc_name
    f = factor(rep(NA_character_, length.out = ncol(df) - 1), 
               levels = c("field", "lattice", "entity"))
    # The right way to do it - not yet in "sf"!
    #names(f) = names(df)[-ncol (df)]
    # The current, wrong way as done in sf:
    names(f) = names(df)[-sf_column]
    attr(df, "relation_to_geometry") = f
    class(df) = c("sf", class(df))
    return (df)
}

test_that ("sfc-single-point", {
               x <- make_sfc (1:2, type="POINT")
               x1 <- sf::st_sfc (sf::st_point(1:2))
               expect_identical (x, x1)
})

test_that ("sf-single-point", {
               x <- sf::st_sfc (sf::st_point(1:2))
               x0 <- make_sf (x)
               x1 <- sf::st_sf (x)
               expect_identical (x0, x1)
})

test_that ("sf-single-point-with-fields", {
               x <- sf::st_sfc (sf::st_point(1:2))
               x0 <- make_sf (x, a=3, b="blah")
               x1 <- sf::st_sf (x, a=3, b="blah")
               expect_identical (x0, x1)
})

# sf::LINESTRINGs need this function:
Mtrx <- function(x, dim = "XYZ", type) {
    stopifnot(is.matrix(x) && is.numeric(x))
    structure(x, class = getClassDim(x, ncol(x), dim, type))
}

test_that ("sfc-single-line", {
               x <- make_sfc (cbind (1:4,5:8), "LINESTRING")
               x1 <- sf::st_sfc (sf::st_linestring (cbind (1:4, 5:8)))
               expect_identical (x, x1)
})

test_that ("sf-single-line", {
               x <- make_sfc (cbind (1:4,5:8), "LINESTRING")
               x1 <- make_sf (x)
               x <- sf::st_sfc (sf::st_linestring (cbind (1:4, 5:8)))
               x2 <- sf::st_sf (x)
               expect_identical (x1, x2)
})

test_that ("sf-single-line-with-fields", {
               x <- make_sfc (cbind (1:4,5:8), "LINESTRING")
               x1 <- make_sf (x, a=3, b="blah")
               x <- sf::st_sfc (sf::st_linestring (cbind (1:4, 5:8)))
               x2 <- sf::st_sf (x, a=3, b="blah")
               expect_identical (x1, x1)
})
