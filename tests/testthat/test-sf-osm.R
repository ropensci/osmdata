test_all <- (identical (Sys.getenv ("MPADGE_LOCAL", "false"), "true") ||
    identical (Sys.getenv ("GITHUB_WORKFLOW", "nope"), "test-coverage"))

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


test_that ("out meta", {
    q <- opq_osm_id (id = "3278525", type = "relation", out = "meta")

    osm_meta <- test_path ("fixtures", "osm-meta_geom.osm")
    doc <- xml2::read_xml (osm_meta)

    x <- osmdata_sf (q, doc, quiet = FALSE)
    x_no_call <- osmdata_sf (doc = doc)

    cols <- c (
        "osm_id", "osm_version", "osm_timestamp",
        "osm_changeset", "osm_uid", "osm_user"
    )
    lapply (
        x [c ("osm_points", "osm_polygons", "osm_multipolygons")],
        function (sf) expect_named (as.data.frame (sf) [, 1:6], cols)
    )
    lapply (
        x_no_call [c ("osm_points", "osm_polygons", "osm_multipolygons")],
        function (sf) expect_named (as.data.frame (sf) [, 1:6], cols)
    )
    expect_s3_class (x, "osmdata_sf")
    expect_s3_class (x_no_call, "osmdata_sf")
})


test_that ("non-valid key names", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_sf (q0, osm_multi)

    k <- lapply (x [grep ("osm_", names (x))], function (f) {
        expect_true ("name:ca" %in% names (f))
    })
})


test_that ("clashes in key names", {
    osm_multi_key_clashes <- test_path ("fixtures", "osm-key_clashes.osm")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    expect_warning (
        x <- osmdata_sf (q0, osm_multi_key_clashes),
        "Feature keys clash with id or metadata columns and will be renamed by "
    )

    expect_false (any (duplicated (names (x$osm_points))))
    # x$osm_points don't have osm_id column in tags TODO?
    k <- lapply (x [grep ("osm_", names (x)) [-1]], function (f) {
        expect_false (any (duplicated (names (f))))
        expect_true (all (c ("osm_id", "osm_id.1") %in% names (f)))
    })
})


test_that ("duplicated column names", {
    # https://github.com/ropensci/osmdata/issues/348
    osm_ways <- test_path ("fixtures", "osm-ways.osm")

    q0 <- opq (bbox = c (1, 1, 5, 5))
    x0 <- osmdata_sf (q0, osm_ways)$osm_lines
    expect_true ("boat" %in% names (x0))
    x0_boat <- x0$boat [which (!is.na (x0$boat))]
    expect_equal (x0_boat, "yes")

    # Read those data and insert new node with duplicated name.
    # This requires much less code read as text rather than xml:
    x <- readLines (osm_ways)
    i <- grep ("\"boat\"", x)
    x_i <- gsub ("yes", "no", gsub ("boat", "Boat", x [i]))
    x <- c (x [seq_len (i)], x_i, x [seq (i + 1L, length (x))])
    ftmp <- tempfile (fileext = ".osm")
    writeLines (x, ftmp)

    # Note that XML parses capitals before lowercase, so "boat" is merged into
    # "Boat"
    x1 <- osmdata_sf (q0, ftmp)$osm_lines
    expect_false ("boat" %in% names (x1))
    expect_true ("Boat" %in% names (x1))
    x1_boat <- x1$Boat [which (!is.na (x1$Boat))]
    expect_equal (x1_boat, "no")
})
