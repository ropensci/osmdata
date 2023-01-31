context ("sf-osm")

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
    x <- osmdata_sf (q0, osm_multi)$osm_multipolygons

    # GDAL spits out a whole lot of generic field names, so first the
    # two have to be reduced to common fields.
    x <- x [, which (names (x) %in% names (x_sf))]
    x_sf <- x_sf [, which (names (x_sf) %in% names (x))]
    # Then all of the object and dimnames inserted by `osmdata` have
    # to be removed
    rownames (x) <- rownames (x_sf)
    # but sf now also inserts default row.names that are numeric
    # rather than character, so
    class (attributes (x)$row.names) <- "integer"
    for (i in seq (length (x$geometry [[1]]))) {
        names (x$geometry [[1]] [[i]]) <- NULL
        for (j in seq (length (x$geometry [[1]] [[i]]))) {
            dimnames (x$geometry [[1]] [[i]] [[j]]) <- NULL
        }
    }
    names (x$geometry) <- NULL
    # CRS check fails on some R-devel windows machines
    # expect_identical (x, x_sf)
    expect_identical (names (x), names (x_sf))
    expect_identical (x$osm_id, x_sf$osm_id)
    expect_identical (x$name, x_sf$name)
    expect_identical (x$type, x_sf$type)
    g <- x$geometry
    g_sf <- x_sf$geometry
    attrs <- names (attributes (g))
    # if (!test_all) # CRS is no longer idencial because x has
    # proj4strin
    attrs <- attrs [attrs != "crs"]
    for (a in attrs) {
        expect_identical (attr (g, a), attr (g_sf, a))
    }
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
    x <- osmdata_sf (q0, osm_multi)$osm_multilines
    x <- x [, which (names (x) %in% names (x_sf))]
    x_sf <- x_sf [, which (names (x_sf) %in% names (x))]
    rownames (x_sf) <- rownames (x)
    names (x$geometry [[1]]) <- NULL
    for (i in seq (length (x$geometry [[1]]))) {
        names (x$geometry [[1]] [[i]]) <- NULL
        dimnames (x$geometry [[1]] [[i]]) <- NULL
    }
    names (x$geometry) <- NULL
    # CRS check fails on some R-devel windows machines
    # expect_identical (x, x_sf)
    expect_identical (names (x), names (x_sf))
    expect_identical (x$osm_id, x_sf$osm_id)
    expect_identical (x$name, x_sf$name)
    expect_identical (x$type, x_sf$type)
    g <- x$geometry
    g_sf <- x_sf$geometry
    attrs <- names (attributes (g))
    # if (!test_all)
    attrs <- attrs [attrs != "crs"]
    for (a in attrs) {
        expect_identical (attr (g, a), attr (g_sf, a))
    }
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
    x <- osmdata_sf (q0, osm_ways)$osm_lines
    x <- x [, which (names (x) %in% names (x_sf))]
    x_sf <- x_sf [, which (names (x_sf) %in% names (x))]
    rownames (x_sf) <- rownames (x)
    names (x$geometry) <- NULL
    for (i in seq (x$geometry)) {
        dimnames (x$geometry [[i]]) <- NULL
    }
    # Then names also need to be removed from each non-sfc column
    for (i in 1:(ncol (x) - 1)) {
        names (x [[names (x) [i]]]) <- NULL
    } # nolint
    # These last lines change the order of attributes, # so they are
    # reset here
    attributes (x) <- attributes (x) [match (
        attributes (x_sf),
        attributes (x)
    )]
    # CRS check fails on some R-devel windows machines
    # expect_identical (x, x_sf)
    expect_identical (names (x), names (x_sf))
    expect_identical (x$osm_id, x_sf$osm_id)
    expect_identical (x$name, x_sf$name)
    expect_identical (x$type, x_sf$type)
    g <- x$geometry
    g_sf <- x_sf$geometry
    attrs <- names (attributes (g))
    # if (!test_all)
    attrs <- attrs [attrs != "crs"]
    for (a in attrs) {
        expect_identical (attr (g, a), attr (g_sf, a))
    }
})


test_that ("non-valid key names", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_sf (q0, osm_multi)

    k <- lapply (x[grep ("osm_", names(x))], function (f) {
        expect_true ("name:ca" %in% names (f))
    })
})

test_that ("clashes in key names", {
    osm_multi_key_clashes <- test_path ("fixtures", "osm-key_clashes.osm")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    expect_warning(
        x <- osmdata_sf (q0, osm_multi_key_clashes),
        "Feature keys clash with id or metadata columns and will be renamed by "
    )

    expect_false (any (duplicated (names (x$osm_points))))
    # x$osm_points don't have osm_id column in tags TODO?
    k <- lapply (x[grep ("osm_", names (x))[-1]], function (f) {
        expect_false (any (duplicated (names (f))))
        expect_true (all (c ("osm_id", "osm_id.1") %in% names (f)))
    })
})
