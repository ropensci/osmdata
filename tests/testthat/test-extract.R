context ("extract-objects")

# ------------------- void values
test_that ('osm_points-void', {
               expect_error (osm_points (),
                             'osm_points can not be extracted without data')
               expect_error (osm_points (1),
                             'id must be given to extract points')
               expect_error (osm_points (1, 1),
                             'dat must be of class osmdata')
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               expect_error (osm_points (x),
                             'id must be given to extract points')
               expect_error (osm_points (id = x),
                             'osm_points can not be extracted without data')
               expect_error (osm_points (x, id = x),
                             'id must be of class character or numeric')
})

test_that ('osm_lines-void', {
               expect_error (osm_lines (),
                             'osm_lines can not be extracted without data')
               expect_error (osm_lines (1),
                             'id must be given to extract lines')
               expect_error (osm_lines (1, 1),
                             'dat must be of class osmdata')
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               expect_error (osm_lines (x),
                             'id must be given to extract lines')
               expect_error (osm_lines (id = x),
                             'osm_lines can not be extracted without data')
               expect_error (osm_lines (x, id = x),
                             'id must be of class character or numeric')
})

test_that ('osm_polygons-void', {
               expect_error (osm_polygons (),
                             'osm_polygons can not be extracted without data')
               expect_error (osm_polygons (1),
                             'id must be given to extract polygons')
               expect_error (osm_polygons (1, 1),
                             'dat must be of class osmdata')
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               expect_error (osm_polygons (x),
                             'id must be given to extract polygons')
               expect_error (osm_polygons (id = x),
                             'osm_polygons can not be extracted without data')
               expect_error (osm_polygons (x, id = x),
                             'id must be of class character or numeric')
})

test_that ('osm_multilines-void', {
               expect_error (osm_multilines (),
                             'osm_multilines can not be extracted without data')
               expect_error (osm_multilines (1),
                             'id must be given to extract multilines')
               expect_error (osm_multilines (1, 1),
                             'dat must be of class osmdata')
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               expect_error (osm_multilines (x),
                             'id must be given to extract multilines')
               expect_error (osm_multilines (id = x),
                             'osm_multilines can not be extracted without data')
               expect_error (osm_multilines (x, id = x),
                             'id must be of class character or numeric')
})

test_that ('osm_multipolygons-void', {
               expect_error (osm_multipolygons (),
                         'osm_multipolygons can not be extracted without data')
               expect_error (osm_multipolygons (1),
                             'id must be given to extract multipolygons')
               expect_error (osm_multipolygons (1, 1),
                             'dat must be of class osmdata')
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               expect_error (osm_multipolygons (x),
                             'id must be given to extract multipolygons')
               expect_error (osm_multipolygons (id = x),
                         'osm_multipolygons can not be extracted without data')
               expect_error (osm_multipolygons (x, id = x),
                             'id must be of class character or numeric')
})

# ------------------- points

test_that ("points-from-multipolygons", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               pts <- osm_points (x, rownames (x$osm_multipolygons))
               expect_equal (dim (pts), c (16, 5))
})

test_that ("points-from-multilines", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               pts <- osm_points (x, rownames (x$osm_multilines))
               expect_equal (dim (pts), c (10, 5))
})

test_that ("points-from-polygons", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               pts <- osm_points (x, rownames (x$osm_polygons))
               expect_equal (dim (pts), c (4, 5))
})

test_that ("points-from-lines", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               pts <- osm_points (x, rownames (x$osm_lines))
               expect_equal (dim (pts), c (12, 5))

               # Only lines have multiples features
               ids <- lapply (seq (x$osm_lines$geometry), function (i)
                      rownames (osm_points (x, rownames (x$osm_lines) [i])))
               ids <- sort (unique (as.vector (unlist (ids))))
               ids_all <- sort (rownames (osm_points (x,
                                                  rownames (x$osm_lines))))
               expect_identical (ids, ids_all)
})

# ------------------- lines

test_that ("lines-from-multipolygons", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               lns <- osm_lines (x, rownames (x$osm_multipolygons))
               expect_equal (dim (lns), c (4, 7))
})

test_that ("lines-from-multilines", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               lns <- osm_lines (x, rownames (x$osm_multilines))
               expect_equal (dim (lns), c (3, 7))
})

test_that ("lines-from-lines", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               lns <- osm_lines (x, rownames (x$osm_lines) [1])
               expect_equal (dim (lns), c (3, 7))
})

test_that ("lines-from-points", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               lns <- osm_lines (x, rownames (x$osm_points) [1])
               expect_equal (dim (lns), c (2, 7))
})

# ------------------- polygons

test_that ("polygons-from-multipolygons", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               pls <- osm_polygons (x, rownames (x$osm_multipolygons))
               expect_equal (dim (pls), c (1, 7))
})

test_that ("polygons-from-multilines", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               expect_error (osm_polygons (x, rownames (x$osm_multilines)),
                     'MULTILINESTRINGS do not contain polygons by definition')
})

test_that ("polygons-from-lines", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               pls <- osm_polygons (x, rownames (x$osm_lines) [1])
               expect_equal (dim (pls), c (0, 7)) # no polygons contain lines
})

test_that ("polygons-from-points", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               pls <- osm_polygons (x, rownames (x$osm_points) [8])
               expect_equal (dim (pls), c (1, 7))
})

# ------------------- multilines

test_that ("multilines-from-lines", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               mls <- osm_multilines (x, rownames (x$osm_lines) [1])
               expect_equal (dim (mls), c (1, 6))
})

test_that ("multilines-from-points", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               mls <- osm_multilines (x, rownames (x$osm_points) [1])
               expect_equal (dim (mls), c (1, 6))
})

# ------------------- multipolygons

test_that ("multipolygons-from-polygons", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               mps <- osm_multipolygons (x, rownames (x$osm_polygons) [1])
               expect_equal (dim (mps), c (1, 5))
})

test_that ("multipolygons-from-lines", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               mps <- osm_multipolygons (x, rownames (x$osm_lines) [2])
               expect_equal (dim (mps), c (1, 5))
})

test_that ("multipolygons-from-points", {
               q0 <- opq (bbox = c(1, 1, 5, 5))
               x <- osmdata_sf (q0, "../osm-multi.osm")
               mps <- osm_multipolygons (x, rownames (x$osm_points) [1])
               expect_equal (dim (mps), c (1, 5))
})
