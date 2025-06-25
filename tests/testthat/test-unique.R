context ("unique-osm-data")

require (sf)

test_that ("unique sf", {
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x0 <- osmdata_sf (q0, test_path ("fixtures", "osm-multi.osm"))
    x1 <- unique_osmdata (x0)
    expect_true (!identical (x0, x1))
    expect_true (nrow (x0$osm_points) > nrow (x1$osm_points))
    # trim converts the polygon to a linestring, but for the ways,
    # all objects extend through the trim bb_poly and out, so nothing
    # is trimmed.

    x0 <- osmdata_sf (q0, test_path ("fixtures", "osm-ways.osm"))
    x1 <- unique_osmdata (x0)
    expect_true (!identical (x0, x1))
    expect_true (nrow (x0$osm_points) > nrow (x1$osm_points))
})

test_that ("unique sp", {
    q0 <- opq (bbox = c (1, 1, 5, 5))
    expect_warning (
        x0 <- osmdata_sp (q0, test_path ("fixtures", "osm-multi.osm")),
        "Deprecated"
    )
    x1 <- unique_osmdata (x0)
    expect_true (!identical (x0, x1))
    expect_true (nrow (x0$osm_points) > nrow (x1$osm_points))
    # trim converts the polygon to a linestring, but for the ways,
    # all objects extend through the trim bb_poly and out, so nothing
    # is trimmed.

    expect_warning (
        x0 <- osmdata_sp (q0, test_path ("fixtures", "osm-ways.osm")),
        "Deprecated"
    )
    # x1 <- unique_osmdata (x0)
    # expect_true (!identical (x0, x1))
    # expect_true (nrow (x0$osm_points) > nrow (x1$osm_points))
})
