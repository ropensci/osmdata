
test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("GITHUB_WORKFLOW"), "test-coverage"))

test_that ("available_features", {

    expect_error (available_features (1), "unused argument")
    f <- available_features ()
    expect_is (f, "character")
    expect_true (length (f) > 1L)
})

test_that ("available_tags", {

    expect_error (available_tags ("highway", 1), "unused argument")
    x <- available_tags ("junk")
    expect_length (x, 0L)
    x <- available_tags ("highway")
    expect_is (x, "character")
    expect_true (length (x) > 1L)
})
