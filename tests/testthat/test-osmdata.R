has_internet <- curl::has_internet ()

# test_all used to switch off tests on CRAN
test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))
             #identical (Sys.getenv ("APPVEYOR"), "True"))

source ('../stub.R')

# Mock tests as discussed by Noam Ross here:
# https://discuss.ropensci.org/t/best-practices-for-testing-api-packages/460
# and demonstrated in detail by Gabor Csardi here:
# https://github.com/MangoTheCat/blog-with-mock/blob/master/Blogpost1.md
# Note that file can be downloaded in configure file, but this produces a very
# large file in the installed package (>2MB), whereas this read_html version
# yields a file <1/10th the size.
get_local <- FALSE
if (get_local)
{
    # This test needs to return the results of overpass_query(), not the direct
    # httr::POST call, so can't be grabbed with curl_fetch_memory
    qry <- opq (bbox = c(-0.118, 51.514, -0.115, 51.517))
    qry <- add_osm_feature (qry, key = 'highway')
    overpass_query_result <- overpass_query (opq_string (qry),
                                             encoding = 'UTF-8')
    save (overpass_query_result, file = "../overpass_query_result.rda")
    # but then overpass_query itself needs to be tested, so fetch_memory is used
    # here
    base_url <- 'https://overpass-api.de/api/interpreter'
    cfm_output_overpass_query <- NULL
    trace(
          curl::curl_fetch_memory,
          exit = function() {
              cfm_output_overpass_query <<- returnValue()
          })
    res <- httr::POST (base_url, body = opq_string (qry))
    untrace (curl::curl_fetch_memory)
    class (cfm_output_overpass_query) <- 'response'
    save (cfm_output_overpass_query, file = '../cfm_output_overpass_query.rda')
}

context ('overpass query')

test_that ('query-construction', {
    q0 <- opq (bbox = c(-0.12, 51.51, -0.11, 51.52))
    expect_error (q1 <- add_osm_feature (q0), 'key must be provided')
    expect_silent (q1 <- add_osm_feature (q0, key = 'aaa')) # bbox from qry
    q0$bbox <- NULL
    expect_error (q1 <- add_osm_feature (q0, key = 'aaa'),
              'Bounding box has to either be set in opq or must be set here')
    q0 <- opq (bbox = c(-0.12, 51.51, -0.11, 51.52))
    q1 <- add_osm_feature (q0, key = 'aaa')
    expect_false (grepl ('=', q1$features))
    q1 <- add_osm_feature (q0, key = 'aaa', value = 'bbb')
    expect_true (grepl ('=', q1$features))
    expect_message (
                q1 <- add_osm_feature (q0, key = 'aaa', value = 'bbb',
                                       key_exact = FALSE),
                "key_exact = FALSE can only combined with value_exact = FALSE;")
    expect_silent (
                q1 <- add_osm_feature (q0, key = 'aaa', value = 'bbb',
                                       key_exact = FALSE, value_exact = FALSE))
          })

test_that ("add feature", {
    qry <- opq (bbox = c(-0.118, 51.514, -0.115, 51.517))
    qry1 <- add_osm_feature (qry, key = 'highway')
    qry2 <- add_osm_feature (qry, key = 'highway', value = "primary")
    qry3 <- add_osm_feature (qry, key = 'highway',
                             value = c ("primary", "tertiary"))
    expect_identical (qry1$features, " [\"highway\"]")
    expect_identical (qry2$features, " [\"highway\"=\"primary\"]")
    expect_identical (qry3$features,
                      " [\"highway\"~\"^(primary|tertiary)$\"]")
          })

test_that ('make_query', {
    qry <- opq (bbox = c(-0.118, 51.514, -0.115, 51.517))
    qry <- add_osm_feature (qry, key = 'highway')

    if (!has_internet) {
        expect_error (osmdata_xml (qry),
                      'Overpass query unavailable without internet')
        expect_error (osmdata_sf (qry),
                      'Overpass query unavailable without internet')
        expect_error (osmdata_sp (qry),
                      'Overpass query unavailable without internet')
        expect_error (osmdata_sc (qry),
                      'Overpass query unavailable without internet')
    } else
    {
        # Test all `osmdata_..` functions by stubbing the results of
        # `overpass_query()`
        load ("../overpass_query_result.rda")
        stub (osmdata_xml, 'overpass_query', function (x, ...)
              overpass_query_result)
        doc <- osmdata_xml (qry)
        expect_true (is (doc, 'xml_document'))
        expect_silent (osmdata_xml (qry, file = 'junk.osm'))

        if (test_all) {
            res <- osmdata_sp (qry)
            expect_message (print (res), "Object of class 'osmdata' with")
            expect_silent (res <- osmdata_sp (qry, doc))
            expect_message (print (res), "Object of class 'osmdata' with")
            expect_silent (res <- osmdata_sp (qry, 'junk.osm'))
            expect_message (res <- osmdata_sp (qry, 'junk.osm', quiet = FALSE))

            expect_s3_class (res, 'osmdata')
            nms <- c ('bbox', 'overpass_call', 'meta', 'osm_points',
                      'osm_lines', 'osm_polygons', 'osm_multilines',
                      'osm_multipolygons')
            expect_named (res, expected = nms, ignore.order = FALSE)
            nms <- c ("timestamp", "OSM_version", "overpass_version")
            expect_named (res$meta, expected = nms)

            res <- osmdata_sf (qry)
            expect_message (print (res), "Object of class 'osmdata' with")
            expect_silent (res <- osmdata_sf (qry, doc))
            expect_message (print (res), "Object of class 'osmdata' with")
            expect_silent (res <- osmdata_sf (qry, 'junk.osm'))
            expect_message (res <- osmdata_sf (qry, 'junk.osm', quiet = FALSE))
            expect_s3_class (res, 'osmdata')
            nms <- c ('bbox', 'overpass_call', 'meta', 'osm_points',
                      'osm_lines', 'osm_polygons', 'osm_multilines',
                      'osm_multipolygons')
            expect_named (res, expected = nms, ignore.order = FALSE)
        }

        if (file.exists ('junk.osm')) invisible (file.remove ('junk.osm'))
    }
})

test_that ('query-no-quiet', {
    qry <- opq (bbox = c(-0.118, 51.514, -0.115, 51.517))
    qry <- add_osm_feature (qry, key = 'highway')
    if (!test_all) {
        load ("../overpass_query_result.rda")
        stub (osmdata_xml, 'overpass_query', function (x, ...)
              overpass_query_result)
        expect_silent (x <- osmdata_xml (qry, quiet = FALSE))
    } else {
        expect_message (x <- osmdata_xml (qry, quiet = FALSE),
                        "Issuing query to Overpass API")
        expect_message (x <- osmdata_sp (qry, quiet = FALSE),
                        "Issuing query to Overpass API")
        expect_message (x <- osmdata_sf (qry, quiet = FALSE),
                        "Issuing query to Overpass API")
        expect_message (x <- osmdata_sc (qry, quiet = FALSE),
                        "Issuing query to Overpass API")
    }
})
