has_internet <- curl::has_internet ()

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
        key = "highway", value = "primary",
        match_case = FALSE
    )
    expect_identical (qry1$features, "[\"highway\"]")
    expect_identical (qry2$features, "[\"highway\"=\"primary\"]")
    expect_identical (
        qry3$features,
        "[\"highway\"~\"^(primary|tertiary)$\"]"
    )
    expect_identical (qry4$features, "[\"highway\"!=\"primary\"]")
    expect_identical (qry5$features, "[\"highway\"~\"^(primary)$\",i]")

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

    qry7 <- opq ("relation(id:74310)") %>% # "Vinçà"
        add_osm_feature (key = c("name", "!name:ca"))
    qry8 <- opq ("relation(id:11755232)") %>% # "el Carxe"
        add_osm_feature (key = "natural", value = "peak") %>%
        add_osm_feature (key = "!ele")
    expect_warning(
        qry9 <- opq ("relation(id:11755232)") %>% # "el Carxe"
            add_osm_feature (key = "!ele")%>%
            add_osm_feature (key = "natural", value = "peak"),
        "The query will request objects whith only a negated key "
    )
    expect_identical(qry7$features, "[\"name\"] [!\"name:ca\"]")
    expect_identical(qry8$features, "[\"natural\"=\"peak\"] [!\"ele\"]")
    expect_identical(qry9$features, "[!\"ele\"] [\"natural\"=\"peak\"]")
})

test_that ("query_errors", {

    expect_error (
        osmdata_xml (),
        "argument \"q\" is missing, with no default"
    )
    expect_error (
        osmdata_sp (),
        'arguments "q" and "doc" are missing, with no default. '
    )
    expect_error (
        osmdata_sf (),
        'arguments "q" and "doc" are missing, with no default. '
    )
    expect_error (
        osmdata_sc (),
        'arguments "q" and "doc" are missing, with no default. '
    )
    expect_error (
        osmdata_data_frame (),
        'arguments "q" and "doc" are missing, with no default. '
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
    expect_error (
        osmdata_data_frame (q = NULL),
        "q must be an overpass query or a character string"
    )
})

test_that ("not implemented queries", {

    qadiff <- opq (bbox = c (1.8374527, 41.5931579, 1.8384799, 41.5936434),
                   datetime = "2014-09-11T00:00:00Z",
                   datetime2 = "2017-09-11T00:00:00Z",
                   adiff = TRUE)
    osm_adiff2 <- test_path ("fixtures", "osm-adiff2.osm")
    doc <- xml2::read_xml (osm_adiff2)

    expect_error (
        osmdata_sp (q = qadiff, doc = doc),
        "adiff queries not yet implemented."
    )
    expect_error (
        osmdata_sf (q = qadiff, doc = doc),
        "adiff queries not yet implemented."
    )
    expect_error (
        osmdata_sc (q = qadiff, doc = doc),
        "adiff queries not yet implemented."
    )


    qtags <- opq (bbox = c (1.8374527, 41.5931579, 1.8384799, 41.5936434),
                  out="tags")
    osm_tags <- test_path ("fixtures", "osm-tags.osm")
    doc <- xml2::read_xml (osm_tags)

    expect_error (
        osmdata_sp (q = qtags, doc = doc),
        "Queries returning no geometries \\(out tags/ids\\) not accepted."
    )
    expect_error (
        osmdata_sf (q = qtags, doc = doc),
        "Queries returning no geometries \\(out tags/ids\\) not accepted."
    )
    expect_error (
        osmdata_sc (q = qtags, doc = doc),
        "Queries returning no geometries \\(out tags/ids\\) not accepted."
    )

    qmeta <- opq (bbox = c (1.8374527, 41.5931579, 1.8384799, 41.5936434),
                  out="meta")
    osm_meta <- test_path ("fixtures", "osm-meta.osm")
    doc <- xml2::read_xml (osm_meta)

    expect_warning (
        osmdata_sp (q = qmeta, doc = doc),
        "`out meta` queries not yet implemented."
    )
    expect_warning (
        osmdata_sf (q = qmeta, doc = doc),
        "`out meta` queries not yet implemented."
    )
    expect_warning (
        osmdata_sc (q = qmeta, doc = doc),
        "`out meta` queries not yet implemented."
    )

    qcsv <- opq (bbox = c (1.8374527, 41.5931579, 1.8384799, 41.5936434)) %>%
        opq_csv(fields = c("name"))
    expect_error (
        osmdata_xml (q = qcsv),
        "out:csv queries only work with osmdata_data_frame()."
    )
    expect_error (
        osmdata_sp (q = qcsv),
        "out:csv queries only work with osmdata_data_frame()."
    )
    expect_error (
        osmdata_sf (q = qcsv),
        "out:csv queries only work with osmdata_data_frame()."
    )
    expect_error (
        osmdata_sc (q = qcsv),
        "out:csv queries only work with osmdata_data_frame()."
    )

})

test_that ("osmdata without query", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")
    doc <- xml2::read_xml (osm_multi)

    expect_silent ( x_sp <- osmdata_sp (doc = doc))
    expect_silent ( x_sf <- osmdata_sf (doc = doc))
    expect_silent ( x_sc <- osmdata_sc (doc = doc))
    expect_silent ( x_df <- osmdata_data_frame (doc = doc))

    expect_s3_class ( x_sp, "osmdata")
    expect_s3_class ( x_sf, "osmdata")
    expect_s3_class ( x_sc, c ("SC", "osmdata_sc"))
    expect_s3_class ( x_df, "data.frame")

    expect_message (
        x_sp <- osmdata_sp (doc = doc, quiet = FALSE),
        "q missing: osmdata object will not include query"
    )
    expect_message (
        x_sf <- osmdata_sf (doc = doc, quiet = FALSE),
        "q missing: osmdata object will not include query"
    )
    expect_message (
        x_sc <- osmdata_sc (doc = doc, quiet = FALSE),
        "q missing: osmdata object will not include query"
    )
    expect_message (
        x_df <- osmdata_data_frame (doc = doc, quiet = FALSE),
        "q missing: osmdata object will not include query"
    )

    expect_s3_class ( x_sp, "osmdata")
    expect_s3_class ( x_sf, "osmdata")
    expect_s3_class ( x_sc, c ("SC", "osmdata_sc"))
    expect_s3_class ( x_df, "data.frame")
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
        expect_error (
            osmdata_data_frame (qry),
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

            res <- with_mock_dir ("mock_osm_df", {
                osmdata_data_frame (qry)
            })
            expect_s3_class (res, "data.frame")
            expect_silent (res <- osmdata_data_frame (qry, doc))
            expect_s3_class (res, "data.frame")
            expect_silent (res <- osmdata_data_frame (qry, "junk.osm"))
            expect_message (res <- osmdata_data_frame (qry, "junk.osm", quiet = FALSE))

            nms <- c (
                "names", "row.names", "class", "bbox", "overpass_call", "meta"
            )
            expect_named (attributes(res), expected = nms, ignore.order = FALSE)
        }

        if (file.exists ("junk.osm")) invisible (file.remove ("junk.osm"))
    }
})

test_that ("query-no-quiet", {

    qry <- opq (bbox = c (-0.116, 51.516, -0.115, 51.517))
    qry <- add_osm_feature (qry, key = "highway")

    if (test_all) {
        with_mock_dir ("mock_osm_xml", {
            expect_message (x <- osmdata_xml (qry, quiet = FALSE),
                           "Issuing query to Overpass API")
        })
        with_mock_dir ("mock_osm_sp", {
            expect_message (x <- osmdata_sp (qry, quiet = FALSE),
                           "Issuing query to Overpass API")
        })
        with_mock_dir ("mock_osm_sf", {
            expect_message (x <- osmdata_sf (qry, quiet = FALSE),
                           "Issuing query to Overpass API")
        })
        with_mock_dir ("mock_osm_sc", {
            expect_message (x <- osmdata_sc (qry, quiet = FALSE),
                           "Issuing query to Overpass API")
        })
        with_mock_dir ("mock_osm_df", {
            expect_message (x <- osmdata_data_frame (qry, quiet = FALSE),
                           "Issuing query to Overpass API")
        })
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
        "features must be a named list or vector or a character vector enclosed in escape delimited quotations \\(see examples\\)"
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

    qry3 <- add_osm_features (qry0, features = c("amenity" = "restaurant"))
    expect_identical (qry1, qry3)

    qry4 <- add_osm_features (qry0,
      features = c("amenity" = "restaurant", "amentity" = "pub")
      )
    expect_s3_class (qry4, "overpass_query")

    qry5 <- add_osm_features (qry0,
      features = list("amenity" = "restaurant", "amentity" = "pub")
    )
    expect_s3_class (qry5, "overpass_query")
})
