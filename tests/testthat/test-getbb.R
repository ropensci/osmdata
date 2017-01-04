has_internet <- curl::has_internet ()
is_cran <-  identical (Sys.getenv("NOT_CRAN"), "false")
is_travis <-  identical (Sys.getenv("TRAVIS"), "true")

get_local <- FALSE
if (get_local) {
  bb_test <- getbb("Salzburg")
  saveRDS (bb_test, 
           file = "./tests/testthat/bb_test.Rds")
}
  
  if (has_internet) {
    f <- "tests/testthat/bb_test.Rds"
    expect_equal(getbb("Salzburg"), readRDS(f))
  }
