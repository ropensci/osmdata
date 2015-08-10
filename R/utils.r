id <- lon <- lat <- NULL # for CRAN checks until I switch to underscore versions of dplyr stuff

overpass_base_url <- "http://overpass-api.de/api/interpreter"

# "fastmatch" version of %in%
"%fmin%" <- function(x, table) { fmatch(x, table, nomatch = 0) > 0 }

# test if a given xpath exists in doc
has_xpath <- function(doc, xpath) {

  tryCatch(length(xml_find_all(doc, xpath)) > 0,
           error=function(err) { return(FALSE) },
           warning=function(wrn) { message(wrn$message) ; return(TRUE); })

}
