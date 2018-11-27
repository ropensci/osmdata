context ("trim-osm-data")

require (sf)

test_that ('trim_osm_data', {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x0 <- osmdata_sf (q0, "../osm-multi.osm")
               x1 <- trim_osmdata (x0, bb_poly = cbind (c (2, 3), c (2, 3)))
               expect_identical (x0, x1)

               x0 <- osmdata_sf (q0, "../osm-ways.osm")
               x1 <- trim_osmdata (x0, bb_poly = cbind (c (2, 3), c (2, 3)))
               expect_identical (x0, x1)
})
