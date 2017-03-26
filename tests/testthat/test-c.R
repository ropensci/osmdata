context ("c")

test_that ("c-method", {
               q <- opq (bbox = c(1, 1, 5, 5))
               x1 <- osmdata_sf (q, "../osm-multi.osm")
               x2 <- osmdata_sf (q, "../osm-ways.osm")
               x <- c (x1, x2)
               osm_indx <- which (grepl ('osm_', names (x)))
               for (i in osm_indx)
               {
                   expect_true (nrow (x [[i]]) >= nrow (x1 [[i]]))
                   expect_true (nrow (x [[i]]) >= nrow (x2 [[i]]))
               }
})
