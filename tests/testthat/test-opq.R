
context ("opq functions")

test_that ("datetime", {

    q0 <- opq (bbox = c(-0.118, 51.514, -0.115, 51.517))
    expect_error (opq (bbox = c(-0.118, 51.514, -0.115, 51.517),
                       datetime = "blah"),
                  "datetime must be in ISO8601 format")
    q1 <- opq (bbox = c(-0.118, 51.514, -0.115, 51.517),
               datetime = "2015-01-01T00:00:00Z")

    expect_true (!identical (q0, q1))
    expect_identical (names (q0), names (q1))
    expect_identical (q0 [!names (q0) == "prefix"],
                      q1 [!names (q1) == "prefix"])
    expect_true (grepl ("date\\:", q1$prefix))

    expect_error (opq (bbox = c(-0.118, 51.514, -0.115, 51.517),
                       datetime = "2015-01-01T00:00:00Z",
                       datetime2 = "blah"),
                  "datetime must be in ISO8601 format")

    q2 <- opq (bbox = c(-0.118, 51.514, -0.115, 51.517),
               datetime = "2015-01-01T00:00:00Z",
               datetime2 = "2015-01-02T00:00:00Z")
    expect_true (!identical (q0, q2))
    expect_identical (names (q0), names (q2))
    expect_identical (q0 [!names (q0) == "prefix"],
                      q2 [!names (q2) == "prefix"])
    expect_true (!grepl ("date\\:", q2$prefix))
    expect_true (grepl ("diff\\:", q2$prefix))
})

test_that ("opq_osm_id", {

    expect_error (q <-opq_osm_id (),
                  "type must be specified: one of node, way, or relation")
    expect_error (opq_osm_id (type = "a"),
                  "'arg' should be one of")
    expect_error (opq_osm_id (type = "node"),
                  "id must be specified")
    expect_error (opq_osm_id (type = "node", id = 1L),
                  "id must be character or numeric.")
    expect_error (opq_osm_id (type = "node", id = 1:2 + 0.1),
                  "Only a single id may be entered.")
    expect_s3_class (x <- opq_osm_id (type = "node", id = 123456),
                     "overpass_query")
    expect_identical (names (x),
                      c ("prefix", "suffix", "id"))
    expect_type (x$id, "list")
    expect_identical (names (x$id), c ("type", "id"))
    expect_identical (x$id$type, "node")
    expect_identical (x$id$id, "123456")
})

test_that ("opq_enclosing", {

    expect_error (opq_enclosing (),
                  "'lon' and 'lat' must be provided.")
    lat <- 54.33601
    lon <- -3.07677
    expect_s3_class (x <- opq_enclosing (lon, lat),
                     "overpass_query")
    expect_length (x$features, 0L)

    key <- "natural"
    value <- "water"
    expect_s3_class (x <- opq_enclosing (lon, lat, key = key, value = value),
                     "overpass_query")
    expect_true (length (x$features) == 1L)
    expect_type (x$features, "character")
    expect_true (grepl ("natural", x$features))
    expect_true (grepl ("water", x$features))
})
