has_internet <- curl::has_internet ()

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("GITHUB_WORKFLOW"), "test-coverage"))


test_that ("bbox", {

  expect_error (bbox_to_string (), "bbox must be provided")
  #expect_error (bbox_to_string ("a"), "bbox must be numeric")
  expect_error (bbox_to_string (1:3), "bbox must contain four elements")
  expect_error (bbox_to_string (TRUE), "bbox must be numeric")
  expect_message (bbox_to_string (1:5),
                              "only the first four elements of bbox used")
})

test_that ("getbb-place_name", {

    res <- getbb (place_name = "Salzburg")
    expect_is (res, "matrix")
    expect_length (res, 4)
    # res_l <- getbb (place_name = list ("Salzburg"))
    # expect_identical (res, res_l)
    res <- getbb (place_name = "Salzburg", format_out = "string")
    expect_is (res, "character")

    expect_silent (res <- getbb (place_name = "Salzburg",
                                 featuretype = "state"))
    expect_output (res <- getbb (place_name = "Salzburg",
                                 silent = FALSE))
    expect_silent (res <- getbb (place_name = "Salzburg",
                                 format_out = "data.frame"))
    expect_is (res, "data.frame")
    expect_error (res <- getbb (place_name = "Salzburg",
                                format_out = "no format"),
                  "format_out not recognised")
})

test_that ("getbb-polygon", {

    res <- getbb (place_name = "Salzburg",
                 format_out = "polygon")
    expect_is (res, "list")
    expect_true (all (lapply (res, nrow) > 2))
    expect_true (all (vapply (res, function (i)
                             methods::is (i, "matrix"),
                             logical (1))))

    expect_silent (res_str <- bbox_to_string (res [[1]]))
    expect_is (res_str, "character")

    res <- getbb (place_name = "Salzburg",
                 format_out = "sf_polygon")
    expect_is (res, "sf")
    expect_is (res$geometry, "sfc_POLYGON")
    expect_true (length (res$geometry) > 1)
})

test_that ("bbox-to-string", {

    bb <- cbind (1:2, 3:4)
    expect_is (bbox_to_string (bb), "character")
    rownames (bb) <- c ("x", "y")
    colnames (bb) <- c ("min", "max")
    expect_is (bbox_to_string (bb), "character")
    rownames (bb) <- c ("coords.x1", "coords.x2")
    colnames (bb) <- c ("min", "max")
    expect_is (bbox_to_string (bb), "character")
    bb <- 1:4
    names (bb) <- c ("left", "bottom", "right", "top")
    expect_is (bbox_to_string (bb), "character")
})
