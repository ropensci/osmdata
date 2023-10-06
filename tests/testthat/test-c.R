context ("c")

test_that ("c-method", {

    # osmdata_sf:
    q <- opq (bbox = c (1, 1, 5, 5))
    x1 <- osmdata_sf (q, test_path ("fixtures", "osm-multi.osm"))
    x2 <- osmdata_sf (q, test_path ("fixtures", "osm-ways.osm"))
    x <- c (x1, x2)
    osm_indx <- which (grepl ("osm_", names (x)))
    for (i in osm_indx) {
        expect_true (nrow (x [[i]]) >= nrow (x1 [[i]]))
        if (!is.null (x2 [[i]])) {
            expect_true (nrow (x [[i]]) >= nrow (x2 [[i]]))
        }
    }

    # osmdata_sc:
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x1 <- osmdata_sc (q0, test_path ("fixtures", "osm-multi.osm"))
    x2 <- osmdata_sc (q0, test_path ("fixtures", "osm-ways.osm"))
    x12 <- c (x1, x2)
    n1 <- vapply (x1, nrow, integer (1L))
    n2 <- vapply (x2, nrow, integer (1L))
    n12 <- vapply (x12, nrow, integer (1L))
    # There is some redundancy in the data, so some n12 == n1 | n2:
    expect_true (all (n12 >= n1 & n12 >= n2))
    expect_true (any (n12 > n1 & n12 > n2))
})


test_that ("poly2line", {
    q <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_sf (q, test_path ("fixtures", "osm-multi.osm"))
    nold <- nrow (x$osm_lines)
    x <- osm_poly2line (x)
    nnew <- nrow (x$osm_lines)
    expect_identical (nrow (x$osm_polygons), nnew - nold)
})
