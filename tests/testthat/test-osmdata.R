has_internet <- curl::has_internet ()
is_cran <-  identical (Sys.getenv("NOT_CRAN"), "false")
is_travis <-  identical (Sys.getenv("TRAVIS"), "true")

context("nodes work")
#test_that("nodes work", {
#  only_nodes <- system.file("osm/only-nodes.osm", package="overpass")
#  expect_that(read_osm(only_nodes), is_a("SpatialPointsDataFrame"))
#})

context("nodes & ways work")
#test_that("nodes & ways work", {
#  nodes_and_ways <- system.file("osm/nodes-and-ways.osm", package="overpass")
#  expect_that(read_osm(nodes_and_ways), is_a("SpatialLinesDataFrame"))
#})

context("xml nodes & ways work")
#test_that("xml nodes & ways work", {
#  nodes_and_ways <- system.file("osm/actual-ways.osm", package="overpass")
#  expect_that(read_osm(nodes_and_ways), is_a("SpatialLinesDataFrame"))
#})

context("duplicates (and large XML return) are handled")
#test_that("duplicates are handled", {
#  mammoth <- system.file("osm/mammoth.osm", package="overpass")
#  expect_that(read_osm(mammoth), is_a("SpatialLinesDataFrame"))
#})

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
    res <- osmdata_xml (qry)
    expect_true (is (res, "xml_document"))

    res <- osmdata_sp (qry)
    expect_s3_class (res, "osmdata")
    nms <- c ("bbox", "overpass_call", "timestamp", "osm_points",
              "osm_linestrings", "osm_polygons", "osm_multilinestrings",
              "osm_multipolygons")
    expect_named (res, expected=nms, ignore.order=FALSE)

    res <- osmdata_sf (qry)
    expect_s3_class (res, "osmdata")
    nms <- c ("bbox", "overpass_call", "timestamp", "osm_points",
              "osm_linestrings", "osm_polygons", "osm_multilinestrings",
              "osm_multipolygons")
    expect_named (res, expected=nms, ignore.order=FALSE)
  }
})

