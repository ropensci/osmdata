has_internet <- curl::has_internet ()

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
    identical (Sys.getenv ("GITHUB_WORKFLOW"), "test-coverage"))

set_overpass_url ("https://overpass-api.de/api/interpreter")

test_that ("query-construction", {

    q0 <- opq (bbox = c (-0.12, 51.51, -0.11, 51.52))
    expect_error (q1 <- add_osm_feature (q0), "key must be provided")
    expect_silent (q1 <- add_osm_feature (q0, key = "aaa")) # bbox from qry
    q0$bbox <- NULL
    expect_error (
        q1 <- add_osm_feature (q0, key = "aaa"),
        "Bounding box has to either be set in opq or must be set here"
    )
    q0 <- opq (bbox = c (-0.12, 51.51, -0.11, 51.52))
    q1 <- add_osm_feature (q0, key = "aaa")
    expect_false (grepl ("=", q1$features))
    q1 <- add_osm_feature (q0, key = "aaa", value = "bbb")
    expect_true (grepl ("=", q1$features))
    expect_message (
        q1 <- add_osm_feature (q0,
            key = "aaa", value = "bbb",
            key_exact = FALSE
        ),
        "key_exact = FALSE can only combined with value_exact = FALSE;"
    )
    expect_silent (
        q1 <- add_osm_feature (q0,
            key = "aaa", value = "bbb",
            key_exact = FALSE, value_exact = FALSE
        )
    )
})

test_that ("add feature", {

    qry <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517))
    qry1 <- add_osm_feature (qry, key = "highway")
    qry2 <- add_osm_feature (qry, key = "highway", value = "primary")
    qry3 <- add_osm_feature (qry,
        key = "highway",
        value = c ("primary", "tertiary")
    )
    qry4 <- add_osm_feature (qry, key = "highway", value = "!primary")
    qry5 <- add_osm_feature (qry,
        key = "highway", value = "!primary",
        match_case = FALSE
    )
    expect_identical (qry1$features, " [\"highway\"]")
    expect_identical (qry2$features, " [\"highway\"=\"primary\"]")
    expect_identical (
        qry3$features,
        " [\"highway\"~\"^(primary|tertiary)$\"]"
    )
    expect_identical (qry4$features, " [\"highway\"!=\"primary\"]")
    expect_identical (qry5$features, " [\"highway\"!=\"primary\",i]")

    bbox <- c (-0.118, 51.514, -0.115, 51.517)
    qry <- opq (bbox = bbox)
    bbox2 <- bbox + c (0.01, 0.01, -0.01, -0.01)
    qry6 <- add_osm_feature (
        qry,
        bbox = bbox2,
        key = "highway",
        value = "!primary"
    )
    expect_true (!identical (qry$bbox, qry6$bbox))
})

test_that ("query_errors", {

    expect_error (
        osmdata_xml (),
        "argument \"q\" is missing, with no default"
    )
    expect_error (
        osmdata_sp (),
        "argument \"q\" is missing, with no default"
    )
    expect_error (
        osmdata_sf (),
        "query must be a single character string"
    )
    expect_error (
        osmdata_sc (),
        "argument \"q\" is missing, with no default"
    )

    expect_error (
        osmdata_xml (q = NULL),
        "q must be an overpass query or a character string"
    )
    expect_error (
        osmdata_sp (q = NULL),
        "q must be an overpass query or a character string"
    )
    expect_error (
        osmdata_sf (q = NULL),
        "q must be an overpass query or a character string"
    )
    expect_error (
        osmdata_sc (q = NULL),
        "q must be an overpass query or a character string"
    )
})

test_that ("make_query", {

    qry <- opq (bbox = c (-0.116, 51.516, -0.115, 51.517))
    qry <- add_osm_feature (qry, key = "highway")

    if (!has_internet) {
        expect_error (
            osmdata_xml (qry),
            "Overpass query unavailable without internet"
        )
        expect_error (
            osmdata_sf (qry),
            "Overpass query unavailable without internet"
        )
        expect_error (
            osmdata_sp (qry),
            "Overpass query unavailable without internet"
        )
        expect_error (
            osmdata_sc (qry),
            "Overpass query unavailable without internet"
        )
    } else {

        doc <- with_mock_dir ("mock_osm_xml", {
            osmdata_xml (qry)
        })
        expect_true (is (doc, "xml_document"))
        expect_silent (
            doc2 <- with_mock_dir ("mock_osm_xml2", {
                osmdata_xml (qry, file = "junk.osm")
            })
        )
        expect_equal (doc, doc2)

        if (test_all) {

            res <- with_mock_dir ("mock_osm_sp", {
                osmdata_sp (qry)
            })
            expect_message (print (res), "Object of class 'osmdata' with")
            expect_silent (res <- osmdata_sp (qry, doc))
            expect_message (print (res), "Object of class 'osmdata' with")
            expect_silent (res <- osmdata_sp (qry, "junk.osm"))
            expect_message (res <- osmdata_sp (qry, "junk.osm", quiet = FALSE))

            expect_s3_class (res, "osmdata")
            nms <- c (
                "bbox", "overpass_call", "meta", "osm_points",
                "osm_lines", "osm_polygons", "osm_multilines",
                "osm_multipolygons"
            )
            expect_named (res, expected = nms, ignore.order = FALSE)
            nms <- c ("timestamp", "OSM_version", "overpass_version")
            expect_named (res$meta, expected = nms)

            res <- with_mock_dir ("mock_osm_sf", {
                osmdata_sf (qry)
            })
            expect_message (print (res), "Object of class 'osmdata' with")
            expect_silent (res <- osmdata_sf (qry, doc))
            expect_message (print (res), "Object of class 'osmdata' with")
            expect_silent (res <- osmdata_sf (qry, "junk.osm"))
            expect_message (res <- osmdata_sf (qry, "junk.osm", quiet = FALSE))
            expect_s3_class (res, "osmdata")
            nms <- c (
                "bbox", "overpass_call", "meta", "osm_points",
                "osm_lines", "osm_polygons", "osm_multilines",
                "osm_multipolygons"
            )
            expect_named (res, expected = nms, ignore.order = FALSE)
        }

        if (file.exists ("junk.osm")) invisible (file.remove ("junk.osm"))
    }
})

test_that ("query-no-quiet", {

    qry <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517))
    qry <- add_osm_feature (qry, key = "highway")
    # switched off until mock results for httr2 reinstanted for #272
    # expect_message (x <- osmdata_xml (qry, quiet = FALSE),
    #                "Issuing query to Overpass API")

    if (test_all) {
        # expect_message (x <- osmdata_sp (qry, quiet = FALSE),
        #                "Issuing query to Overpass API")
        # expect_message (x <- osmdata_sf (qry, quiet = FALSE),
        #                "Issuing query to Overpass API")
        # expect_message (x <- osmdata_sc (qry, quiet = FALSE),
        #                "Issuing query to Overpass API")
    }
})

test_that ("add_osm_features", {

    qry <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517))
    expect_error (
        qry <- add_osm_features (qry),
        "features must be provided"
    )

    qry$bbox <- NULL
    expect_error (
        qry <- add_osm_features (qry, features = "a"),
        "Bounding box has to either be set in opq or must be set here"
    )

    qry <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517))
    expect_error (
        qry <- add_osm_features (qry, features = "a"),
        paste0 (
            "features must be enclosed in escape-delimited ",
            "quotations \\(see example\\)"
        )
    )

    bbox <- c (-0.118, 51.514, -0.115, 51.517)
    bbox_mod <- bbox + c (-0.001, -0.001, 0.001, 0.001)
    qry0 <- opq (bbox = bbox)
    qry1 <- add_osm_features (qry0, features = "\"amenity\"=\"restaurant\"")
    qry2 <- add_osm_features (qry0,
        features = "\"amenity\"=\"restaurant\"",
        bbox = bbox_mod
    )
    expect_false (identical (qry1$bbox, qry2$bbox))

})
