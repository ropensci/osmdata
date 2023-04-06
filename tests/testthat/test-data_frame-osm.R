context ("data_frame-osm")

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
    x <- osmdata_data_frame (q0, osm_multi)

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
    x <- osmdata_data_frame (q0, osm_multi)
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
    x <- osmdata_data_frame (q0, osm_ways)
    x_sf <- sf::st_drop_geometry (x_sf)
    x <- x [, which (names (x) %in% names (x_sf))]
    x_sf <- x_sf [, which (names (x_sf) %in% names (x))]

    expect_setequal (names (x), names (x_sf))
    expect_true (all (x_sf$osm_id %in% x$osm_id))
    expect_true (all (x_sf$name %in% x$name))
    expect_true (all (x_sf$highway %in% x$highway))
})

test_that ("empty result", {
    # bb <- getbb ("Països Catalans", featuretype = "relation")
    bb <- rbind (c (-1.24, 8.42), c (28.03, 42.92))
    rownames (bb) <- c ("x", "y")
    colnames (bb) <- c ("min", "max")

    q0 <- opq (bb, nodes_only = TRUE, datetime = "1714-09-11T00:00:00Z") %>%
        add_osm_feature ("does not exist", "&%$")

    osm_empty <- test_path ("fixtures", "osm-empty.osm")
    doc <- xml2::read_xml (osm_empty)

    x <- osmdata_data_frame (q0, doc)

    cols <- c ("osm_type", "osm_id")
    expect_named (x, cols)
    expect_s3_class (x, "data.frame")
    expect_identical (nrow (x), 0L)

    obj_overpass_call <-
        osmdata (bbox = q0$bbox, overpass_call = opq_string_intern (q0))
    obj_opq <- osmdata (bbox = q0$bbox, overpass_call = q0)
    obj <- osmdata (bbox = q0$bbox)

    meta_l <- list (
        meta_overpass_call = get_metadata (obj_overpass_call, doc)$meta,
        meta_opq = get_metadata (obj_opq, doc)$meta,
        meta_no_call = get_metadata (obj, doc)$meta
    )

    expect_equal (meta_l$meta_overpass_call$query_type, "date")
    expect_equal (meta_l$meta_opq$query_type, "date")
    expect_null (meta_l$meta_no_call$query_type)

    # adiff
    # q0 <- getbb ("Països Catalans", featuretype = "relation") %>%
    q0 <- opq (
        bb,
        nodes_only = TRUE,
        datetime = "1714-09-11T00:00:00Z",
        adiff = TRUE
    ) %>%
        add_osm_feature ("does not exist", "&%$")

    # osm_empty <- test_path ("fixtures", "osm-empty.osm") # same result
    # doc <- xml2::read_xml (osm_empty)

    x <- osmdata_data_frame (q0, doc)

    cols <- c (
        "osm_type",
        "osm_id",
        "adiff_action",
        "adiff_date",
        "adiff_visible"
    )
    expect_named (x, cols)
    expect_s3_class (x, "data.frame")
    expect_identical (nrow (x), 0L)

    obj_overpass_call <- osmdata (
        bbox = q0$bbox,
        overpass_call = opq_string_intern (q0)
    )
    obj_opq <- osmdata (bbox = q0$bbox, overpass_call = q0)
    obj <- osmdata (bbox = q0$bbox)

    meta_l <- list (
        meta_overpass_call = get_metadata (obj_overpass_call, doc)$meta,
        meta_opq = get_metadata (obj_opq, doc)$meta,
        meta_no_call = get_metadata (obj, doc)$meta
    )

    expect_equal (meta_l$meta_overpass_call$query_type, "adiff")
    expect_equal (meta_l$meta_opq$query_type, "adiff")
    expect_null (meta_l$meta_no_call$query_type)

    expect_identical (meta_l$meta_overpass_call, meta_l$meta_opq)
    expect_identical (
        meta_l$meta_overpass_call$datetime_from,
        attr (q0, "datetime")
    )
})

test_that ("attributes", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")

    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_data_frame (q0, osm_multi)
    x_no_call <- osmdata_data_frame (doc = osm_multi)
    x_sf <- osmdata_sf (q0, osm_multi)

    expect_s3_class (x, "data.frame")
    expect_true (setequal (
        names (attributes (x)),
        c ("bbox", "class", "meta", "names", "overpass_call", "row.names")
    ))
    expect_identical (attr (x, "bbox"), q0$bbox)
    expect_identical (attr (x, "overpass_call"), x_sf$overpass_call)
    expect_identical (attr (x, "meta"), x_sf$meta)
    # no call
    expect_s3_class (x_no_call, "data.frame")
    expect_true (setequal (
        names (attributes (x_no_call)),
        c ("names", "class", "row.names", "meta")
    ))
    expect_identical (attr (x_no_call, "meta"), x_sf$meta)
})

test_that ("date", {
    # q <- getbb ("Conflent", featuretype = "relation")
    bb <- rbind (c (2.01, 2.66), c (42.42, 42.71))
    rownames (bb) <- c ("x", "y")
    colnames (bb) <- c ("min", "max")
    q <- opq (bb, nodes_only = TRUE, datetime = "2020-11-07T00:00:00Z") %>%
        add_osm_feature ("natural", "peak") %>%
        add_osm_feature ("prominence") %>%
        add_osm_feature ("name:ca")

    osm_meta_date <- test_path ("fixtures", "osm-date.osm")
    doc <- xml2::read_xml (osm_meta_date)

    x <- osmdata_data_frame (q, doc)
    x_no_call <- osmdata_data_frame (doc = doc, quiet = FALSE)

    cols <- c (
        "osm_type", "osm_id", "ele", "name",
        "name:ca", "natural", "prominence"
    )
    expect_named (x, cols)
    # expect_named (x_no_call, cols) # include osm_center_lat/lon columns
    expect_s3_class (x, "data.frame")
    expect_s3_class (x_no_call, "data.frame")

    obj_overpass_call <-
        osmdata (bbox = q$bbox, overpass_call = opq_string_intern (q))
    obj_opq <- osmdata (bbox = q$bbox, overpass_call = q)
    obj <- osmdata (bbox = q$bbox)

    meta_l <- list (
        meta_overpass_call = get_metadata (obj_overpass_call, doc)$meta,
        meta_opq = get_metadata (obj_opq, doc)$meta,
        meta_no_call = get_metadata (obj, doc)$meta
    )

    expect_identical (meta_l$meta_overpass_call, meta_l$meta_opq)
    expect_identical (
        meta_l$meta_overpass_call$datetime_to,
        attr (q, "datetime")
    )
    expect_null (meta_l$meta_overpass_call$datetime_from)
    expect_null (meta_l$meta_no_call$query_type)
})

test_that ("out tags center", {
    # q <- getbb ("Franja de Ponent", featuretype = "relation") %>%
    bb <- rbind (c (-0.73, 1.27), c (40.63, 42.63))
    rownames (bb) <- c ("x", "y")
    colnames (bb) <- c ("min", "max")
    q <- opq (bb, out = "tags center") %>%
        add_osm_feature ("amenity", "community_centre")

    osm_tags_center <- test_path ("fixtures", "osm-tags_center.osm")
    doc <- xml2::read_xml (osm_tags_center)

    expect_silent (x <- osmdata_data_frame (opq_string_intern (q), doc))
    expect_silent (x_no_call <- osmdata_data_frame (doc = doc))

    cols <- c (
        "osm_type", "osm_id", "osm_center_lat", "osm_center_lon", "addr:city",
        "addr:housenumber", "addr:postcode", "addr:street", "amenity",
        "building", "building:colour", "building:levels", "building:material",
        "community_centre", "community_centre:for", "name", "name:ca",
        "old_name", "operator", "roof:material", "roof:shape", "sport", "type",
        "website", "wikidata", "wikipedia"
    )
    expect_named (x, cols)
    expect_named (x_no_call, cols)
    expect_s3_class (x, "data.frame")
    expect_s3_class (x_no_call, "data.frame")
    expect_type (x$osm_center_lat, "double")
    expect_type (x$osm_center_lon, "double")
    expect_true (!any (is.na (x$osm_center_lat)))
    expect_true (!any (is.na (x$osm_center_lon)))
})

test_that ("out meta & diff", {
    # q <- getbb ("Conflent", featuretype = "relation") %>%
    bb <- rbind (c (2.01, 2.66), c (42.42, 42.71))
    rownames (bb) <- c ("x", "y")
    colnames (bb) <- c ("min", "max")
    q <- opq (bb,
        nodes_only = TRUE, out = "meta",
        datetime = "2020-11-07T00:00:00Z",
        datetime2 = "2022-12-04T00:00:00Z"
    ) %>%
        add_osm_feature ("natural", "peak") %>%
        add_osm_feature ("prominence") %>%
        add_osm_feature ("name:ca")

    osm_meta_diff <- test_path ("fixtures", "osm-meta_diff.osm")
    doc <- xml2::read_xml (osm_meta_diff)

    x <- osmdata_data_frame (q, doc, quiet = FALSE)
    x_no_call <- osmdata_data_frame (doc = doc)

    cols <- c (
        "osm_type", "osm_id", "osm_version", "osm_timestamp",
        "osm_changeset", "osm_uid", "osm_user", "ele", "name",
        "name:ca", "natural", "prominence"
    )
    expect_named (x, cols)
    # expect_named (x_no_call, cols) # include osm_center_lat/lon columns
    expect_s3_class (x, "data.frame")
    expect_s3_class (x_no_call, "data.frame")

    obj_overpass_call <-
        osmdata (bbox = q$bbox, overpass_call = opq_string_intern (q))
    obj_opq <- osmdata (bbox = q$bbox, overpass_call = q)
    obj <- osmdata (bbox = q$bbox)

    meta_l <- list (
        meta_overpass_call = get_metadata (obj_overpass_call, doc)$meta,
        meta_opq = get_metadata (obj_opq, doc)$meta,
        meta_no_call = get_metadata (obj, doc)$meta
    )

    expect_identical (meta_l$meta_overpass_call, meta_l$meta_opq)
    expect_identical (
        meta_l$meta_overpass_call$datetime_from,
        attr (q, "datetime")
    )
    expect_identical (
        meta_l$meta_overpass_call$datetime_to,
        attr (q, "datetime2")
    )
    expect_null (meta_l$meta_no_call$query_type)
})

test_that ("out meta & adiff", {
    # q <- getbb ("Conflent", featuretype = "relation") %>%
    bb <- rbind (c (2.01, 2.66), c (42.42, 42.71))
    rownames (bb) <- c ("x", "y")
    colnames (bb) <- c ("min", "max")
    q <- opq (bb,
        nodes_only = TRUE, out = "meta",
        datetime = "2020-11-07T00:00:00Z", adiff = TRUE
    ) %>%
        add_osm_feature ("natural", "peak") %>%
        add_osm_feature ("prominence") %>%
        add_osm_feature ("name:ca")

    osm_meta_adiff <- test_path ("fixtures", "osm-meta_adiff.osm")
    doc <- xml2::read_xml (osm_meta_adiff)

    expect_silent (x <- osmdata_data_frame (opq_string_intern (q), doc))
    expect_warning (
        x_no_call <- osmdata_data_frame (doc = doc),
        "OSM data is ambiguous and can correspond either to a diff or an adiff query." # nolint
    ) # query_type assigned to diff

    cols <- c (
        "osm_type", "osm_id",
        "osm_version", "osm_timestamp", "osm_changeset", "osm_uid", "osm_user",
        "adiff_action", "adiff_date", "adiff_visible",
        "ele", "name", "name:ca", "natural", "prominence",
        "source:prominence", "wikidata", "wikipedia"
    )
    expect_named (x, cols)
    # expect_named (x_no_call, cols) # query_type assigned to diff
    expect_s3_class (x, "data.frame")
    expect_s3_class (x_no_call, "data.frame")

    obj_overpass_call <-
        osmdata (bbox = q$bbox, overpass_call = opq_string_intern (q))
    obj_opq <- osmdata (bbox = q$bbox, overpass_call = q)
    obj <- osmdata (bbox = q$bbox)

    meta_l <- list (
        meta_overpass_call = get_metadata (obj_overpass_call, doc)$meta,
        meta_opq = get_metadata (obj_opq, doc)$meta,
        meta_no_call = expect_warning (
            get_metadata (obj, doc)$meta,
            "OSM data is ambiguous and can correspond either to a diff or an adiff query" # nolint
        )
    )

    expect_equal (meta_l$meta_overpass_call$query_type, "adiff")
    expect_equal (meta_l$meta_opq$query_type, "adiff")
    expect_equal (meta_l$meta_no_call$query_type, "diff")
    expect_identical (meta_l$meta_overpass_call, meta_l$meta_opq)
    expect_identical (
        meta_l$meta_overpass_call$datetime_from,
        attr (q, "datetime")
    )
})

test_that ("out tags center & adiff", {
    # q <- getbb ("Franja de Ponent", featuretype = "relation") %>%
    bb <- rbind (c (-0.73, 1.27), c (40.63, 42.63))
    rownames (bb) <- c ("x", "y")
    colnames (bb) <- c ("min", "max")
    q <- opq (
        bb,
        out = "tags center",
        datetime = "2017-11-07T00:00:00Z",
        datetime2 = "2020-11-07T00:00:00Z",
        adiff = TRUE,
        timeout = 50
    ) %>%
        add_osm_feature ("amenity", "community_centre")

    osm_tags_center <- test_path ("fixtures", "osm-tags_center-adiff.osm")
    doc <- xml2::read_xml (osm_tags_center)

    expect_silent (x <- osmdata_data_frame (opq_string_intern (q), doc))
    expect_silent (x_no_call <- osmdata_data_frame (doc = doc))

    cols <- c (
        "osm_type", "osm_id", "osm_center_lat", "osm_center_lon",
        "adiff_action", "adiff_date", "adiff_visible", "alt_name", "amenity",
        "building", "building:levels", "community_centre:for", "designation",
        "heritage", "heritage:operator", "name", "name:ca", "name:en",
        "name:es", "social_facility:for"
    )
    expect_named (x, cols)
    expect_named (x_no_call, cols)
    expect_s3_class (x, "data.frame")
    expect_s3_class (x_no_call, "data.frame")
    expect_type (x$osm_center_lat, "double")
    expect_type (x$osm_center_lon, "double")
    ## BUG in overpass?? modified objects without tags have no center
    # expect_true (!any (
    #     is.na (x$osm_center_lat) &
    #     is.na (x$osm_center_lon) &
    #     x$adiff_action != "delete" &
    #     x$adiff_date == min (x$adiff_date)
    # ))
    # x[is.na (x$osm_center_lat) & x$adiff_action != "delete" & x$adiff_date != max (x$adiff_date), 1:10]
    # x[x$osm_id == "383342026", ]
    # expect_true (!any (
    #     is.na (x_no_call$osm_center_lat) &
    #     is.na (x_no_call$osm_center_lon) &
    #     x_no_call$adiff_action != "delete" &
    #     x_no_call$adiff_date == "old"
    # ))
})

test_that ("adiff2", {
    # q <- getbb ("Perpinyà", featuretype = "relation")
    bb <- rbind (c (2.82, 2.98), c (42.65, 42.75))
    rownames (bb) <- c ("x", "y")
    colnames (bb) <- c ("min", "max")
    q <- opq (bb,
        nodes_only = TRUE,
        datetime = "2012-11-07T00:00:00Z",
        datetime2 = "2016-11-07T00:00:00Z",
        adiff = TRUE
    ) %>%
        add_osm_feature ("amenity", "restaurant")

    osm_adiff2 <- test_path ("fixtures", "osm-adiff2.osm")
    doc <- xml2::read_xml (osm_adiff2)

    x <- osmdata_data_frame (q, doc, quiet = FALSE)
    x_no_call <- osmdata_data_frame (doc = doc)

    cols <- c (
        "osm_type", "osm_id",
        "adiff_action", "adiff_date", "adiff_visible",
        "addr:housenumber", "addr:street", "amenity", "created_by",
        "cuisine", "name", "phone"
    )
    expect_named (x, cols)
    expect_named (x_no_call, cols)
    expect_s3_class (x, "data.frame")
    expect_s3_class (x_no_call, "data.frame")

    obj_overpass_call <-
        osmdata (bbox = q$bbox, overpass_call = opq_string_intern (q))
    obj_opq <- osmdata (bbox = q$bbox, overpass_call = q)
    obj <- osmdata (bbox = q$bbox)

    meta_l <- list (
        meta_overpass_call = get_metadata (obj_overpass_call, doc)$meta,
        meta_opq = get_metadata (obj_opq, doc)$meta,
        meta_no_call = get_metadata (obj, doc)$meta
    )

    k <- sapply (meta_l, function (x) expect_equal (x$query_type, "adiff"))
    expect_identical (meta_l$meta_overpass_call, meta_l$meta_opq)
    expect_identical (
        meta_l$meta_overpass_call$datetime_from,
        attr (q, "datetime")
    )
})

test_that ("out:csv", {
    # q <- getbb ("Catalan Countries", format_out = "osm_type_id") %>%
    q <- opq (bbox = "relation(id:11747082)", out = "tags center", osm_type = "relation", timeout = 50) %>%
        add_osm_feature ("admin_level", "7") %>%
        add_osm_feature ("boundary", "administrative") %>%
        opq_csv (fields = c ("name", "::type", "::id", "::lat", "::lon"))

    with_mock_dir ("mock_csv", {
        x <- osmdata_data_frame (q)
    })
    expect_is (x, "data.frame")
    r <- lapply (x, expect_is, "character")

    # Test quotes and NAs
    # qqoutes <- getbb ("Barcelona", format_out = "osm_type_id") %>%
    qqoutes <- opq (bbox = "relation(id:347950)", osm_types = "nwr", out = "tags") %>%
        opq_csv (fields = c ("name", "::id", "no_exists", "amenity")) %>%
        add_osm_feature (
            key = "name", value = "\\\"|,|Pont",
            value_exact = FALSE
        )

    with_mock_dir ("mock_csv_quotes", {
        xquotes <- osmdata_data_frame (qqoutes)
    })
    expect_is (xquotes, "data.frame")
    r <- lapply (xquotes, expect_is, "character")
    r <- lapply (xquotes, function (v) expect_false (any (v %in% ""))) # NAs

    # OP values containing `,` | `"` get quoted with `"`. `"` in values -> `""`
    expect_false (any (grepl ("^\".+,", xquotes$name))) # case specific
    expect_false (any (grepl ("\"\".+,", xquotes$name)))
})

test_that ("non-valid key names", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_data_frame (q0, osm_multi)

    expect_true ("name:ca" %in% names (x))
})

test_that ("clashes in key names", {
    osm_multi_key_clashes <- test_path ("fixtures", "osm-key_clashes.osm")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    expect_warning (
        x <- osmdata_data_frame (q0, osm_multi_key_clashes),
        "Feature keys clash with id or metadata columns and will be renamed by "
    )

    expect_true (all (c ("osm_id", "osm_id.1") %in% names (x)))
    expect_false (any (duplicated (names (x))))
})
