context ("trim-osm-data")


test_that ('trim_osm_data', {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x0 <- osmdata_sf (q0, "../osm-multi.osm")
               expect_message (x1 <- trim_osmdata (x0,
                                    bb_poly = cbind (c (2, 3), c (2, 3))),
                       "It is generally necessary to pre-load the sf package")
               require (sf)
               expect_silent (x1 <- trim_osmdata (x0,
                                    bb_poly = cbind (c (2, 3), c (2, 3))))

               expect_identical (x0, x1)

               bb <- list (cbind (c (0, 0),
                                  c (0, 1),
                                  c (1, 1),
                                  c (1, 0),
                                  c (0, 0)),
                           cbind (c (2, 3),
                                  c (2, 4),
                                  c (3, 4),
                                  c (3, 3),
                                  c (2, 3)))

               expect_message (x1 <- trim_osmdata (x0, bb_poly = bb),
                               "bb_poly has more than one polygon")
               expect_identical (x0, x1)
})
