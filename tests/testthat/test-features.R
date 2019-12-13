has_internet <- curl::has_internet ()

# test_all used to switch off tests on CRAN
test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))
             #identical (Sys.getenv ("APPVEYOR"), "True"))

source ("../stub.R")

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
    #trace ( curl::curl_fetch_memory, exit = function() { })
    url_ftrs <- "https://wiki.openstreetmap.org/wiki/Map_Features"
    cfm_output_af <- NULL
    trace(
          curl::curl_fetch_memory,
          exit = function() {
              cfm_output_af <<- returnValue()
          }
          )
    res <- httr::GET (url_ftrs)
    untrace (curl::curl_fetch_memory)
    save (cfm_output_af, file = "../cfm_output_af.rda")
}

context ("features.R")
test_that ("available_features", {
               expect_error (available_features (1), "unused argument")
               if (!has_internet) {
                   expect_message (available_features (),
                                   "No internet connection")
               } else
               {
                   if (!test_all)
                   {
                       load ("../cfm_output_af.rda")
                       stub (available_features, 'httr::GET', function (x)
                             cfm_output_af$content )
                   }
                   expect_is (available_features (), "character")
               }
          })

test_that ("available_tags", {
               expect_error (available_tags ("highway", 1), "unused argument")
               if (!has_internet) {
                   expect_message (available_tags (), "No internet connection")
               } else {
                   if (!test_all)
                   {
                       load ("../cfm_output_af.rda")
                       stub (available_tags, 'httr::GET', function (x)
                             cfm_output_af$content )
                   }
                   expect_that (length (available_tags ("junk")), equals (0))
                   expect_is (available_tags ("highway"), "character")
               }
          })
