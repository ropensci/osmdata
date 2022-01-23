
context ("overpass query datetime param")

test_that ("datetime", {

    q0 <- opq (bbox = c(-0.118, 51.514, -0.115, 51.517))
    expect_error (opq (bbox = c(-0.118, 51.514, -0.115, 51.517),
                       datetime = "blah"),
                  "datetime must be in ISO8601 format")
    q1 <- opq (bbox = c(-0.118, 51.514, -0.115, 51.517),
               datetime = "2015-01-01T00:00:00Z")

    expect_true (!identical (q0, q1))
    expect_identical (names (q0), names (q1))
    expect_identical (q0 [!names (q0) == "prefix"],
                      q1 [!names (q1) == "prefix"])
    expect_true (grepl ("date\\:", q1$prefix))

    expect_error (opq (bbox = c(-0.118, 51.514, -0.115, 51.517),
                       datetime = "2015-01-01T00:00:00Z",
                       datetime2 = "blah"),
                  "datetime must be in ISO8601 format")

    q2 <- opq (bbox = c(-0.118, 51.514, -0.115, 51.517),
               datetime = "2015-01-01T00:00:00Z",
               datetime2 = "2015-01-02T00:00:00Z")
    expect_true (!identical (q0, q2))
    expect_identical (names (q0), names (q2))
    expect_identical (q0 [!names (q0) == "prefix"],
                      q2 [!names (q2) == "prefix"])
    expect_true (!grepl ("date\\:", q2$prefix))
    expect_true (!grepl ("diff\\:", q2$prefix))
})
