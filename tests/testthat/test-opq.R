
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
        "datetime2 must be in ISO8601 format"
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

test_that ("adiff", {

    q0 <- opq (
        bbox = c (-0.118, 51.514, -0.115, 51.517),
        datetime = "2015-01-01T00:00:00Z"
    )
    q1 <- opq (
        bbox = c (-0.118, 51.514, -0.115, 51.517),
        datetime = "2015-01-01T00:00:00Z",
        adiff = TRUE
    )


    expect_true (!identical (q0, q1))
    expect_identical (names (q0), names (q1))
    expect_identical (
        q0 [!names (q0) == "prefix"],
        q1 [!names (q1) == "prefix"]
    )
    expect_true (!grepl ("date\\:", q1$prefix))
    expect_true (grepl ("adiff\\:", q1$prefix))

    expect_error (
        opq (
            bbox = c (-0.118, 51.514, -0.115, 51.517),
            datetime = "2015-01-01T00:00:00Z",
            datetime2 = "blah",
            adiff = TRUE
        ),
        "datetime2 must be in ISO8601 format"
    )

    q2 <- opq (
        bbox = c (-0.118, 51.514, -0.115, 51.517),
        datetime = "2015-01-01T00:00:00Z",
        datetime2 = "2015-01-02T00:00:00Z"
    )
    q3 <- opq (
        bbox = c (-0.118, 51.514, -0.115, 51.517),
        datetime = "2015-01-01T00:00:00Z",
        datetime2 = "2015-01-02T00:00:00Z",
        adiff = TRUE
    )
    expect_true (!identical (q2, q3))
    expect_identical (names (q2), names (q3))
    expect_identical (
        q2 [!names (q2) == "prefix"],
        q3 [!names (q3) == "prefix"]
    )
    expect_true (!grepl ("date\\:", q3$prefix))
    expect_true (grepl ("adiff\\:", q3$prefix))
})

test_that ("osm_types", {

    q0 <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517))
    expect_error (
        q <- opq (
            bbox = c (-0.118, 51.514, -0.115, 51.517),
            osm_types = "blah"
        ),
        'osm_types parameter must be a vector with values from "node", "way", '
    )

    q1 <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517), osm_types = "nwr")
    expect_true (!identical (q0, q1))
    expect_identical (names (q0), names (q1))
    expect_identical (
        q0 [names (q0) != "osm_types"],
        q1 [names (q1) != "osm_types"]
    )
    expect_true ("nwr" == q1$osm_types)

    features <- c (
        "\"amenity\"=\"school\"",
        "\"amenity\"=\"kindergarten\"",
        "\"amenity\"=\"music_school\"",
        "\"amenity\"=\"language_school\"",
        "\"amenity\"=\"dancing_school\""
    )
    q2 <- opq ("relation(id:349053)") %>% # "Catalunya"
        add_osm_features(features = features)
    s <- opq_string (q2)

    n_fts <- length (features)
    n_fts_in_query <- length (gregexpr ("amenity", s) [[1]])
    # Query should have that number repeated for each osm_types (default to
    # node, way, relation):
    expect_equal (n_fts_in_query, n_fts * length(q2$osm_types))

    # nodes_only
    q3 <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517), nodes_only = TRUE)
    expect_silent (
        q4 <- opq (
            bbox = c (-0.118, 51.514, -0.115, 51.517),
            nodes_only = TRUE,
            osm_types = "blah" # ignored if nodes_only == TRUE
        )
    )

    expect_identical (q3, q4)
    expect_true (q4$osm_types == "node")
})

test_that ("out", {

    q0 <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517))
    expect_error (
        q <- opq (
            bbox = c (-0.118, 51.514, -0.115, 51.517),
            out = "blah"
        ),
        'out parameter must be "body", "tags", "meta", "skel", "tags center" or "ids".'
    )

    q_geo <- lapply (c ("meta", "skel"), function (x) {
        q <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517), out = x)
        expect_true (!identical (q0, q))
        expect_identical (names (q0), names (q))
        expect_identical (
            q0 [names (q0) != "suffix"],
            q [names (q) != "suffix"]
        )
        expect_true (grepl ("^\\);\\n\\(\\._;>;\\);\\nout [a-z ]+;$", q$suffix))
    })
    q_no_geo <- lapply (c ("tags", "tags center", "ids"), function (x) {
        q <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517), out = x)
        expect_true (!identical (q0, q))
        expect_identical (names (q0), names (q))
        expect_identical (
            q0 [names (q0) != "suffix"],
            q [names (q) != "suffix"]
        )
        expect_true (grepl ("^\\); out [a-z ]+;$", q$suffix))
    })

    # nodes_only
    q1 <- opq (bbox = c (-0.118, 51.514, -0.115, 51.517), nodes_only = TRUE)
    expect_error (
        q <- opq (
            bbox = c (-0.118, 51.514, -0.115, 51.517),
            out = "blah"
        ),
        'out parameter must be "body", "tags", "meta", "skel", "tags center" or "ids".'
    )

    q_geo <- lapply (c ("meta", "skel"), function (x) {
        q <- opq (
            bbox = c (-0.118, 51.514, -0.115, 51.517),
            nodes_only = TRUE, out = x
        )
        expect_true (!identical (q1, q))
        expect_identical (names (q1), names (q))
        expect_identical (
            q1 [names (q1) != "suffix"],
            q [names (q) != "suffix"]
        )
        expect_true (grepl ("^\\); out[a-z ]+;$", q$suffix))
    })
    q_no_geo <- lapply (c ("tags", "tags center", "ids"), function (x) {
        q <- opq (
            bbox = c (-0.118, 51.514, -0.115, 51.517),
            nodes_only = TRUE, out = x
        )
        expect_true (!identical (q1, q))
        expect_identical (names (q1), names (q))
        expect_identical (
            q1 [names (q1) != "suffix"],
            q [names (q) != "suffix"]
        )
        expect_true (grepl ("^\\); out[a-z ]+;$", q$suffix))
    })
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

    # area only:
    expect_silent (
        q0 <- opq (bbox = "relation(id:11747082)")
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
    # nodes only, so "out" instead of "out body" and no way nor relation
    expect_false (grepl ("\\(\\._;>;\\)", s1))
    expect_false (grepl ("way|relation", s1))

    q1 <- opq (
        bbox = "relation(id:11747082)",
        nodes_only = TRUE
    )
    s1 <- opq_string (q1)
    # nodes only, so "out" instead of "out body" and no way nor relation on clauses
    expect_false (grepl ("\\(\\._;>;\\)", s1))
    expect_false (all (grepl ("way|relation", strsplit (s1, "\\n") [[1]] [-2])))

    # nodes_only parameter with features:
    q1 <- opq (
        bbox = c (-0.118, 51.514, -0.115, 51.517),
        nodes_only = TRUE
    )
    q1 <- add_osm_feature (q1, key = "amenity", value = "restaurant")
    s1 <- opq_string (q1)
    # nodes only, so "out" instead of "out body" and no way nor relation
    expect_false (grepl ("\\(\\._;>;\\)", s1))
    expect_false (grepl ("way|relation", s1))

    q1 <- opq (
        bbox = "relation(id:11747082)",
        nodes_only = TRUE
    )
    q1 <- add_osm_feature (q1, key = "amenity", value = "restaurant")
    s1 <- opq_string (q1)
    # nodes only, so "out" instead of "out body" and no way nor relation on clauses
    expect_false (grepl ("\\(\\._;>;\\)", s1))
    expect_false (all (grepl ("way|relation", strsplit (s1, "\\n") [[1]] [-2])))

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
        "type must be specified: one of node, way, or relation if id is 'NULL'"
    )
    expect_error (
        opq_osm_id (type = "a"),
        'type items must be "node", "way" or "relation".'
    )
    expect_error (
        opq_osm_id (type = "node"),
        "id must be specified"
    )
    expect_error (
        opq_osm_id (type = "node", id = 1L),
        "id must be character or numeric."
    )
    expect_s3_class (
        opq_osm_id (type = "node", id = 1:2 + 0.1),
        "overpass_query"
    )
    expect_s3_class (
        opq_osm_id (id = c (paste0 ("node/", 1:2), "way/1")),
        "overpass_query"
    )
    expect_s3_class (
        x <- opq_osm_id (type = c ("node", "way"), id = 1:4 + 0.1),
        "overpass_query"
    )
    expect_error (
        x <- opq_osm_id (type = c ("node", "way"), id = 1:3 + 0.1),
        "id length must be a multiple of type length."
    )
    expect_identical (
        opq_osm_id (type = "node", id = 123456),
        opq_osm_id (id = "node/123456")
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

test_that ("opq_csv", {

    q <- opq (bbox = c (8.42, -1.24, 42.92, 28.03))
    expect_error (
        opq_csv (q),
        'argument "fields" is missing, with no default'
    )
    expect_error (
        opq_csv (42),
        "q must be an overpass query or a character string."
    )
    expect_error (
        opq_csv (q, fields = 1:3),
        "fields must be a character vector"
    )

    q0 <- opq_csv (q, fields = "name")
    expect_identical (
        q [!names (q) == "prefix"],
        q0 [!names (q0) == "prefix"]
    )
    expect_s3_class (q0, "overpass_query")
    expect_true (grepl ("\\[out:csv", q0$prefix))
    expect_true (!grepl ("\\[out:xml", q0$prefix))
    expect_true (!identical (q, q0))
    expect_identical (attributes (q), attributes (q0))

    qdate <- opq (
        bbox = c (8.42, -1.24, 42.92, 28.03),
        datetime = "2014-09-11T00:00:00Z",
    )
    qdate <- opq_string (qdate)
    q1 <- opq_csv (qdate, fields = "name")
    expect_is (q1, "character")
    expect_identical (
        gsub ("\\[out:csv\\(.+\\)]", "[out:xml]", q1),
        qdate
    )

    qadiff <- opq (
        bbox = c (8.42, -1.24, 42.92, 28.03),
        datetime = "2017-10-01T00:00:00Z",
        datetime2 = "2017-11-09T00:00:00Z",
        adiff = TRUE
    )
    q2 <- opq_csv (qadiff, fields = "name")
    expect_identical (
        qadiff [!names (qadiff) == "prefix"],
        q2 [!names (q2) == "prefix"]
    )
    expect_s3_class (q2, "overpass_query")
    expect_true (grepl ("\\[out:csv", q2$prefix))
    expect_true (!grepl ("\\[out:xml", q2$prefix))
    expect_true (!identical (qadiff, q2))
    expect_identical (attributes (qadiff), attributes (q2))

    qid <- opq_osm_id (id = c (paste0 ("node/", 1:2), "way/1"))
    q3 <- opq_csv (qid, fields = "name")
    expect_identical (
        qid [!names (qid) == "prefix"],
        q3 [!names (q3) == "prefix"]
    )
    expect_s3_class (q3, "overpass_query")
    expect_true (grepl ("\\[out:csv", q3$prefix))
    expect_true (!grepl ("\\[out:xml", q3$prefix))
    expect_true (!identical (qid, q3))
    expect_identical (attributes (qid), attributes (q3))

    qenc <- opq_enclosing (lon = 2.4565596, lat = 42.5189047)
    q4 <- opq_csv (qenc, fields = "name")
    expect_identical (
        qenc [!names (qenc) == "prefix"],
        q4 [!names (q4) == "prefix"]
    )
    expect_s3_class (q4, "overpass_query")
    expect_true (grepl ("\\[out:csv", q4$prefix))
    expect_true (!grepl ("\\[out:xml", q4$prefix))
    expect_true (!identical (qenc, q4))
    expect_identical (attributes (qenc), attributes (q4))

    qaround <- opq_around (lon = 2.4565596, lat = 42.5189047)
    q5 <- opq_csv (qaround, fields = "name")
    expect_is (q5, "character")
    expect_identical (
        gsub ("\\[out:csv\\(.+\\)]", "[out:xml]", q5),
        qaround
    )
})
