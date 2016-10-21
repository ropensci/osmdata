has_internet <- curl::has_internet ()
is_cran <-  (identical(Sys.getenv("NOT_CRAN"), "false"))
is_travis <-  (identical(Sys.getenv("TRAVIS"), "true"))

url_ftrs <- "http://wiki.openstreetmap.org/wiki/Map_Features"

# Mock tests as discussed by Noam Ross here:
# https://discuss.ropensci.org/t/best-practices-for-testing-api-packages/460
# and demonstrated in detail by Gabor Csardi here:
# https://github.com/MangoTheCat/blog-with-mock/blob/master/Blogpost1.md
get_local <- FALSE
if (get_local)
{
  cfm_output_available_features <- NULL
  trace(
        curl::curl_fetch_memory,
        exit = function() { cfm_output_available_features <<- returnValue() }
        )
  pg <- xml2::read_html (httr::GET (url_ftrs))
  #names (cfm_output_available_features)
  untrace (curl::curl_fetch_memory)
  save (cfm_output_available_features, 
        file="./tests/testthat/cfm_output_available_features.rda")
}

context ("features.R")
test_that ("available_features", {
             if (!has_internet) {
               expect_message (available_features (), "No internet connection")
             } else 
             {
               expect_error (available_features (1), "unused argument")
               if (is_cran)
               {
                 with_mock (
                            `curl::curl_fetch_memory` = function(...) {
                              load("cfm_output_available_features.rda")
                              cfm_output_available_features
                            },
                            available_features <- function (...)
                            {
                              af <- cfm_output_available_features$content
                              res <- xml2::read_html (af)
                              keys <- xml2::xml_attr (rvest::html_nodes (res,
                                            "a[href^='/wiki/Key']"), "title")
                              unique (sort (gsub ("^Key:", "", keys)))
                            })
               }
               expect_is (available_features (), "character")
             }
      })

test_that ("available_tags", {
  expect_error (available_tags (), "Please specify feature")
  if (!has_internet) {
    expect_message (available_tags (), "No internet connection")
  } else {
    expect_that (length (available_tags ("junk")), equals (0))
    expect_is (available_tags ("highway"), "character")
    expect_error (available_tags ("highway", 1), "unused argument")
  }
})
