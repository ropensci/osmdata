context ("extract-objects")

test_that ("points-from-multipolygons", {
               q0 <- opq (bbox=c(1,1,5,5)) 
               x <- osmdata_sf (q0, "../osm-multi.osm")
               pts <- osm_points (x, rownames (x$osm_multipolygons))
               expect_equal (dim (pts), c (16, 4))
})

test_that ("points-from-multilines", {
               q0 <- opq (bbox=c(1,1,5,5)) 
               x <- osmdata_sf (q0, "../osm-multi.osm")
               pts <- osm_points (x, rownames (x$osm_multilines))
               expect_equal (dim (pts), c (10, 4))
})

test_that ("points-from-polygons", {
               q0 <- opq (bbox=c(1,1,5,5)) 
               x <- osmdata_sf (q0, "../osm-multi.osm")
               pts <- osm_points (x, rownames (x$osm_polygons))
               expect_equal (dim (pts), c (4, 4))
})

test_that ("points-from-lines", {
               q0 <- opq (bbox=c(1,1,5,5)) 
               x <- osmdata_sf (q0, "../osm-multi.osm")
               pts <- osm_points (x, rownames (x$osm_lines))
               expect_equal (dim (pts), c (12, 4))

               # Only lines have multiples features
               ids <- sapply (seq (x$osm_lines$geometry), function (i)
                              rownames (osm_points (x, 
                                                    rownames (x$osm_lines) [i])))
               ids <- sort (unique (as.vector (ids)))
               ids_all <- sort (rownames (osm_points (x, 
                                                      rownames (x$osm_lines))))
               expect_identical (ids, ids_all)
})

