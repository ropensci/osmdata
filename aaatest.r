Sys.setenv ('PKG_CXXFLAGS'='-std=c++11')
Rcpp::sourceCpp('src/xml-parser.cpp')
Sys.unsetenv ('PKG_CXXFLAGS')

bbox <- '(51.5,-0.11,51.51,-0.1)'
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

# convert to SpatialLines object. Note that coercing to sp::Line removes the
# name, so this has to be constructed as an explicit loop.
# TODO: re-write without loop
nd <- names (dat)
indx <- which (nchar (nd) == 0)
nd2 <- rep (1, length (indx))
while (any (duplicated (nd2)))
    nd2 <- paste0 (round (runif (length (indx)) * 1e6))
nd [indx] <- nd2
for (i in seq (dat)) 
{
    di <- data.frame (do.call (rbind,  dat [[i]]))
    names (di) <- c ('x', 'y')
    dat [[i]] <- sp::Lines (sp::Line (di), ID=nd [i])
}
dat <- sp::SpatialLines (dat)

wd <- getwd ()
setwd ("..")
devtools::load_all ('osmplotr', export_all=FALSE)
setwd (wd)
bbox <- get_bbox (c(-0.11,51.5,-0.10,51.51))
dat2 <- extract_osm_objects (key='highway', bbox=bbox, verbose=TRUE)
