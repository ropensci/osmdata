context ("trim-osm-data")

require (sf)

test_that ('trim_osm_data', {
               x0 <- osmdata_sf (q0, "../osm-multi.osm")
               x1 <- trim_osmdata (x, bb_poly = cbind (c (2, 3), c (2, 3)))
               expect_true (!identical (x0, x1))
               # trim converts the polygon to a linestring, but for the ways,
               # all objects extend through the trim bb_poly and out, so nothing
               # is trimmed.

               x0 <- osmdata_sf (q0, "../osm-ways.osm")
               x1 <- trim_osmdata (x, bb_poly = cbind (c (2, 3), c (2, 3)))
               expect_identical (x0, x1)
})
