has_internet <- curl::has_internet ()

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("GITHUB_WORKFLOW"), "test-coverage"))

test_that ("osmdata_sc", {

    qry <- opq (bbox = c(-0.118, 51.514, -0.115, 51.517)) %>%
        add_osm_feature (key = "highway")

    f <- file.path (tempdir (), "junk.osm")
    doc <- with_mock_dir ("test_elevation", {
        osmdata_xml (qry, file = f)
    })
    expect_silent (x <- osmdata_sc (qry, doc = f))
    expect_true (file.exists (f))

    xml <- xml2::read_xml (f)
    expect_s3_class (xml, "xml_document")

    #elev_file = "/data/data/elevation/srtm_36_02.zip"
    #x <- osm_elevation (x, elev_file = elev_file)
})
