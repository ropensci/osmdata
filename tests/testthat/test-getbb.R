has_internet <- curl::has_internet ()
is_cran <-  identical (Sys.getenv("NOT_CRAN"), "false")
is_travis <-  identical (Sys.getenv("TRAVIS"), "true")

get_local <- FALSE
if (get_local) {
    # vcr code, for when it eventually appears on CRAN:
    #bb_test <- getbb ("Salzburg")
    #saveRDS (bb_test, 
    #         file = "./tests/testthat/bb_test.Rds")

    # Equivalent code using internal 'stub.R' function
    cfm_output_bb <- NULL
    trace(
          curl::curl_fetch_memory,
          exit = function() { cfm_output_bb <<- returnValue() }
          )
    res <- httr::POST (base_url, query=query)
    untrace (curl::curl_fetch_memory)
    save (cfm_output_bb, 
          file="./tests/testthat/cfm_output_bb.rda")
}

context ("bbox")

test_that ('getbb-place_name', {
               if (has_internet) {
                   if (is_cran)
                   {
                       load("cfm_output_bb.rda")
                       stub (getbb, 'httr::POST', 
                             function (x, ...) cfm_output_bb$content )
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
