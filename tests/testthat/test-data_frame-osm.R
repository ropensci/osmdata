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

test_that ("attributes", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")

    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_data_frame (q0, osm_multi)
    x_sf <- osmdata_sf (q0, osm_multi)

    expect_s3_class (x, "data.frame")
    expect_identical (names (attributes (x)),
                      c ("names", "class", "row.names", "bbox", "overpass_call", "meta"))
    expect_identical (attr (x, "bbox"), q0$bbox)
    expect_identical (attr (x, "overpass_call"), x_sf$overpass_call)
    expect_identical (attr (x, "meta"), x_sf$meta)
})

test_that ("attributes", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")

    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_data_frame (q0, osm_multi)
    x_sf <- osmdata_sf (q0, osm_multi)

    expect_s3_class (x, "data.frame")
    expect_identical (names (attributes (x)),
                      c ("names", "class", "row.names", "bbox", "overpass_call", "meta"))
    expect_identical (attr (x, "bbox"), q0$bbox)
    expect_identical (attr (x, "overpass_call"), x_sf$overpass_call)
    expect_identical (attr (x, "meta"), x_sf$meta)
})

test_that ("out meta & adiff", {
    q <- getbb ("Conflent", featuretype = "relation") %>%
        opq (nodes_only = TRUE, datetime = "2020-11-07T00:00:00Z") %>%
        add_osm_feature ("natural", "peak") %>%
        add_osm_feature ("prominence")  %>%
        add_osm_feature ("name:ca")

    q$prefix <- gsub ("date:", "adiff:", q$prefix)
    q$suffix <- ");\n(._;>;);\nout meta;"

    osm_meta_adiff <- test_path ("fixtures", "osm-meta_adiff.osm")
    doc <- xml2::read_xml (osm_meta_adiff)

    x <- osmdata_data_frame (q, doc)

    cols <- c ("adiff_action", "adiff_date", "adiff_visible", "osm_type", "osm_id",
               "osm_version", "osm_timestamp", "osm_changeset", "osm_uid", "osm_user",
               "ele", "name", "name:ca", "natural", "prominence", "source:prominence",
               "wikidata", "wikipedia")
    expect_named (x, cols)
    expect_s3_class (x, "data.frame")

    obj_overpass_call <- osmdata(bbox = q$bbox, overpass_call = opq_string_intern(q))
    obj_opq <- osmdata(bbox = q$bbox, overpass_call = q)
    obj <- osmdata(bbox = q$bbox)

    metaL<- list (meta_overpass_call = get_metadata(obj_overpass_call, doc)$meta,
                  meta_opq = get_metadata(obj_opq, doc)$meta,
                  meta_no_call = get_metadata(obj, doc)$meta)

    k <- sapply (metaL, function (x) expect_equal(x$query_type, "adiff"))
    expect_identical (metaL$meta_overpass_call, metaL$meta_opq)
    expect_identical (metaL$meta_overpass_call$datetime_from, attr (q, "datetime"))
})

test_that ("adiff2", {
    q <- getbb ("Perpinyà", featuretype = "relation") %>%
      opq (nodes_only = TRUE, datetime = "2012-11-07T00:00:00Z", datetime2 = "2016-11-07T00:00:00Z") %>%
      add_osm_feature ("amenity", "restaurant")

    q$prefix <- gsub ("diff:", "adiff:", q$prefix)

    osm_adiff2 <- test_path ("fixtures", "osm-adiff2.osm")
    doc <- xml2::read_xml (osm_adiff2)

    x <- osmdata_data_frame (q, doc)

    cols <- c ("adiff_action", "adiff_date", "adiff_visible", "osm_type", "osm_id",
               "addr:housenumber", "addr:street", "amenity", "created_by",
               "cuisine", "name", "phone")
    expect_named (x, cols)
    expect_s3_class (x, "data.frame")

    obj_overpass_call <- osmdata(bbox = q$bbox, overpass_call = opq_string_intern(q))
    obj_opq <- osmdata(bbox = q$bbox, overpass_call = q)
    obj <- osmdata(bbox = q$bbox)

    metaL<- list (meta_overpass_call = get_metadata(obj_overpass_call, doc)$meta,
                  meta_opq = get_metadata(obj_opq, doc)$meta,
                  meta_no_call = get_metadata(obj, doc)$meta)

    k <- sapply (metaL, function (x) expect_equal(x$query_type, "adiff"))
    expect_identical (metaL$meta_overpass_call, metaL$meta_opq)
    expect_identical (metaL$meta_overpass_call$datetime_from, attr (q, "datetime"))
})
