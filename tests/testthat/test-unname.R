context ("unname-osmdata-sf")

skip_if (!test_all)

has_internet <- curl::has_internet ()
skip_if (!has_internet)

require (sf)

test_that ("unname", {

    qry <- opq (bbox = c (-0.116, 51.516, -0.115, 51.517))
    qry <- add_osm_feature (qry, key = "highway")

    res <- with_mock_dir ("mock_unname", {
        osmdata_sf (qry)
    })

    expect_true (all (nzchar (rownames (res$osm_points))))
    m_l <- as.matrix (res$osm_lines$geometry [[1]])
    expect_false (is.null (rownames (m_l)))
    expect_true (length (nchar (rownames (m_l))) > 0L)
    m_p <- as.matrix (res$osm_polygons$geometry [[1]])
    expect_true (!is.null (rownames (m_p)))
    expect_true (length (nchar (rownames (m_p))) > 0L)

    res_u <- unname_osmdata_sf (res)
    expect_true (all (nzchar (rownames (res_u$osm_points))))
    m_l <- as.matrix (res_u$osm_lines$geometry [[1]])
    expect_true (is.null (rownames (m_l)))
    expect_false (length (nchar (rownames (m_l))) > 0L)
    m_p <- as.matrix (res_u$osm_polygons$geometry [[1]])
    expect_true (is.null (rownames (m_p)))
    expect_false (length (nchar (rownames (m_p))) > 0L)
})
