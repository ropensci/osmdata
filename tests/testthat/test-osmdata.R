has_internet <- curl::has_internet ()
is_cran <-  identical (Sys.getenv("NOT_CRAN"), "false")
is_travis <-  identical (Sys.getenv("TRAVIS"), "true")


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
    qry <- opq (bbox=c(-0.12,51.11,-0.11,51.12)) 
    qry <- add_feature (qry, key='highway', value='tertiary')
    qry <- paste0 (c (qry$features, qry$suffix), collapse="\n")

    cfm_output_overpass_query <- NULL
    trace(
          curl::curl_fetch_memory,
          exit = function() { cfm_output_overpass_query <<- returnValue() }
          )
    res <- httr::POST (base_url, body=qry)
    #names (cfm_output_make_query)
    untrace (curl::curl_fetch_memory)
    save (cfm_output_overpass_query, 
          file="./tests/testthat/cfm_output_overpass_query.rda")
}

context ("overpass query")

test_that ("overpass null values", {
    expect_error (overpass_query (), "query must be supplied")
    expect_error (overpass_query (1), 
                "query must contain nothing but character strings")
})

test_that ("query-construction", {
    q0 <- opq (bbox=c(-0.12,51.11,-0.11,51.12)) 
    expect_error (q1 <- add_feature (q0), 'key must be provided')
    expect_silent (q1 <- add_feature (q0, key='aaa')) # bbox from qry
    q0$bbox <- NULL
    expect_error (q1 <- add_feature (q0, key='aaa'),
                  'Bounding box has to either be set in opq or must be set here') 
    q0 <- opq (bbox=c(-0.12,51.11,-0.11,51.12)) 
    q1 <- add_feature (q0, key='aaa')
    expect_false (grepl ('=', q1$features [2])) # [2] is the main query
    q1 <- add_feature (q0, key='aaa', value='bbb')
    expect_true (grepl ('=', q1$features [2])) # [2] is the main query
})

test_that ("make_query", {
    qry <- opq (bbox=c(-0.12,51.11,-0.11,51.12)) 
    qry <- add_feature (qry, key='highway', value='tertiary')

    if (!has_internet) {
        expect_message (overpass_query (qry), 
          "Overpass query unavailable without internet", call.=FALSE)
    } else 
    {
        if (is_cran)
        {
          load("cfm_output_overpass_query.rda")
          stub (overpass_query, 'httr::POST', 
                function (x, ...) cfm_output_overpass_query$content )
        } 
        # NOTE: This still issues a query for overpass_status
        doc <- osmdata_xml (qry)
        expect_true (is (doc, "xml_document"))
        expect_silent (osmdata_xml (qry, file="junk.osm"))

        res <- osmdata_sp (qry)
        expect_message (print (res), "Object of class 'osmdata' with")
        expect_silent (res <- osmdata_sp (qry, doc))
        expect_message (print (res), "Object of class 'osmdata' with")
        expect_silent (res <- osmdata_sp (qry, "junk.osm"))
        expect_message (res <- osmdata_sp (qry, "junk.osm", quiet=FALSE))

        expect_s3_class (res, "osmdata")
        nms <- c ("bbox", "overpass_call", "timestamp", "osm_points",
                  "osm_lines", "osm_polygons", "osm_multilines",
                  "osm_multipolygons")
        expect_named (res, expected=nms, ignore.order=FALSE)

        res <- osmdata_sf (qry)
        expect_message (print (res), "Object of class 'osmdata' with")
        expect_silent (res <- osmdata_sf (qry, doc))
        expect_message (print (res), "Object of class 'osmdata' with")
        expect_silent (res <- osmdata_sf (qry, "junk.osm"))
        expect_message (res <- osmdata_sf (qry, "junk.osm", quiet=FALSE))
        expect_s3_class (res, "osmdata")
        nms <- c ("bbox", "overpass_call", "timestamp", "osm_points",
                  "osm_lines", "osm_polygons", "osm_multilines",
                  "osm_multipolygons")
        expect_named (res, expected=nms, ignore.order=FALSE)

        if (file.exists ("junk.osm")) file.remove ("junk.osm")
    }
})

