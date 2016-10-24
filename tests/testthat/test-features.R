has_internet <- curl::has_internet ()
is_cran <-  identical (Sys.getenv("NOT_CRAN"), "false")
is_travis <-  identical (Sys.getenv("TRAVIS"), "true")

url_ftrs <- "http://wiki.openstreetmap.org/wiki/Map_Features"

# Mock tests as discussed by Noam Ross here:
# https://discuss.ropensci.org/t/best-practices-for-testing-api-packages/460
# and demonstrated in detail by Gabor Csardi here:
# https://github.com/MangoTheCat/blog-with-mock/blob/master/Blogpost1.md
# Note that file can be downloaded in configure file, but this produces a very
# large file in the installed package (>2MB), whereas this read_html version
# yields a file <1/10th the size.
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
  expect_error (available_features (1), "unused argument")
  if (!has_internet) {
    expect_message (available_features (), "No internet connection")
  } else 
  {
    if (is_cran)
    {
      load("cfm_output_available_features.rda")
      stub (available_features, 'httr::GET', function (x) 
            cfm_output_available_features$content )
    }
    expect_is (available_features (), "character")
  }
})

test_that ("available_tags", {
  expect_error (available_tags (), "Please specify feature")
  expect_error (available_tags ("highway", 1), "unused argument")
  if (!has_internet) {
    expect_message (available_tags (), "No internet connection")
  } else {
    if (is_cran)
    {
      load("cfm_output_available_features.rda")
      stub (available_tags, 'httr::GET', function (x) 
            cfm_output_available_features$content )
    }
    expect_that (length (available_tags ("junk")), equals (0))
    expect_is (available_tags ("highway"), "character")
  }
})
