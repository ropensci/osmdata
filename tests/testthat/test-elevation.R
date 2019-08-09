has_internet <- curl::has_internet ()

# test_all used to switch off tests on CRAN
test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))
             #identical (Sys.getenv ("APPVEYOR"), "True"))

source ('../stub.R')

context ("elevation")

test_that ("osmdata_sc", {
    qry <- opq (bbox = c(-0.118, 51.514, -0.115, 51.517)) %>%
        add_osm_feature (key = 'highway')

    load ("../overpass_query_result.rda")
    stub (osmdata_xml, 'overpass_query', function (x, ...)
          overpass_query_result)

    f <- file.path (tempdir (), "junk.osm")
    doc <- osmdata_xml (qry, file = f)
    expect_silent (x <- osmdata_sc (qry, doc = f))

    #elev_file = "/data/data/elevation/srtm_36_02.zip"
    #x <- osm_elevation (x, elev_file = elev_file)
             })
