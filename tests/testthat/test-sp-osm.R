context ("sp-osm")

test_that ("multipolygon", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")
    x_sf <- sf::st_read (osm_multi, layer = "multipolygons", quiet = TRUE)
    x_sp <- as (x_sf, "Spatial")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_sp (q0, osm_multi)$osm_multipolygons
    # GDAL spits out a whole lot of generic field names, so first the
    # two have to be reduced to common fields.
    x <- x [, which (names (x) %in% names (x_sp))]
    x_sp <- x_sp [, which (names (x_sp) %in% names (x))]
    # Then all of the object and dimnames inserted by `osmdata` have
    # to be removed
    rownames (slot (x, "data")) <- rownames (slot (x_sp, "data"))
    # crs arguments for x_sp include "+ellps=WGS84", while the
    # corresponding value for x (the osmdata version) is
    # "+datum=WGS84".
    slot (x, "proj4string") <- slot (x_sp, "proj4string")
    # Then, as for sf, all of the object and dimnames inserted by
    # `osmdata` have to be removed
    names (slot (x, "polygons")) <- NULL
    names (slot (slot (x, "polygons") [[1]], "Polygons")) <- NULL
    np <- length (slot (slot (x, "polygons") [[1]], "Polygons"))
    for (i in seq (np)) {
        rownames (slot (slot (
            slot (x, "polygons") [[1]],
            "Polygons"
        ) [[i]], "coords")) <- NULL
        colnames (slot (slot (
            slot (x, "polygons") [[1]],
            "Polygons"
        ) [[i]], "coords")) <- NULL
        dimnames (slot (slot (
            slot (x, "polygons") [[1]],
            "Polygons"
        ) [[i]], "coords")) <- NULL
    }
    # sp arbitrarily re-sorts the coordinates, so the following
    # always fails:
    for (i in seq (np)) {
        pi <- slot (slot (x, "polygons") [[1]], "Polygons") [[i]]
        pi_sp <- slot (
            slot (x_sp, "polygons") [[1]],
            "Polygons"
        ) [[i]]
        xyi <- slot (pi, "coords")
        xyi_sp <- slot (pi_sp, "coords")
        # expect_identical (xyi, xyi_sp)
        expect_identical (attributes (xyi), attributes (xyi_sp))
    }

    # sp also inserts row.names in the "data" slot of type integer
    # instead of char, so those slots can't be compared either
    # ... sp tests are not continued any further, and these tests
    # really just exist to cover the relevant lines of code.
})


test_that ("multilinestring", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")
    x_sf <- sf::st_read (osm_multi, layer = "multilinestrings", quiet = TRUE)
    x_sp <- as (x_sf, "Spatial")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_sp (q0, osm_multi)$osm_multilines
    x <- x [, which (names (x) %in% names (x_sp))]
    x_sp <- x_sp [, which (names (x_sp) %in% names (x))]
    rownames (slot (x, "data")) <- rownames (slot (x_sp, "data"))
    slot (x, "proj4string") <- slot (x_sp, "proj4string")
    names (slot (x, "lines")) <- NULL
    names (slot (slot (x, "lines") [[1]], "Lines")) <- NULL
    np <- length (slot (slot (x, "lines") [[1]], "Lines"))
    for (i in seq (np)) {
        rownames (slot (slot (
            slot (x, "lines") [[1]],
            "Lines"
        ) [[i]], "coords")) <- NULL
        colnames (slot (slot (
            slot (x, "lines") [[1]],
            "Lines"
        ) [[i]], "coords")) <- NULL
        dimnames (slot (slot (
            slot (x, "lines") [[1]],
            "Lines"
        ) [[i]], "coords")) <- NULL
    }
    for (i in seq (np)) {
        pi <- slot (slot (x, "lines") [[1]], "Lines") [[i]]
        pi_sp <- slot (slot (x_sp, "lines") [[1]], "Lines") [[i]]
        xyi <- slot (pi, "coords")
        xyi_sp <- slot (pi_sp, "coords")
        expect_identical (attributes (xyi), attributes (xyi_sp))
    }
})

test_that ("ways", {
    osm_ways <- test_path ("fixtures", "osm-ways.osm")
    x_sf <- sf::st_read (osm_ways, layer = "lines", quiet = TRUE)
    x_sp <- as (x_sf, "Spatial")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_sp (q0, osm_ways)$osm_lines
    x <- x [, which (names (x) %in% names (x_sp))]
    x_sp <- x_sp [, which (names (x_sp) %in% names (x))]
    np <- length (slot (slot (x, "lines") [[1]], "Lines"))
    for (i in seq (np)) {
        rownames (slot (slot (
            slot (x, "lines") [[1]],
            "Lines"
        ) [[i]], "coords")) <- NULL
        colnames (slot (slot (
            slot (x, "lines") [[1]],
            "Lines"
        ) [[i]], "coords")) <- NULL
        dimnames (slot (slot (
            slot (x, "lines") [[1]],
            "Lines"
        ) [[i]], "coords")) <- NULL
    }
    for (i in seq (np)) {
        pi <- slot (slot (x, "lines") [[1]], "Lines") [[i]]
        pi_sp <- slot (slot (x_sp, "lines") [[1]], "Lines") [[i]]
        xyi <- slot (pi, "coords")
        xyi_sp <- slot (pi_sp, "coords")
        expect_identical (attributes (xyi), attributes (xyi_sp))
    }
})

test_that ("non-valid key names", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_sp (q0, osm_multi)

    k <- lapply (x[grep ("osm_", names (x))], function (f) {
        expect_true("name:ca" %in% names(f))
    })
})

test_that ("clashes in key names", {
    osm_multi_key_clashes <- test_path ("fixtures", "osm-key_clashes.osm")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    expect_warning(
        x <- osmdata_sp (q0, osm_multi_key_clashes),
        "Feature keys clash with id or metadata columns and will be renamed by "
    )

    expect_false (any (duplicated (names (x$osm_points))))
    # x$osm_points don't have osm_id column in tags TODO?
    k <- lapply (x[grep ("osm_", names (x))[-1]], function (f) {
        expect_false (any (duplicated (names (f))))
        expect_true (all (c ("osm_id", "osm_id.1") %in% names (f)))
    })
})
