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
}
