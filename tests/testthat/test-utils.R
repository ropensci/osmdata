has_internet <- curl::has_internet ()
is_cran <-  (identical(Sys.getenv("NOT_CRAN"), "false"))
is_travis <-  (identical(Sys.getenv("TRAVIS"), "true"))

context ("test-utils.R")
test_that ("bbox", {
  expect_error (bbox_to_string (), "bbox must be provided")
  #expect_error (bbox_to_string ("a"), "bbox must be numeric")
  expect_error (bbox_to_string (1:3), "bbox must contain four elements")
  expect_message (bbox_to_string (1:5), 
                              "only the first four elements of bbox used")
})

