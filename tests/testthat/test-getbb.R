has_internet <- curl::has_internet ()

# test_all used to switch off tests on CRAN
test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))
             #identical (Sys.getenv ("APPVEYOR"), "True"))

source ("../stub.R")

get_local <- FALSE
if (get_local) {
    # vcr code, for when it eventually appears on CRAN:
    #bb_test <- getbb ("Salzburg")
    #saveRDS (bb_test,
    #         file = "./tests/testthat/bb_test.Rds")

    # Equivalent code using internal 'stub.R' function
    stub1 <- function (query)
    {
        base_url <- "https://nominatim.openstreetmap.org"
        the_url <- httr::modify_url (base_url, query = query)
        cfm_output <- NULL
        trace(
              curl::curl_fetch_memory,
              exit = function() {
                  cfm_output <<- returnValue()
              })
        res <- httr::GET (the_url)
        class (cfm_output) <- 'response'
        untrace (curl::curl_fetch_memory)
        return (cfm_output)
    }

    list (q = 'Salzburg', viewbox = NULL, format = 'json',
          featuretype = 'settlement', key = NULL, limit = 10) %>%
        stub1 () -> cfm_output_bb
    save (cfm_output_bb, file = '../cfm_output_bb1.rda')
    list (q = 'Salzburg', viewbox = NULL, format = 'json',
          polygon_text = 1,
          featuretype = 'settlement', key = NULL, limit = 10) %>%
        stub1 () -> cfm_output_bb
    save (cfm_output_bb, file = '../cfm_output_bb2.rda')
}

context ("bbox")

test_that ("bbox", {
  expect_error (bbox_to_string (), "bbox must be provided")
  #expect_error (bbox_to_string ("a"), "bbox must be numeric")
  expect_error (bbox_to_string (1:3), "bbox must contain four elements")
  expect_error (bbox_to_string (TRUE), "bbox must be numeric")
  expect_message (bbox_to_string (1:5),
                              "only the first four elements of bbox used")
})

test_that ('getbb-place_name', {
               if (has_internet) {
                   if (!test_all)
                   {
                       load("../cfm_output_bb1.rda")
                       stub (getbb, 'httr::GET', function (x) cfm_output_bb )
                   }
                   res <- getbb (place_name = "Salzburg")
                   expect_is (res, "matrix")
                   expect_length (res, 4)
                   res_l <- getbb (place_name = list ("Salzburg"))
                   expect_identical (res, res_l)
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
               }
          })

test_that ('getbb-polygon', {
               if (has_internet) {
                   if (!test_all)
                   {
                       load("../cfm_output_bb2.rda")
                       stub (getbb, 'httr::GET', function (x) cfm_output_bb )
                   }
                   res <- getbb (place_name = "Salzburg", format_out = "polygon")
                   expect_is (res, "list")
                   expect_true (all (lapply (res, nrow) > 2))
                   expect_true (all (vapply (res, function (i)
                                             methods::is (i, "matrix"),
                                             logical (1))))

                   expect_silent (res_str <- bbox_to_string (res [[1]]))
                   expect_is (res_str, "character")

                   res <- getbb (place_name = "Salzburg", format_out = "sf_polygon")
                   expect_is (res, "sf")
                   expect_is (res$geometry, "sfc_POLYGON")
                   expect_true (length (res$geometry) > 1)
               }
          })

test_that ('bbox-to-string', {
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
