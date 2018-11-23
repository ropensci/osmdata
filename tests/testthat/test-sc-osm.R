context ("sc-osm")

# test_all used to switch off tests on CRAN
test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))
             #identical (Sys.getenv ("APPVEYOR"), "True"))

test_that ("multipolygon", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sc (q0, "../osm-multi.osm")
               # TODO: Write proper tests
               expect_is (x, "SC")
               expect_equal (names (x), c ("object", "object_link_edge", "edge", "vertex", "meta"))
})


test_that ("ways", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sc (q0, "../osm-ways.osm")
               expect_is (x, "SC")
               expect_equal (names (x), c ("object", "object_link_edge", "edge", "vertex", "meta"))
})
