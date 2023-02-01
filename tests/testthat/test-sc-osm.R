context ("sc-osm")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
    identical (Sys.getenv ("GITHUB_WORKFLOW"), "test-coverage"))

# Current names of SC objects as returned by osmdata:
sc_names <- c (
    "nodes", "relation_members", "relation_properties",
    "object", "object_link_edge", "edge", "vertex", "meta"
)

test_that ("multipolygon", {
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_sc (q0, test_path ("fixtures", "osm-multi.osm"))
    # TODO: Write proper tests
    expect_is (x, "SC")
    expect_equal (names (x), sc_names)
})


test_that ("ways", {
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_sc (q0, test_path ("fixtures", "osm-ways.osm"))
    expect_is (x, "SC")
    expect_equal (names (x), sc_names)
})


test_that ("non-valid key names", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x <- osmdata_sc (q0, osm_multi)

    k<- lapply (x[c ("nodes", "relation_properties", "object")], function (f) {
        expect_true ("name:ca" %in% f$key)
    })
})

# test_that ("clashes in key names", {
#     osm_multi_key_clashes <- test_path ("fixtures", "osm-key_clashes.osm")
#     q0 <- opq (bbox = c (1, 1, 5, 5))
#     x <- osmdata_sc (q0, osm_multi_key_clashes)
#
#     k <- lapply (x[c ("nodes", "relation_properties", "object")], function (f) {
#         expect_false (any ( duplicated (f$key)))
#     })
# })
