
context ("opq functions")

test_that ("datetime", {

    q0 <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517))
    expect_error (
        opq (
            bbox = c (-0.118, 51.514, -0.115, 51.517),
            datetime = "blah"
        ),
        "datetime must be in ISO8601 format"
    )
    q1 <- opq (
        bbox = c (-0.118, 51.514, -0.115, 51.517),
        datetime = "2015-01-01T00:00:00Z"
    )

    expect_true (!identical (q0, q1))
    expect_identical (names (q0), names (q1))
    expect_identical (
        q0 [!names (q0) == "prefix"],
        q1 [!names (q1) == "prefix"]
    )
    expect_true (grepl ("date\\:", q1$prefix))

    expect_error (
        opq (
            bbox = c (-0.118, 51.514, -0.115, 51.517),
            datetime = "2015-01-01T00:00:00Z",
            datetime2 = "blah"
        ),
        "datetime must be in ISO8601 format"
    )

    q2 <- opq (
        bbox = c (-0.118, 51.514, -0.115, 51.517),
        datetime = "2015-01-01T00:00:00Z",
        datetime2 = "2015-01-02T00:00:00Z"
    )
    expect_true (!identical (q0, q2))
    expect_identical (names (q0), names (q2))
    expect_identical (
        q0 [!names (q0) == "prefix"],
        q2 [!names (q2) == "prefix"]
    )
    expect_true (!grepl ("date\\:", q2$prefix))
    expect_true (grepl ("diff\\:", q2$prefix))
})

test_that ("opq_string", {

    # bbox only:
    expect_silent (
        q0 <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517))
    )
    expect_silent (
        s0 <- opq_string (q0)
    )
    expect_message (
        s0 <- opq_string_intern (q0, quiet = FALSE),
        paste0 (
            "The overpass server is intended to ",
            "be used to extract specific features"
        )
    )
    expect_type (s0, "character")
    expect_length (s0, 1L)
    expect_false (grepl ("key", s0))
    expect_false (grepl ("value", s0))
    expect_true (grepl ("out body", s0)) # full data body; (nodes,ways,rels)

    # nodes_only parameter:
    q1 <- opq (
        bbox = c (-0.118, 51.514, -0.115, 51.517),
        nodes_only = TRUE
    )
    s1 <- opq_string (q1)
    # nodes only, so "out" instead of "out body"
    expect_false (grepl ("out body", s1))

    # key-value pair:
    q2 <- add_osm_feature (q0, key = "highway", value = "!primary")
    s2 <- opq_string (q2)
    expect_true (grepl ("highway", s2))
    expect_true (grepl ("primary", s2))

    # opq_enclosing:
    lat <- 54.33601
    lon <- -3.07677
    key <- "natural"
    value <- "water"
    expect_s3_class (
        q3 <- opq_enclosing (lon, lat, key = key, value = value),
        "overpass_query"
    )
    expect_length (q3$features, 1L)
    s3 <- opq_string (q3)
    expect_true (grepl (key, s3))
    expect_true (grepl (value, s3))
    # the object -> pivot calls for an enclosing query:
    expect_true (grepl ("\\->\\.a", s3))
    expect_true (grepl ("pivot\\.a", s3))

    # opq_osm_id:
    q4 <- opq_osm_id (id = 1, type = "node")
    s4 <- opq_string (q4)
    expect_true (grepl ("id\\:", s4))
    expect_true (grepl ("node", s4))
    expect_false (grepl ("way", s4))
    expect_false (grepl ("rel", s4))
})

test_that ("opq_osm_id", {

    expect_error (
        q <- opq_osm_id (),
        "type must be specified: one of node, way, or relation"
    )
    expect_error (
        opq_osm_id (type = "a"),
        "'arg' should be one of"
    )
    expect_error (
        opq_osm_id (type = "node"),
        "id must be specified"
    )
    expect_error (
        opq_osm_id (type = "node", id = 1L),
        "id must be character or numeric."
    )
    expect_error (
        opq_osm_id (type = "node", id = 1:2 + 0.1),
        "Only a single id may be entered."
    )
    expect_s3_class (
        x <- opq_osm_id (type = "node", id = 123456),
        "overpass_query"
    )
    expect_identical (
        names (x),
        c ("prefix", "suffix", "id")
    )
    expect_type (x$id, "list")
    expect_identical (names (x$id), c ("type", "id"))
    expect_identical (x$id$type, "node")
    expect_identical (x$id$id, "123456")
})

test_that ("opq_enclosing", {

    expect_error (
        opq_enclosing (),
        "'lon' and 'lat' must be provided."
    )
    lat <- 54.33601
    lon <- -3.07677
    expect_s3_class (
        x <- opq_enclosing (lon, lat),
        "overpass_query"
    )
    expect_length (x$features, 0L)

    key <- "natural"
    value <- "water"
    expect_s3_class (
        x <- opq_enclosing (lon, lat, key = key, value = value),
        "overpass_query"
    )
    expect_true (length (x$features) == 1L)
    expect_type (x$features, "character")
    expect_true (grepl ("natural", x$features))
    expect_true (grepl ("water", x$features))
})

test_that ("opq_around", {

    expect_error (
        opq_around (),
        "argument \"lat\" is missing, with no default"
    )
    lat <- 54.33601
    lon <- -3.07677
    expect_silent (x <- opq_around (lon, lat))
    expect_type (x, "character")
    expect_length (x, 1L)
    expect_false (grepl ("key", x))
    expect_false (grepl ("value", x))

    expect_silent (x_key <- opq_around (lon, lat, key = "key"))
    expect_true (!identical (x_key, x))
    expect_true (grepl ("key", x_key))
    expect_false (grepl ("value", x_key))

    expect_silent (
        x_key_val <- opq_around (lon, lat, key = "key", value = "val")
    )
    expect_true (!identical (x_key, x_key_val))
    expect_true (grepl ("key", x_key_val))
    expect_true (grepl ("val", x_key_val))
})
