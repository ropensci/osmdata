test_that ("bbox", {

    expect_error (bbox_to_string (), "bbox must be provided")
    # expect_error (bbox_to_string ("a"), "bbox must be numeric")
    expect_error (bbox_to_string (1:3), "bbox must contain four elements")
    expect_error (bbox_to_string (TRUE), "bbox must be numeric")
    expect_message (
        bbox_to_string (1:5),
        "only the first four elements of bbox used"
    )
    expect_error (
        bbox_to_string (data.frame (a = "type", b = "id")),
        "bbox must be a data.frame with osm_type and osm_id columns"
    )
})

test_that ("getbb-place_name", {

    res0 <- with_mock_dir ("mock_bb", {
        getbb (place_name = "Salzburg")
    })
    expect_is (res0, "matrix")
    expect_length (res0, 4)

    res1 <- with_mock_dir ("mock_bb_str", {
        getbb (place_name = "Salzburg", format_out = "string")
    })
    expect_is (res1, "character")

    expect_silent (
        res2 <- with_mock_dir ("mock_bb_state", {
            getbb (place_name = "Salzburg", featuretype = "state")
        })
    )
    range0 <- apply (res0, 1, function (i) diff (range (i)))
    range2 <- apply (res2, 1, function (i) diff (range (i)))
    expect_true (all (range2 >= range0))

    expect_message (
        res0 <- with_mock_dir ("mock_bb", {
            getbb (place_name = "Salzburg", silent = FALSE)
        })
    )
    expect_silent (
        res4 <- with_mock_dir ("mock_bb_df", {
            getbb (place_name = "Salzburg", format_out = "data.frame")
        })
    )
    expect_is (res4, "data.frame")
    expect_true (nrow (res4) > 1L)

    expect_error (
        res5 <- with_mock_dir ("mock_bb_nope", {
            getbb (place_name = "Salzburg", format_out = "no format")
        }),
        class = "simpleError"
    )

    expect_silent (
        res6 <- with_mock_dir ("mock_bb_df", {
            getbb (place_name = "Salzburg", format_out = "osm_type_id")
        })
    )
    expect_is (res6, "character")
    expect_length (res6, 1L)

    expect_error (
        with_mock_dir ("mock_bb_typo", {
            getbb ("Salzzburg")
        }),
        "`place_name` 'Salzzburg' can't be found"
    )
})

# Note that the polygon calls produce large mock files which are reduced with
# post-processing routines. See `test-features.R` for explanations.
post_process_polygons <- function (dir_name, min_polys = 2) {

    fname <- list.files (
        dir_name,
        full.names = TRUE,
        recursive = TRUE
    ) [1]
    j <- jsonlite::fromJSON (fname)
    sizes <- vapply (
        j$geotext,
        object.size,
        numeric (1L),
        USE.NAMES = FALSE
    )
    # include smallest objects, but ensure at least 2 polygons:
    ord <- order (sizes)
    n <- 5
    while (length (which (j$osm_type [ord [seq (n)]] != "node")) < min_polys) {
        n <- n + 1
    }
    j <- j [ord [seq (n)], ]
    jsonlite::write_json (j, path = fname, pretty = TRUE)
}

test_that ("getbb-polygon", {

    post_process <- !dir.exists ("mock_bb_poly")
    with_mock_dir ("mock_bb_poly", {
        res_poly <- getbb (
            place_name = "Milano, Italia", format_out = "polygon"
        )
        res_sf <- getbb (
            place_name = "Milano, Italia", format_out = "sf_polygon"
        )
    })
    if (post_process) {
        post_process_polygons ("mock_bb_poly", min_polys = 2L)
    }

    expect_is (res_poly, "list")
    # test polygon
    expect_true (all (sapply (res_poly [[1]], nrow) > 2))
    expect_true (all (sapply (res_poly [[1]], is.matrix)))
    # test multipolygon
    expect_true (all (sapply (res_poly [[2]], sapply, nrow) > 2))
    expect_true (all (sapply (res_poly [[2]], sapply, is.matrix)))

    expect_silent (res_str <- sapply (res_poly, bbox_to_string))
    expect_is (res_str, "character")

    # sf_polygon
    expect_is (res_sf, "sf")
    expect_is (res_sf$geometry, "sfc")
    expect_true (length (res_sf$geometry) > 1)
    expect_true (ncol (res_sf) > 1)
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

    area <- data.frame (osm_type = "relation", osm_id = "11747082")
    expect_is (bbox_to_string (area), "character")
    expect_length (bbox_to_string (area), 1)
    area <- data.frame (
        osm_type = c ("relation", "relation", "way"),
        osm_id = c ("11747082", "307833", "22422490")
    )
    expect_is (bbox_to_string (area), "character")
    expect_length (bbox_to_string (area), 1)
})
