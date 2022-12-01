context ("data.frame-osm")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
    identical (Sys.getenv ("GITHUB_WORKFLOW"), "test-coverage"))

test_that ("multipolygon", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")
    x_sf <- sf::st_read (
        osm_multi,
        layer = "multipolygons",
        stringsAsFactors = FALSE,
        quiet = TRUE
    )
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_data.frame (q0, osm_multi)

    # GDAL spits out a whole lot of generic field names, so first the
    # two have to be reduced to common fields.
    x_sf <- sf::st_drop_geometry (x_sf)
    x <- x [, which (names (x) %in% names (x_sf))]
    x_sf <- x_sf [, which (names (x_sf) %in% names (x))]

    expect_identical (names (x), names (x_sf))
    expect_true (x_sf$osm_id %in% x$osm_id)
    expect_true (x_sf$name %in% x$name)
    expect_true (x_sf$type %in% x$type)
})


test_that ("multilinestring", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")
    x_sf <- sf::st_read (
        osm_multi,
        layer = "multilinestrings",
        stringsAsFactors = FALSE,
        quiet = TRUE
    )
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_data.frame (q0, osm_multi)
    x_sf <- sf::st_drop_geometry (x_sf)
    x <- x [, which (names (x) %in% names (x_sf))]
    x_sf <- x_sf [, which (names (x_sf) %in% names (x))]

    expect_identical (names (x), names (x_sf))
    expect_true (x_sf$osm_id %in% x$osm_id)
    expect_true (x_sf$name %in% x$name)
    expect_true (x_sf$type %in% x$type)
})

test_that ("ways", {
    osm_ways <- test_path ("fixtures", "osm-ways.osm")
    x_sf <- sf::st_read (
        osm_ways,
        layer = "lines",
        stringsAsFactors = FALSE,
        quiet = TRUE
    )
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_data.frame (q0, osm_ways)
    x_sf <- sf::st_drop_geometry (x_sf)
    x <- x [, which (names (x) %in% names (x_sf))]
    x_sf <- x_sf [, which (names (x_sf) %in% names (x))]

    expect_setequal (names (x), names (x_sf))
    expect_true (all (x_sf$osm_id %in% x$osm_id))
    expect_true (all (x_sf$name %in% x$name))
    expect_true (all (x_sf$highway %in% x$highway))
})
