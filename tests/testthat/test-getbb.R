has_internet <- curl::has_internet ()
is_cran <-  identical (Sys.getenv("NOT_CRAN"), "false")
is_travis <-  identical (Sys.getenv("TRAVIS"), "true")

source ("../stub.R")

get_local <- FALSE
if (get_local) {
    # vcr code, for when it eventually appears on CRAN:
    #bb_test <- getbb ("Salzburg")
    #saveRDS (bb_test, 
    #         file = "./tests/testthat/bb_test.Rds")

    # Equivalent code using internal 'stub.R' function
    #trace ( curl::curl_fetch_memory, exit = function() { })
    base_url = "https://nominatim.openstreetmap.org"
    query <- list (q = 'Salzburg', viewbox = NULL, format = 'json',
                   featuretype = 'settlement', key = NULL, limit = 10)
    the_url <- httr::modify_url (base_url, query=query)
    GET_result_bb <- httr::GET (the_url)
    #untrace (curl::curl_fetch_memory)
    save (GET_result_bb, file="GET_result_bb.rda")
}

context ("bbox")

test_that ("bbox", {
  expect_error (bbox_to_string (), "bbox must be provided")
  #expect_error (bbox_to_string ("a"), "bbox must be numeric")
  expect_error (bbox_to_string (1:3), "bbox must contain four elements")
  expect_message (bbox_to_string (1:5), 
                              "only the first four elements of bbox used")
})

test_that ('getbb-place_name', {
               if (has_internet) {
                   if (is_cran)
                   {
                       load("GET_result_bb.rda")
                       stub (getbb, 'httr::GET', function (x) GET_result_bb)
                   } 
                   res <- getbb (place_name="Salzburg")
                   expect_is (res, "matrix")
                   expect_length (res, 4)
                   res <- getbb (place_name="Salzburg", format_out="string")
                   expect_is (res, "character")
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
