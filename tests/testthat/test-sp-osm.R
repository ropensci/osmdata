context ("sp-osm")

test_that ("multipolygon", {
               x_sf <- sf::st_read ("../osm-multi.osm",
                                    layer = "multipolygons", quiet = TRUE)
               x_sp <- as (x_sf, "Spatial")
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sp (q0, "../osm-multi.osm")$osm_multipolygons
               # GDAL spits out a whole lot of generic field names, so first the
               # two have to be reduced to common fields.
               x <- x [, which (names (x) %in% names (x_sp))]
               x_sp <- x_sp [, which (names (x_sp) %in% names (x))]
               # Then all of the object and dimnames inserted by `osmdata` have
               # to be removed
               rownames (slot (x, "data")) <- rownames (slot (x_sp, "data"))
               # crs arguments for x_sp include "+ellps=WGS84", while the
               # corresponding value for x (the osmdata version) is
               # "+datum=WGS84".
               slot (x, "proj4string") <- slot (x_sp, "proj4string")
               # Then, as for sf, all of the object and dimnames inserted by
               # `osmdata` have to be removed
               names (slot (x, "polygons")) <- NULL
               names (slot (slot (x, "polygons")[[1]], "Polygons")) <- NULL
               np <- length (slot (slot (x, "polygons")[[1]], "Polygons"))
               for (i in seq (np))
               {
                   rownames (slot (slot (slot (x, "polygons")[[1]],
                                         "Polygons")[[i]], "coords")) <- NULL
                   colnames (slot (slot (slot (x, "polygons")[[1]],
                                         "Polygons")[[i]], "coords")) <- NULL
                   dimnames (slot (slot (slot (x, "polygons")[[1]],
                                         "Polygons")[[i]], "coords")) <- NULL
               }
               # sp arbitrarily re-sorts the coordinates, so the following
               # always fails:
               for (i in seq (np))
               {
                   pi <- slot (slot (x, "polygons")[[1]], "Polygons") [[i]]
                   pi_sp <- slot (slot (x_sp, "polygons")[[1]],
                                  "Polygons") [[i]]
                   xyi <- slot (pi, "coords")
                   xyi_sp <- slot (pi_sp, "coords")
                   #expect_identical (xyi, xyi_sp)
                   expect_identical (attributes (xyi), attributes (xyi_sp))
               }

               # sp also inserts row.names in the "data" slot of type integer
               # instead of char, so those slots can't be compared either
               # ... sp tests are not continued any further, and these tests
               # really just exist to cover the relevant lines of code.
})


test_that ("multilinestring", {
               x_sf <- sf::st_read ("../osm-multi.osm",
                                    layer = "multilinestrings", quiet = TRUE)
               x_sp <- as (x_sf, "Spatial")
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sp (q0, "../osm-multi.osm")$osm_multilines
               x <- x [, which (names (x) %in% names (x_sp))]
               x_sp <- x_sp [, which (names (x_sp) %in% names (x))]
               rownames (slot (x, "data")) <- rownames (slot (x_sp, "data"))
               slot (x, "proj4string") <- slot (x_sp, "proj4string")
               names (slot (x, "lines")) <- NULL
               names (slot (slot (x, "lines")[[1]], "Lines")) <- NULL
               np <- length (slot (slot (x, "lines")[[1]], "Lines"))
               for (i in seq (np))
               {
                   rownames (slot (slot (slot (x, "lines")[[1]],
                                         "Lines")[[i]], "coords")) <- NULL
                   colnames (slot (slot (slot (x, "lines")[[1]],
                                         "Lines")[[i]], "coords")) <- NULL
                   dimnames (slot (slot (slot (x, "lines")[[1]],
                                         "Lines")[[i]], "coords")) <- NULL
               }
               for (i in seq (np))
               {
                   pi <- slot (slot (x, "lines")[[1]], "Lines") [[i]]
                   pi_sp <- slot (slot (x_sp, "lines")[[1]], "Lines") [[i]]
                   xyi <- slot (pi, "coords")
                   xyi_sp <- slot (pi_sp, "coords")
                   expect_identical (attributes (xyi), attributes (xyi_sp))
               }
})

test_that ("ways", {
               x_sf <- sf::st_read ("../osm-ways.osm",
                                    layer = "lines", quiet = TRUE)
               x_sp <- as (x_sf, "Spatial")
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sp (q0, "../osm-ways.osm")$osm_lines
               x <- x [, which (names (x) %in% names (x_sp))]
               x_sp <- x_sp [, which (names (x_sp) %in% names (x))]
               np <- length (slot (slot (x, "lines")[[1]], "Lines"))
               for (i in seq (np))
               {
                   rownames (slot (slot (slot (x, "lines")[[1]],
                                         "Lines")[[i]], "coords")) <- NULL
                   colnames (slot (slot (slot (x, "lines")[[1]],
                                         "Lines")[[i]], "coords")) <- NULL
                   dimnames (slot (slot (slot (x, "lines")[[1]],
                                         "Lines")[[i]], "coords")) <- NULL
               }
               for (i in seq (np))
               {
                   pi <- slot (slot (x, "lines")[[1]], "Lines") [[i]]
                   pi_sp <- slot (slot (x_sp, "lines")[[1]], "Lines") [[i]]
                   xyi <- slot (pi, "coords")
                   xyi_sp <- slot (pi_sp, "coords")
                   expect_identical (attributes (xyi), attributes (xyi_sp))
               }
})
