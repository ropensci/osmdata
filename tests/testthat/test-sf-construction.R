context ("sf-construction")

# Needs this function from `sf::sfg.R`:
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

# And then these functions to construct `sf` objects:
make_sfc <- function (x, type) {
    xvals <- if (is.matrix (x)) x [,1] else x [1]
    yvals <- if (is.matrix (x)) x [,2] else x [2]
    bb <- structure(rep(NA_real_, 4), names = c("xmin", "ymin", "xmax", "ymax"))
    bb [1:4] <- c (min (xvals), min (yvals), max (xvals), max (yvals))
    # The `ncol` here is from the fn `Mtrx()` in `sfg.R`
    n <- if (is.matrix (x))
            ncol (x)
        else
            length (x)
    if (length (n) > 1)
        stop ("Found multiple dimensions")
    if (type == "MULTIPOLYGON") x <- list (list (x))
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
               levels = c ("field", "lattice", "entity"))
    # Next sf changes to:
               #levels = c ("constant", "aggregate", "identity"))
    # The right way to do it - not yet in "sf"!
    #names(f) = names(df)[-ncol (df)]
    # The current, wrong way as done in sf:
    names(f) = names(df)[-sf_column]
    attr(df, "relation_to_geometry") = f
    class(df) = c("sf", class(df))
    return (df)
}

test_that ("sfc-point", {
               x <- make_sfc (1:2, type="POINT")
               x1 <- sf::st_sfc (sf::st_point(1:2))
               expect_identical (x, x1)
               x <- make_sfc (1:3, type="POINT") # POINTZ
               x2 = sf::st_sfc (sf::st_point(1:3))
               expect_identical (x, x2)
               x <- make_sfc (1:4, type="POINT")
               x2 = sf::st_sfc (sf::st_point(1:4)) # POINTZM
               expect_identical (x, x2)
})

test_that ("sf-point", {
               x <- sf::st_sfc (sf::st_point (1:2))
               x0 <- make_sf (x)
               x1 <- sf::st_sf (x)
               expect_identical (x0, x1)
               x <- sf::st_sfc (sf::st_point (1:3))
               x0 <- make_sf (x)
               x1 <- sf::st_sf (x)
               expect_identical (x0, x1)
               x <- sf::st_sfc (sf::st_point (1:4))
               x0 <- make_sf (x)
               x1 <- sf::st_sf (x)
               expect_identical (x0, x1)
})

test_that ("sf-point-with-fields", {
               x <- sf::st_sfc (sf::st_point(1:2))
               x0 <- make_sf (x, a=3, b="blah")
               x1 <- sf::st_sf (x, a=3, b="blah")
               expect_identical (x0, x1)
               # next lines will work with next sf version:
               #x0 <- make_sf (a=3, b="blah", x)
               #x1 <- sf::st_sf (x, a=3, b="blah")
               #expect_identical (x0, x1)
})

test_that ("sfc-line", {
               x <- make_sfc (cbind (1:4,5:8), "LINESTRING")
               x1 <- sf::st_sfc (sf::st_linestring (cbind (1:4, 5:8)))
               expect_identical (x, x1)
})

test_that ("sf-line", {
               x <- make_sfc (cbind (1:4,5:8), "LINESTRING")
               x1 <- make_sf (x)
               x <- sf::st_sfc (sf::st_linestring (cbind (1:4, 5:8)))
               x2 <- sf::st_sf (x)
               expect_identical (x1, x2)
})

test_that ("sf-line-with-fields", {
               x <- make_sfc (cbind (1:4,5:8), "LINESTRING")
               x1 <- make_sf (x, a=3, b="blah")
               x <- sf::st_sfc (sf::st_linestring (cbind (1:4, 5:8)))
               x2 <- sf::st_sf (x, a=3, b="blah")
               expect_identical (x1, x1)
})

test_that ("sfg-multipolygon", {
               p1 <- matrix(c(0,0,10,0,10,10,0,10,0,0),ncol=2, byrow=TRUE)
               pts <- list (list (p1))
               mp <- sf::st_multipolygon (pts)
               mp1 <- structure (pts, class=getClassDim (pts, ncol (p1), dim="XYZ",
                                                         type="MULTIPOLYGON"))
               expect_identical (mp, mp1)
})

test_that ("sfc-multipolygon", {
               p1 <- matrix(c(0,0,10,0,10,10,0,10,0,0),ncol=2, byrow=TRUE)
               pts <- list (list (p1))
               mp <- structure (pts, class=getClassDim (pts, ncol (p1), dim="XYZ",
                                                         type="MULTIPOLYGON"))
               xsf <- sf::st_sfc (mp) 
               x <- make_sfc (p1, type="MULTIPOLYGON")
               expect_identical (x, xsf)
})

test_that ("sf-multipolygon", {
               p1 <- matrix(c(0,0,10,0,10,10,0,10,0,0),ncol=2, byrow=TRUE)
               pts <- list (list (p1))
               mp <- structure (pts, class=getClassDim (pts, ncol (p1), dim="XYZ",
                                                         type="MULTIPOLYGON"))
               x <- sf::st_sfc (mp) 
               xsf <- sf::st_sf (x)
               x <- make_sfc (p1, type="MULTIPOLYGON")
               x <- make_sf (x)
               expect_identical (x, xsf)
})

test_that ("sf-multipolygon-with-fields", {
               p1 <- matrix(c(0,0,10,0,10,10,0,10,0,0),ncol=2, byrow=TRUE)
               pts <- list (list (p1))
               mp <- structure (pts, class=getClassDim (pts, ncol (p1), dim="XYZ",
                                                         type="MULTIPOLYGON"))
               x <- sf::st_sfc (mp) 
               xsf <- sf::st_sf (x, a=3, b="blah")
               x <- make_sfc (p1, type="MULTIPOLYGON")
               x <- make_sf (x, a=3, b="blah")
               expect_identical (x, xsf)
               # These lines will work with next sf:
               #x <- sf::st_sfc (mp) 
               #xsf <- sf::st_sf (x, a=3, b="blah")
               #x <- make_sfc (p1, type="MULTIPOLYGON")
               #x <- make_sf (a=3, b="blah", x)
               #expect_identical (x, xsf)
})
