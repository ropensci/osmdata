context ("sf-construction")

make_sfc <- function (x, type) {
    if (!is.list (x)) x <- list (x)
    type <- toupper (type)
    stopifnot (type %in% c ("POINT", "LINESTRING", "MULTIPOLYGON"))
    xy <- do.call (rbind, x)
    xvals <- xy [,1]
    yvals <- xy [,2]
    bb <- structure(rep(NA_real_, 4), names = c("xmin", "ymin", "xmax", "ymax"))
    bb [1:4] <- c (min (xvals), min (yvals), max (xvals), max (yvals))
    if (type == "MULTIPOLYGON") x <- lapply (x, function (i) list (list (i)))
    x <- lapply (x, function (i) structure (i, class = c ("XY", type, "sfg")))
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
    # Next version of sf:
    #f = factor(rep(NA_character_, length.out = ncol(df) - 1), 
    #           levels = c ("constant", "aggregate", "identity"))
    # The right way to do it - not yet in "sf"!
    #names(f) = names(df)[-ncol (df)]
    # The current, wrong way as done in sf:
    names(f) = names(df)[-sf_column]
    attr(df, "relation_to_geometry") = f
    class(df) = c("sf", class(df))
    return (df)
}

# **********************************************************
# ***                       POINTS                       ***
# **********************************************************

test_that ("sfg-point", {
               x <- structure (1:2, class=c("XY", "POINT", "sfg"))
               expect_identical (x, sf::st_point (1:2))
})

test_that ("sfc-point", {
               x <- make_sfc (1:2, type="POINT") # POINT
               y = sf::st_sfc (sf::st_point(1:2))
               expect_identical (x, y)
})

test_that ("sf-point", {
               x <- sf::st_sfc (sf::st_point(1:2))
               expect_identical (x, make_sfc (1:2, "POINT"))
               y <- sf::st_sf (x)
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sf-point-with-fields", {
               x <- sf::st_sfc (sf::st_point(1:2))
               y <- sf::st_sf (x, a=3, b="blah")
               x <- make_sf (x, a=3, b="blah")
               expect_identical (x, y)
               # next lines will work with next sf version:
               #x0 <- make_sf (a=3, b="blah", x)
               #x1 <- sf::st_sf (x, a=3, b="blah")
               #expect_identical (x0, x1)
})

test_that ("multiple-points", {
               x0 <- make_sfc (list (1:2, 3:4), type="POINT")
               y <- sf::st_sfc (sf::st_point (1:2), sf::st_point (3:4))
               expect_identical (x0, y)
               y <- sf::st_sf (x0, a=7:8, b=c("blah", "junk")) 
               x <- make_sf (x0, a=7:8, b=c("blah", "junk"))
               expect_identical (x, y)
               dat <- data.frame (a=11:12, txt=c("junk", "blah"))
               y <- sf::st_sf (x0, dat)
               x <- make_sf (x0, dat)
               expect_identical (x, y)
               dat <- data.frame (a=11:12, txt=c("junk", "blah"))
               y <- sf::st_sf (x0, dat)
               expect_identical (x, y) # data.frame yields same results as lists
               x <- make_sf (x0, dat)
               expect_identical (x, y)
})

# **********************************************************
# ***                       LINES                        ***
# **********************************************************

test_that ("sfg-line", {
               x <- structure (cbind (1:4,5:8), class=c("XY", "LINESTRING", "sfg"))
               expect_identical (x, sf::st_linestring (cbind (1:4,5:8)))
})

test_that ("sfc-line", {
               x <- make_sfc (cbind (1:4,5:8), "LINESTRING")
               y <- sf::st_sfc (sf::st_linestring (cbind (1:4, 5:8)))
               expect_identical (x, y)
})

test_that ("sf-line", {
               x <- make_sfc (cbind (1:4,5:8), "LINESTRING")
               y <- sf::st_sf (x)
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sf-line-with-fields", {
               x <- make_sfc (cbind (1:4,5:8), "LINESTRING")
               y <- sf::st_sf (x, a=3, b="blah")
               x <- make_sf (x, a=3, b="blah")
               expect_identical (x, y)
})

test_that ("sfc-multiple-lines", {
               x1 <- cbind (1:4, 5:8)
               x2 <- cbind (11:13, 25:27)
               x <- make_sfc (list (x1, x2), type="LINESTRING")
               y <- sf::st_sfc (sf::st_linestring (x1), sf::st_linestring (x2))
               expect_identical (x, y)
})

test_that ("sf-multiple-lines", {
               x1 <- cbind (1:4, 5:8)
               x2 <- cbind (11:13, 25:27)
               x <- make_sfc (list (x1, x2), type="LINESTRING")
               y <- sf::st_sf (x) 
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sf-multiple-lines-with-fields", {
               x1 <- cbind (1:4, 5:8)
               x2 <- cbind (11:13, 25:27)
               x <- sf::st_sfc (sf::st_linestring (x1), sf::st_linestring (x2))
               y <- sf::st_sf (x, a=1:2, b="blah")
               x <- make_sfc (list (x1, x2), type="LINESTRING")
               x <- make_sf (x, a=1:2, b="blah")
               expect_identical (x, y)
               x <- sf::st_sfc (sf::st_linestring (x1), sf::st_linestring (x2))
               dat <- data.frame (a=1:2, b=c("blah", "junk"), c=c (TRUE, FALSE))
               y <- sf::st_sf (x, dat)
               x <- make_sfc (list (x1, x2), type="LINESTRING")
               x <- make_sf (x, dat)
               expect_identical (x, y)
})

# **********************************************************
# ***                      POLYGONS                      ***
# **********************************************************

test_that ("sfg-multipolygon", {
               x <- cbind (c (1:4, 1), c (5:8, 5))
               y <- sf::st_multipolygon (list (list (x)))
               x <- structure (list (list (x)), class=c ("XY", "MULTIPOLYGON", "sfg"))
               expect_identical (x, y)
})

test_that ("sfc-multipolygon", {
               x <- cbind (c (1:4, 1), c (5:8, 5))
               y <- sf::st_sfc (sf::st_multipolygon (list (list (x))))
               x <- make_sfc (x, type="MULTIPOLYGON")
               expect_identical (x, y)
})

test_that ("sf-multipolygon", {
               x <- make_sfc (cbind (c (1:4, 1), c (5:8, 5)), type="MULTIPOLYGON")
               y <- sf::st_sf (x) 
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sfc-multiple-multipolygons", {
               x1 <- cbind (c (1:4, 1), c (5:8, 5))
               x2 <- cbind (c (11:13, 11), c (25:27, 25))
               x <- make_sfc (list (x1, x2), type="MULTIPOLYGON")
               y <- sf::st_sfc (sf::st_multipolygon (list (list (x1))), 
                                sf::st_multipolygon (list (list (x2))))
               expect_identical (x, y)
})

test_that ("sf-multiple-multipolygons", {
               x1 <- cbind (c (1:4, 1), c (5:8, 5))
               x2 <- cbind (c (11:13, 11), c (25:27, 25))
               x <- make_sfc (list (x1, x2), type="MULTIPOLYGON")
               y <- sf::st_sf (x)
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sf-multipolygon-with-fields", {
               x1 <- cbind (c (1:4, 1), c (5:8, 5))
               x2 <- cbind (c (11:13, 11), c (25:27, 25))
               x0 <- make_sfc (list (x1, x2), type="MULTIPOLYGON")
               dat <- data.frame (a=1:2, b=c("blah", "junk"))
               y <- sf::st_sf (x0, dat)
               x <- make_sf (x0, dat)
               expect_identical (x, y)
               # The following will be possible with next version of sf:
               #y <- sf::st_sf (dat, x0)
               #x <- make_sf (x0, dat)
               #expect_identical (x, y)
               #y <- sf::st_sf (x0, dat)
               #x <- make_sf (dat, x0)
               #expect_identical (x, y)
})