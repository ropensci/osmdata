
# Note: the html files produced by these calls, and stored by `httptest2`, are
# huge (> 1MB each), so have to be "post-processeed" here to reduce them to a
# small sample only. Post-process of features is done in the test call; tags are
# done via separate fn defined below.

test_that ("available_features", {

    expect_error (available_features (1), "unused argument")

    post_process <- !dir.exists ("mock_features")
    f <- with_mock_dir ("mock_features", {
        available_features ()
    })

    if (post_process) {
        fname <- list.files ("mock_features",
            full.names = TRUE,
            recursive = TRUE
        ) [1]
        x <- xml2::read_html (fname)
        nodes_all <- rvest::html_nodes (x, "td")
        nodes_sample <- nodes_all [1:20]
        writeLines (as.character (nodes_sample), fname)
    }

    expect_is (f, "character")
    expect_true (length (f) > 1L)
})


post_process_tags <- function (dir_name, sample_index = 1:10, feature = NULL) {

    fname <- list.files (dir_name,
        full.names = TRUE,
        recursive = TRUE
    ) [1]
    x <- xml2::read_html (fname)
    nodes_all <- rvest::html_nodes (x, "div[class='taglist']")
    if (!is.null (feature)) {
        # see features.R/available_tags() for details:
        nodes_sample <- rvest::html_nodes (
            x,
            sprintf ("a[title^='Tag:%s']", feature)
        )
    } else {
        nodes_sample <- nodes_all [sample_index]
    }
    writeLines (as.character (nodes_sample), fname)
}

test_that ("available_tags", {

    expect_error (available_tags ("highway", 1), "unused argument")
    post_process <- !dir.exists ("mock_tags_fail")
    tags <- with_mock_dir ("mock_tags_fail", {
        available_tags ("junk")
    })
    if (post_process) {
        post_process_tags ("mock_tags_fail", 1:10)
    }
    expect_length (tags, 0L)

    post_process <- !dir.exists ("mock_tags")
    tags <- with_mock_dir ("mock_tags", {
        available_tags ("highway")
    })
    if (post_process) {
        post_process_tags ("mock_tags", feature = "highway")
    }
    expect_is (tags, "character")
    expect_true (length (tags) > 1L)
})
