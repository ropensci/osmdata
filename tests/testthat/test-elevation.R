has_internet <- curl::has_internet ()

test_that ("elevation", {

    # elevation can't actually be tested, because it only works with a full SRTM
    # elevation file, so this test doesn't actually do anything.
    qry <- opq (bbox = c (-0.116, 51.516, -0.115, 51.517)) %>%
        add_osm_feature (key = "highway")

    f <- file.path (tempdir (), "junk.osm")
    doc <- with_mock_dir ("mock_elevation", {
        osmdata_xml (qry, file = f)
    })

    expect_silent (x <- osmdata_sc (qry, doc = f))
    expect_true (file.exists (f))

    xml <- xml2::read_xml (f)
    expect_s3_class (xml, "xml_document")

    # elev_file = "/data/data/elevation/srtm_36_02.zip"
    # x <- osm_elevation (x, elev_file = elev_file)
})

# elevation.R has two helper fns:
# 1. check_bbox()
# 2. get_file_index()
test_that ("misc elevation fns", {

    bbox <- c (-0.116, 51.516, -0.115, 51.517)
    # 2nd param of check_bbox() is a raster object to which sp::bbox can be
    # directly applied; faked here with a simple matrix:
    bbox_mat <- t (matrix (bbox, ncol = 2))

    qry <- opq (bbox = bbox)
    dat <- list (meta = list (bbox = qry$bbox))
    # 'sp' will soon issue a message here about depending on legacy packages.
    # Expectation may be restored once sp-dependency has been removed (#273).
    # expect_silent (
    check_bbox (dat, bbox_mat)
    # )

    ti <- get_tile_index (qry$bbox)
    expect_s3_class (ti, "data.frame")
    expect_length (ti, 2L)
    expect_identical (names (ti), c ("xi", "yi"))
    expect_type (ti$xi, "integer")
    expect_type (ti$yi, "integer")
})
