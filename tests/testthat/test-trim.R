context ("trim-osm-data")

skip_on_os ("mac")
skip_on_os ("windows")

test_that ("trim_osm_data", {
    osm_multi <- test_path ("fixtures", "osm-multi.osm")
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x0 <- osmdata_sf (q0, osm_multi)
    bb <- cbind (c (2, 3), c (2, 3))
    require (sf)
    expect_error (
        trim_osmdata (1, bb_poly = bb),
        "unrecognised dat class: numeric"
    )
    expect_silent (x1 <- trim_osmdata (x0, bb_poly = bb, exclude = TRUE))
    expect_equal (nrow (x1$osm_points), 0)
    expect_equal (nrow (x1$osm_lines), 0)
    expect_equal (nrow (x1$osm_polygons), 0)
    expect_equal (nrow (x1$osm_multilines), 0)
    expect_equal (nrow (x1$osm_multipolygons), 0)

    expect_silent (x1 <- trim_osmdata (x0, bb_poly = bb, exclude = FALSE))
    expect_equal (nrow (x1$osm_points), 4)
    expect_equal (nrow (x1$osm_lines), 1)
    expect_equal (nrow (x1$osm_polygons), 1)
    expect_equal (nrow (x1$osm_multilines), 0)
    expect_equal (nrow (x1$osm_multipolygons), 1)

    expect_true (nrow (x1$osm_points) < nrow (x0$osm_points))
    expect_true (nrow (x1$osm_lines) < nrow (x0$osm_lines))
    expect_true (nrow (x1$osm_polygons) == nrow (x0$osm_polygons))
    expect_true (nrow (x1$osm_multilines) < nrow (x0$osm_multilines))
    expect_true (nrow (x1$osm_multipolygons) ==
        nrow (x0$osm_multipolygons))

    expect_silent (x0_sc <- osmdata_sc (q0, osm_multi))
    expect_silent (x1 <- trim_osmdata (x0_sc, bb_poly = bb))
    expect_equal (nrow (x1$object), 0)
    expect_equal (nrow (x1$object_link_edge), 0)
    expect_equal (nrow (x1$edge), 0)
    expect_equal (nrow (x1$vertex), 0)

    bb <- list (
        rbind (
            c (0, 0),
            c (0, 1),
            c (1, 1),
            c (1, 0),
            c (0, 0)
        ),
        rbind (
            c (2, 3),
            c (2, 4),
            c (3, 4),
            c (3, 3),
            c (2, 3)
        )
    )

    expect_message (
        x1 <- trim_osmdata (x0, bb_poly = bb),
        "bb_poly has more than one polygon"
    )
})

test_that ("bb_poly as sf/sc", {
    q0 <- opq (bbox = c (1, 1, 5, 5))
    x0 <- osmdata_sf (q0, test_path ("fixtures", "osm-multi.osm"))
    bb <- rbind (
        c (2, 2),
        c (2, 3),
        c (3, 3),
        c (3, 2),
        c (2, 2)
    )
    x1 <- trim_osmdata (x0, bb, exclude = FALSE)

    bb_sf <- sf::st_polygon (list (bb)) |>
        st_sfc () |>
        st_sf (crs = 4326)
    expect_silent (x2 <- trim_osmdata (x0,
        bb_poly = bb_sf,
        exclude = FALSE
    ))
    expect_identical (x1, x2)

    bb_sp <- as (bb_sf, "Spatial")
    expect_silent (x3 <- trim_osmdata (x0,
        bb_poly = bb_sp,
        exclude = FALSE
    ))
    expect_identical (x1, x3)
})
