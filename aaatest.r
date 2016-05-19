Sys.setenv ('PKG_CXXFLAGS'='-std=c++11')
Rcpp::sourceCpp('src/xml-parser.cpp')
Sys.unsetenv ('PKG_CXXFLAGS')

bbox <- '(-11,-51.51,-0.1,-51.5)'
key <- "['highway']"
query <- paste0 ('(node', key, bbox, ';way', key, bbox, ';rel', key, bbox, ';')
url_base <- 'http://overpass-api.de/api/interpreter?data='
query <- paste0 (url_base, query, ');(._;>;);out;')

dat <- httr::GET (query)
if (dat$status_code != 200)
    warning (httr::http_status (dat)$message)
# Encoding must be supplied to suppress warning
txt <- httr::content (dat, "text", encoding='UTF-8')
#txt <- XML::xmlParse (httr::content (dat, "text", encoding='UTF-8'))
dat <- test (txt)
dat <- lapply (dat, function (i) do.call (rbind, i))
dat
