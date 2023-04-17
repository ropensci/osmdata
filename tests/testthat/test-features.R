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
        nodes_all <- rvest::html_elements (x, "td")
        nodes_sample <- nodes_all [1:20]
        writeLines (as.character (nodes_sample), fname)
    }

    expect_is (f, "character")
    expect_true (length (f) > 1L)
})


#' The raw HTML files are > 1MB. This function reduces their size by selecting
#' just a few sample nodes, and only tables for a specific key. Note that keys
#' like "highway" still correspond to overly large tables. The default key
#' corresponds to the item in `tables_r` below which has the smallest number of
#' rows.
#' @noRd
post_process_tags <- function (dir_name, keys = "building") {

    fname <- list.files (dir_name,
        full.names = TRUE,
        recursive = TRUE
    ) [1]

    x <- xml2::read_html (fname)

    nodes_sample <- rvest::html_elements (x, "div[class='taglist']") [1:10]

    tables <- rvest::html_elements (x, "table")
    tables_r <- rvest::html_table (tables)
    index <- which (vapply (tables_r, function (i) {
        ret <- FALSE
        if ("Key" %in% names (i)) {
            ret <- any (keys %in% i$Key)
        }
        return (ret)
    }, logical (1L)))

    tables_sample <- xml2::xml_child (tables, index)
    table_body <- xml2::xml_children (tables_sample)
    rm_rows <- table_body [10:length (table_body)]
    xml2::xml_remove (rm_rows)

    writeLines (c (as.character (nodes_sample), as.character (tables_sample)), fname)
}

test_that ("available_tags", {

    expect_error (available_tags ("building", 1), "unused argument")
    post_process <- !dir.exists ("mock_tags_fail")
    expect_error (
        tags <- with_mock_dir ("mock_tags_fail", {
            available_tags ("junk")
        }),
        "feature \\[junk\\] not listed as Key"
    )
    if (post_process) {
        post_process_tags ("mock_tags_fail")
    }

    post_process <- !dir.exists ("mock_tags")
    tags <- with_mock_dir ("mock_tags", {
        available_tags ("building")
    })
    if (post_process) {
        post_process_tags ("mock_tags", keys = "building")
    }
    expect_s3_class (tags, "data.frame")
    expect_equal (names (tags), c ("Key", "Value"))
    expect_true (all (tags$Key == "building"))
    expect_true (nrow (tags) > 1L)
})
