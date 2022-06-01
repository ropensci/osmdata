
test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("GITHUB_WORKFLOW"), "test-coverage"))

test_that ("available_features", {

    expect_error (available_features (1), "unused argument")
    expect_is (available_features (), "character")
})

test_that ("available_tags", {

    expect_error (available_tags ("highway", 1), "unused argument")
    expect_that (length (available_tags ("junk")), equals (0))
    expect_is (available_tags ("highway"), "character")
})
