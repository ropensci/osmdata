context ("sf-construction")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))

make_sfc <- function (x, type) {
    if (!is.list (x)) x <- list (x)
    type <- toupper (type)
    stopifnot (type %in% c ("POINT", "LINESTRING", "POLYGON",
                            "MULTILINESTRING", "MULTIPOLYGON"))
    if (is.list (x [[1]]))
        xy <- do.call (rbind, do.call ("c", x))
    else
        xy <- do.call (rbind, x)
    xvals <- xy [, 1]
    yvals <- xy [, 2]
    bb <- structure(rep(NA_real_, 4), names = c("xmin", "ymin", "xmax", "ymax"))
    bb [1:4] <- c (min (xvals), min (yvals), max (xvals), max (yvals))
    class (bb) <- "bbox"
    if (type == "POLYGON")
        x <- lapply (x, function (i) list (i))
    else if (grepl ("MULTI", type) & !is.list (x [[1]]))
        x <- list (x)
    if (type != "MULTIPOLYGON")
        x <- lapply (x, function (i)
                     structure (i, class = c ("XY", type, "sfg")))
    else
        x <- lapply (x, function (i)
                     structure (list (i), class = c ("XY", type, "sfg")))
    attr (x, "n_empty") <- sum(vapply(x, function(x)
                                      length(x) == 0,
                                      FUN.VALUE = logical (1)))
    attr(x, "precision") <- 0.0
    class(x) <- c(paste0("sfc_", class(x[[1L]])[2L]), "sfc")
    attr(x, "bbox") <- bb

    if (packageVersion ("sf") < 0.9)
        NA_crs_ <- structure(list(epsg = NA_integer_,
                                  proj4string = NA_character_), class = "crs")
    else
        NA_crs_ <- structure (list (input = NA_character_,
                                    wkt = NA_character_), class = "crs")
    attr(x, "crs") <- NA_crs_

    return (x)
}


# **********************************************************
# ***                       POINTS                       ***
# **********************************************************

if (test_all)
{

test_that ("sfg-point", {
               x <- structure (1:2, class = c("XY", "POINT", "sfg"))
               expect_identical (x, sf::st_point (1:2))
})

test_that ("sfc-point", {
               x <- make_sfc (1:2, type = "POINT") # POINT
               y <- sf::st_sfc (sf::st_point(1:2))
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
               y <- sf::st_sf (x, a = 3, b = "blah", stringsAsFactors = FALSE)
               x <- make_sf (x, a = 3, b = "blah")
               expect_identical (x, y)
               # next lines will work with next sf version:
               #x0 <- make_sf (a = 3, b = "blah", x)
               #x1 <- sf::st_sf (x, a = 3, b = "blah")
               #expect_identical (x0, x1)
})

test_that ("multiple-points", {
               x <- make_sfc (list (1:2, 3:4), type = "POINT")
               y <- sf::st_sfc (sf::st_point (1:2), sf::st_point (3:4))
               expect_identical (x, y)
               y0 <- sf::st_sf (x, a = 7:8, b = c("blah", "junk"),
                                stringsAsFactors = FALSE)
               x0 <- make_sf (x, a = 7:8, b = c("blah", "junk"))
               expect_identical (x0, y0)
               dat <- data.frame (a = 11:12, txt = c("junk", "blah"))
               y0 <- sf::st_sf (x, dat, stringsAsFactors = FALSE)
               x0 <- make_sf (x, dat)
               expect_identical (x0, y0)
               dat <- data.frame (a = 11:12, txt = c("junk", "blah"))
               y0 <- sf::st_sf (x, dat, stringsAsFactors = FALSE)
               expect_identical (x0, y0) # data.frame yields same results as lists
               x0 <- make_sf (x, dat, stringsAsFactors = FALSE)
               expect_identical (x0, y0)
})

# **********************************************************
# ***                       LINES                        ***
# **********************************************************

test_that ("sfg-line", {
               x <- structure (cbind (1:4, 5:8),
                               class = c("XY", "LINESTRING", "sfg"))
               expect_identical (x, sf::st_linestring (cbind (1:4, 5:8)))
})

test_that ("sfc-line", {
               x <- make_sfc (cbind (1:4, 5:8), "LINESTRING")
               y <- sf::st_sfc (sf::st_linestring (cbind (1:4, 5:8)))
               expect_identical (x, y)
})

test_that ("sf-line", {
               x <- make_sfc (cbind (1:4, 5:8), "LINESTRING")
               y <- sf::st_sf (x)
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sf-line-with-fields", {
               x <- make_sfc (cbind (1:4, 5:8), "LINESTRING")
               y <- sf::st_sf (x, a = 3, b = "blah", stringsAsFactors = FALSE)
               x <- make_sf (x, a = 3, b = "blah")
               expect_identical (x, y)
})

test_that ("sfc-multiple-lines", {
               x1 <- cbind (1:4, 5:8)
               x2 <- cbind (11:13, 25:27)
               x <- make_sfc (list (x1, x2), type = "LINESTRING")
               y <- sf::st_sfc (sf::st_linestring (x1), sf::st_linestring (x2))
               expect_identical (x, y)
})

test_that ("sf-multiple-lines", {
               x1 <- cbind (1:4, 5:8)
               x2 <- cbind (11:13, 25:27)
               x <- make_sfc (list (x1, x2), type = "LINESTRING")
               y <- sf::st_sf (x)
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sf-multiple-lines-with-fields", {
               x1 <- cbind (1:4, 5:8)
               x2 <- cbind (11:13, 25:27)
               x <- sf::st_sfc (sf::st_linestring (x1), sf::st_linestring (x2))
               y <- sf::st_sf (x, a = 1:2, b = "blah", stringsAsFactors = FALSE)
               x <- make_sfc (list (x1, x2), type = "LINESTRING")
               x <- make_sf (x, a = 1:2, b = "blah")
               expect_identical (x, y)
               x <- sf::st_sfc (sf::st_linestring (x1), sf::st_linestring (x2))
               dat <- data.frame (a = 1:2, b = c("blah", "junk"),
                                  c = c (TRUE, FALSE))
               y <- sf::st_sf (x, dat)
               x <- make_sfc (list (x1, x2), type = "LINESTRING")
               x <- make_sf (x, dat)
               expect_identical (x, y)
})

# **********************************************************
# ***                      POLYGONS                      ***
# **********************************************************

test_that ("sfg-polygon", {
               # NOTE: polygons are lists; linestrings are not!
               xy <- list (cbind (c (1:4, 1), c(5:8, 5)))
               x <- structure (xy, class = c("XY", "POLYGON", "sfg"))
               expect_identical (x, sf::st_polygon (xy))
})

test_that ("sfc-polygon", {
               xy <- cbind (c (1:4, 1), c(5:8, 5))
               x <- make_sfc (xy, "POLYGON")
               y <- sf::st_sfc (sf::st_polygon (list (xy)))
               expect_identical (x, y)
})

test_that ("sf-polygon", {
               xy <- cbind (c (1:4, 1), c(5:8, 5))
               x <- make_sfc (xy, "POLYGON")
               y <- sf::st_sf (x)
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sf-polygon-with-fields", {
               xy <- cbind (c (1:4, 1), c(5:8, 5))
               x <- make_sfc (xy, "POLYGON")
               y <- sf::st_sf (x, a = 3, b = "blah", stringsAsFactors = FALSE)
               x <- make_sf (x, a = 3, b = "blah")
               expect_identical (x, y)
})

test_that ("sfc-multiple-polygons", {
               xy1 <- cbind (c (1:4, 1), c(5:8, 5))
               xy2 <- cbind (c (11:14, 11), c(15:18, 15))
               x <- make_sfc (list (xy1, xy2), type = "POLYGON")
               y <- sf::st_sfc (sf::st_polygon (list (xy1)),
                                sf::st_polygon (list (xy2)))
               expect_identical (x, y)
})

test_that ("sf-multiple-polygons", {
               xy1 <- cbind (c (1:4, 1), c(5:8, 5))
               xy2 <- cbind (c (11:14, 11), c(15:18, 15))
               x <- make_sfc (list (xy1, xy2), type = "POLYGON")
               y <- sf::st_sf (x)
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sf-multiple-polygons-with-fields", {
               xy1 <- cbind (c (1:4, 1), c(5:8, 5))
               xy2 <- cbind (c (11:14, 11), c(15:18, 15))
               x <- sf::st_sfc (sf::st_polygon (list (xy1)),
                                sf::st_polygon (list (xy2)))
               y <- sf::st_sf (x, a = 1:2, b = "blah", stringsAsFactors = FALSE)
               x <- make_sfc (list (xy1, xy2), type = "POLYGON")
               x <- make_sf (x, a = 1:2, b = "blah")
               expect_identical (x, y)
               x <- sf::st_sfc (sf::st_polygon (list (xy1)),
                                sf::st_polygon (list (xy2)))
               dat <- data.frame (a = 1:2, b = c("blah", "junk"),
                                  c = c (TRUE, FALSE))
               y <- sf::st_sf (x, dat)
               x <- make_sfc (list (xy1, xy2), type = "POLYGON")
               x <- make_sf (x, dat)
               expect_identical (x, y)
})

# **********************************************************
# ***                  MULTILINESTRINGS                  ***
# **********************************************************

test_that ("sfg-multilinestring", {
               x <- cbind (c (1:4, 1), c (5:8, 5))
               y <- sf::st_multilinestring (list (x))
               x <- structure (list (x),
                               class = c ("XY", "MULTILINESTRING", "sfg"))
               expect_identical (x, y)
})

test_that ("sfc-multilinestring", {
               x <- cbind (c (1:4, 1), c (5:8, 5))
               y <- sf::st_sfc (sf::st_multilinestring (list (x)))
               x <- make_sfc (x, type = "MULTILINESTRING")
               expect_identical (x, y)
})

test_that ("sf-multilinestring", {
               x <- make_sfc (cbind (c (1:4, 1), c (5:8, 5)),
                              type = "MULTILINESTRING")
               y <- sf::st_sf (x)
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sfc-multiple-multilinestring1", {
               x1 <- cbind (c (1:4, 1), c (5:8, 5))
               x2 <- cbind (c (11:13, 11), c (25:27, 25))
               x <- make_sfc (list (x1, x2), type = "MULTILINESTRING")
               y <- sf::st_sfc (sf::st_multilinestring (list (x1, x2)))
               expect_identical (x, y)
})

test_that ("sfc-multiple-multilinestring2", {
               x1 <- cbind (c (1:4, 1), c (5:8, 5))
               x2 <- cbind (c (11:13, 11), c (25:27, 25))
               x <- make_sfc (list (list (x1, x2), list (x1, x2)),
                              type = "MULTILINESTRING")
               y <- sf::st_sfc (sf::st_multilinestring (list (x1, x2)),
                                sf::st_multilinestring (list (x1, x2)))
               expect_identical (x, y)
})

test_that ("sf-multiple-multilinestring", {
               x1 <- cbind (c (1:4, 1), c (5:8, 5))
               x2 <- cbind (c (11:13, 11), c (25:27, 25))
               x <- make_sfc (list (x1, x2), type = "MULTILINESTRING")
               y <- sf::st_sf (x)
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sf-multilinestring-with-fields", {
               x1 <- cbind (c (1:4, 1), c (5:8, 5))
               x2 <- cbind (c (11:13, 11), c (25:27, 25))
               x0 <- c (make_sfc (list (x1, x2), type = "MULTILINESTRING"),
                        make_sfc (list (x2, x1), type = "MULTILINESTRING"))
               y0 <- sf::st_sfc (sf::st_multilinestring (list (x1, x2)),
                                 sf::st_multilinestring (list (x2, x1)))
               expect_identical (x0, y0)
               dat <- data.frame (a = 1:2, b = c("blah", "junk"))
               x1 <- make_sf (x0, dat)
               x2 <- make_sf (y0, dat)
               y1 <- sf::st_sf (x0, dat)
               y2 <- sf::st_sf (y0, dat)
               attr (x2, "sf_column") <- "x0"
               names (x2) <- c ("a", "b", "x0")
               attr (y2, "sf_column") <- "x0"
               names (y2) <- c ("a", "b", "x0")
               expect_identical (x1, x2)
               expect_identical (x1, y1)
               expect_identical (x1, y2)
               expect_identical (x2, y1)
               expect_identical (x2, y2)
               expect_identical (y1, y2)

               y3 <- sf::st_sf (dat, x0)
               expect_identical (x1, y3)
               expect_identical (x2, y3)
               expect_identical (y1, y3)
               expect_identical (y2, y3)
               x3 <- make_sf (dat, x0)
               expect_identical (x1, x3)
               expect_identical (x2, x3)
               expect_identical (y1, x3)
               expect_identical (y2, x3)
               expect_identical (y3, x3)
})


# **********************************************************
# ***                   MULTIPOLYGONS                    ***
# **********************************************************

test_that ("sfg-multipolygon", {
               x <- cbind (c (1:4, 1), c (5:8, 5))
               y <- sf::st_multipolygon (list (list (x)))
               x <- structure (list (list (x)),
                               class = c ("XY", "MULTIPOLYGON", "sfg"))
               expect_identical (x, y)
})

test_that ("sfc-multipolygon", {
               x <- cbind (c (1:4, 1), c (5:8, 5))
               y <- sf::st_sfc (sf::st_multipolygon (list (list (x))))
               x <- make_sfc (x, type = "MULTIPOLYGON")
               expect_identical (x, y)
})

test_that ("sf-multipolygon", {
               x <- make_sfc (cbind (c (1:4, 1), c (5:8, 5)),
                              type = "MULTIPOLYGON")
               y <- sf::st_sf (x)
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sfc-multiple-multipolygons1", {
               x1 <- cbind (c (1:4, 1), c (5:8, 5))
               x2 <- cbind (c (11:13, 11), c (25:27, 25))
               x <- make_sfc (list (x1, x2), type = "MULTIPOLYGON")
               y <- sf::st_sfc (sf::st_multipolygon (list (list (x1, x2))))
               expect_identical (x, y)
})

test_that ("sfc-multiple-multipolygons2", {
               x1 <- cbind (c (1:4, 1), c (5:8, 5))
               x2 <- cbind (c (11:13, 11), c (25:27, 25))
               x <- make_sfc (list (list (x1, x2), list (x1, x2)),
                              type = "MULTIPOLYGON")
               y <- sf::st_sfc (sf::st_multipolygon (list (list (x1, x2))),
                                sf::st_multipolygon (list (list (x1, x2))))
               expect_identical (x, y)
})

test_that ("sf-multiple-multipolygons", {
               x1 <- cbind (c (1:4, 1), c (5:8, 5))
               x2 <- cbind (c (11:13, 11), c (25:27, 25))
               x <- make_sfc (list (x1, x2), type = "MULTIPOLYGON")
               y <- sf::st_sf (x)
               x <- make_sf (x)
               expect_identical (x, y)
})

test_that ("sf-multipolygon-with-fields", {
               x1 <- cbind (c (1:4, 1), c (5:8, 5))
               x2 <- cbind (c (11:13, 11), c (25:27, 25))
               x0 <- c (make_sfc (list (x1, x2), type = "MULTIPOLYGON"),
                        make_sfc (list (x2, x1), type = "MULTIPOLYGON"))
               y0 <- sf::st_sfc (sf::st_multipolygon (list (list (x1, x2))),
                                 sf::st_multipolygon (list (list (x2, x1))))
               expect_identical (x0, y0)
               dat <- data.frame (a = 1:2, b = c("blah", "junk"))
               x1 <- make_sf (x0, dat)
               x2 <- make_sf (y0, dat)
               y1 <- sf::st_sf (x0, dat)
               y2 <- sf::st_sf (y0, dat)
               attr (x2, "sf_column") <- "x0"
               names (x2) <- c ("a", "b", "x0")
               attr (y2, "sf_column") <- "x0"
               names (y2) <- c ("a", "b", "x0")
               expect_identical (x1, x2)
               expect_identical (x1, y1)
               expect_identical (x1, y2)
               expect_identical (x2, y1)
               expect_identical (x2, y2)
               expect_identical (y1, y2)

               y3 <- sf::st_sf (dat, x0)
               expect_identical (x1, y3)
               expect_identical (x2, y3)
               expect_identical (y1, y3)
               expect_identical (y2, y3)
               x3 <- make_sf (dat, x0)
               expect_identical (x1, x3)
               expect_identical (x2, x3)
               expect_identical (y1, x3)
               expect_identical (y2, x3)
               expect_identical (y3, x3)
})

} # end if test_all
