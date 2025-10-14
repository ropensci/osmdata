df_cols <- c (
    "place_id", "licence", "osm_type", "osm_id", "lat", "lon",
    "class", "type", "place_rank", "importance", "addresstype", "name",
    "display_name"
)

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
    expect_equal (dimnames (res0), list (c ("x", "y"), c ("min", "max")))

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
        res3 <- with_mock_dir ("mock_bb_df", {
            getbb (place_name = "Salzburg", format_out = "data.frame")
        })
    )
    expect_is (res3, "data.frame")
    expect_true (nrow (res3) > 1L)
    expect_named (res3, c (df_cols, "boundingbox"))

    expect_silent (
        res4 <- with_mock_dir ("mock_bb_df_viewbox", {
            getbb (
                place_name = "Salzburg",
                format_out = "data.frame",
                viewbox = "9.5307487,46.3722987,17.1607728,49.0205249"
                # paste(getbb ("Österreich"), collapse = ",")
            )
        })
    )
    expect_is (res4, "data.frame")
    expect_true (nrow (res4) > 1L)
    expect_named (res4, c (df_cols, "boundingbox"))
    expect_true (all (grepl ("Österreich", res4$display_name)))
    expect_true (nrow (res3) > nrow (res4))

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


    ## Empty results

    expect_warning (
        res_empty_matrix <- with_mock_dir ("mock_bb_typo", {
            getbb ("Salzzburg")
        }),
        "`place_name` 'Salzzburg' can't be found"
    )
    expect_is (res_empty_matrix, "matrix")
    expect_length (res_empty_matrix, 4)
    expect_equal (
        dimnames (res_empty_matrix),
        list (c ("x", "y"), c ("min", "max"))
    )

    expect_warning (
        res_empty_df <- with_mock_dir ("mock_bb_typo", {
            getbb ("Salzzburg", format_out = "data.frame")
        }),
        "`place_name` 'Salzzburg' can't be found"
    )
    expect_is (res4, "data.frame")
    expect_true (nrow (res_empty_df) == 0L)
    expect_named (res_empty_df, c (df_cols, "boundingbox"))

    expect_warning (
        res_empty_string <- with_mock_dir ("mock_bb_typo", {
            getbb ("Salzzburg", format_out = "string")
        }),
        "`place_name` 'Salzzburg' can't be found"
    )
    expect_is (res_empty_string, "character")
    expect_length (res_empty_string, 0L)

    expect_warning (
        res_empty_polygon <- with_mock_dir ("mock_bb_typo_pol", {
            getbb ("Salzzburg", format_out = "polygon")
        }),
        "`place_name` 'Salzzburg' can't be found"
    )
    expect_is (res_empty_polygon, "list")
    expect_length (res_empty_polygon, 0L)

    expect_warning (
        res_empty_sfpolygon <- with_mock_dir ("mock_bb_typo_pol", {
            getbb ("Salzzburg", format_out = "sf_polygon")
        }),
        "`place_name` 'Salzzburg' can't be found"
    )
    expect_is (res_empty_sfpolygon, "sf")
    expect_length (res_empty_sfpolygon$geometry, 0L)
    expect_true (nrow (res_empty_sfpolygon) == 0L)
    expect_named (res_empty_sfpolygon, c (df_cols, "geometry"))

    expect_warning (
        res_empty_osmid <- with_mock_dir ("mock_bb_typo", {
            getbb ("Salzzburg", format_out = "osm_type_id")
        }),
        "`place_name` 'Salzzburg' can't be found"
    )
    expect_is (res_empty_osmid, "character")
    expect_length (res_empty_osmid, 0L)

})


test_that ("getbb-wikidata", {

    res0 <- with_mock_dir ("mock_bb_wikidata", {
        getbb (place_name = "Q234963")
    })
    expect_is (res0, "matrix")
    expect_length (res0, 4)
    expect_equal (dimnames (res0), list (c ("x", "y"), c ("min", "max")))

    res1 <- with_mock_dir ("mock_bb_wikidata", {
        getbb (place_name = "Q234963", format_out = "string")
    })
    expect_is (res1, "character")

    expect_message (
        res0 <- with_mock_dir ("mock_bb_wikidata", {
            getbb (place_name = "Q234963", silent = FALSE)
        })
    )
    expect_silent (
        res4 <- with_mock_dir ("mock_bb_wikidata", {
            getbb (place_name = "Q234963", format_out = "data.frame")
        })
    )
    expect_is (res4, "data.frame")
    expect_true (nrow (res4) == 1L)
    expect_named (res4, c (df_cols, "boundingbox"))

    expect_error (
        res5 <- with_mock_dir ("mock_bb_wikidata_nope", {
            getbb (place_name = "Q234963", format_out = "no format")
        }),
        class = "simpleError"
    )

    expect_silent (
        res6 <- with_mock_dir ("mock_bb_wikidata", {
            getbb (place_name = "Q234963", format_out = "osm_type_id")
        })
    )
    expect_is (res6, "character")
    expect_length (res6, 1L)


    ## Empty results

    expect_warning (
        res_empty_matrix <- with_mock_dir ("mock_bb_wikidata_NULL", {
            getbb ("Q00")
        }),
        "`place_name` 'Q00' can't be found"
    )
    expect_is (res_empty_matrix, "matrix")
    expect_length (res_empty_matrix, 4)
    expect_equal (
        dimnames (res_empty_matrix),
        list (c ("x", "y"), c ("min", "max"))
    )

    expect_warning (
        res_empty_df <- with_mock_dir ("mock_bb_wikidata_NULL", {
            getbb ("Q00", format_out = "data.frame")
        }),
        "`place_name` 'Q00' can't be found"
    )
    expect_is (res4, "data.frame")
    expect_true (nrow (res_empty_df) == 0L)
    expect_named (res_empty_df, c (df_cols, "boundingbox"))

    expect_warning (
        res_empty_string <- with_mock_dir ("mock_bb_wikidata_NULL", {
            getbb ("Q00", format_out = "string")
        }),
        "`place_name` 'Q00' can't be found"
    )
    expect_is (res_empty_string, "character")
    expect_length (res_empty_string, 0L)

    expect_warning (
        res_empty_polygon <- with_mock_dir ("mock_bb_wikidata_NULL", {
            getbb ("Q00", format_out = "polygon")
        }),
        "`place_name` 'Q00' can't be found"
    )
    expect_is (res_empty_polygon, "list")
    expect_length (res_empty_polygon, 0L)

    expect_warning (
        res_empty_sfpolygon <- with_mock_dir ("mock_bb_wikidata_NULL", {
            getbb ("Q00", format_out = "sf_polygon")
        }),
        "`place_name` 'Q00' can't be found"
    )
    expect_is (res_empty_sfpolygon, "sf")
    expect_length (res_empty_sfpolygon$geometry, 0L)
    expect_true (nrow (res_empty_sfpolygon) == 0L)
    expect_named (res_empty_sfpolygon, c (df_cols, "geometry"))

    expect_warning (
        res_empty_osmid <- with_mock_dir ("mock_bb_wikidata_NULL", {
            getbb ("Q00", format_out = "osm_type_id")
        }),
        "`place_name` 'Q00' can't be found"
    )
    expect_is (res_empty_osmid, "character")
    expect_length (res_empty_osmid, 0L)
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
    expect_true (all (grepl ("^relation/[0-9]+$", names (res_poly))))

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
    expect_named (res_sf, c (df_cols, "geometry"))


    # No polygonal boundary

    with_mock_dir ("mock_bb_poly_no", {
        expect_message (res_bb <- getbb (
            place_name = "Sorita de Llitera", format_out = "polygon"
        ), "No polygonal boundary")
        expect_message (res_bb_sf <- getbb (
            place_name = "Sorita de Llitera", format_out = "sf_polygon"
        ))
    })

    expect_is (res_bb, "matrix")
    expect_identical (dim (res_bb), c (2L, 2L))
    expect_identical (dimnames (res_bb), list (c ("x", "y"), c ("min", "max")))

    # sf_polygon
    expect_is (res_bb_sf, "sf")
    expect_is (res_bb_sf$geometry, "sfc")
    expect_true (ncol (res_bb_sf) > 1)
})

test_that ("bbox-to-string", {

    # Bounding box
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

    # data.frame
    area <- data.frame (osm_type = "relation", osm_id = "11747082")
    expect_is (bbox_to_string (area), "character")
    expect_length (bbox_to_string (area), 1)
    area <- data.frame (
        osm_type = c ("relation", "relation", "way"),
        osm_id = c ("11747082", "307833", "22422490")
    )
    expect_is (bbox_to_string (area), "character")
    expect_length (bbox_to_string (area), 1)

    # polygon
    with_mock_dir ("mock_bb_poly", {
        res_poly <- getbb (
            place_name = "Milano, Italia", format_out = "polygon"
        )
        res_sf <- getbb (
            place_name = "Milano, Italia", format_out = "sf_polygon"
        )
    })

    expect_message (
        bbox_to_string (res_poly),
        "more than one polygon; the first will be selected"
    )
    str <- list ()
    expect_silent (str$pol <- bbox_to_string (res_poly [[1]]))
    expect_silent (str$multipol <- bbox_to_string (res_poly [[2]]))
    expect_silent (str$sf <- bbox_to_string (res_sf))

    sapply (str, expect_is, "character")
    sapply (str, expect_length, 1)

})
