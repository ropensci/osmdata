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
                   if (!is.null (x2 [[i]])) 
                       expect_true (nrow (x [[i]]) >= nrow (x2 [[i]]))
               }
})

test_that ("poly2line", {
                q <- opq (bbox = c(1, 1, 5, 5))
                x <- osmdata_sf (q, "../osm-multi.osm")
                nold <- nrow (x$osm_lines)
                x <- osm_poly2line (x)
                nnew <- nrow (x$osm_lines)
                expect_identical (nrow (x$osm_polygons), nnew - nold)
})
