context ("sf-osm")

test_that ("multipolygon", {
               x_sf <- sf::st_read ("../osm-multi.osm",
                                    layer = "multipolygons", quiet = TRUE)
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")$osm_multipolygons
               # GDAL spits out a whole lot of generic field names, so first the
               # two have to be reduced to common fields.
               x <- x [, which (names (x) %in% names (x_sf))]
               x_sf <- x_sf [, which (names (x_sf) %in% names (x))]
               # Then all of the object and dimnames inserted by `osmdata` have
               # to be removed
               rownames (x) <- rownames (x_sf)
               # but sf now also inserts default row.names that are numeric
               # rather than character, so
               class (attributes (x)$row.names) <- "integer"
               for (i in seq (length (x$geometry [[1]])))
               {
                   names (x$geometry [[1]] [[i]]) <- NULL
                   for (j in seq (length (x$geometry [[1]] [[i]])))
                       dimnames (x$geometry [[1]] [[i]] [[j]]) <- NULL
               }
               names (x$geometry) <- NULL
               expect_identical (x, x_sf)
})


test_that ("multilinestring", {
               x_sf <- sf::st_read ("../osm-multi.osm",
                                    layer = "multilinestrings", quiet = TRUE)
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")$osm_multilines
               x <- x [, which (names (x) %in% names (x_sf))]
               x_sf <- x_sf [, which (names (x_sf) %in% names (x))]
               rownames (x_sf) <- rownames (x)
               names (x$geometry [[1]]) <- NULL
               for (i in seq (length (x$geometry [[1]])))
               {
                   names (x$geometry [[1]] [[i]]) <- NULL
                   dimnames (x$geometry [[1]] [[i]]) <- NULL
               }
               names (x$geometry) <- NULL
               expect_identical (x, x_sf)
})

test_that ("ways", {
               x_sf <- sf::st_read ("../osm-ways.osm",
                                    layer = "lines", quiet = TRUE)
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-ways.osm")$osm_lines
               x <- x [, which (names (x) %in% names (x_sf))]
               x_sf <- x_sf [, which (names (x_sf) %in% names (x))]
               rownames (x_sf) <- rownames (x)
               names (x$geometry) <- NULL
               for (i in seq (x$geometry))
                   dimnames (x$geometry [[i]]) <- NULL
               # Then names also need to be removed from each non-sfc column
               for (i in 1:(ncol (x) - 1))
                   names (x [[names (x)[i] ]]) <- NULL
               # These last lines change the order of attributes, # so they are
               # reset here
               attributes (x) <- attributes (x) [match (attributes (x_sf),
                                                        attributes (x))]
               expect_identical (x, x_sf)
})
