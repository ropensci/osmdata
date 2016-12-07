library (osmdata)
# NOTE: Currently requires devtools::load_all ("osmdata", export_all=TRUE)!

benchmark <- function ()
{
    q0 <- opq (bbox=c(-0.12,51.51,-0.11,51.52)) # Central London, U.K.
    q1 <- add_feature (q0, key='building')
    query <- paste0 (c (q1$features, q1$suffix), collapse="\n")

    base_url <- "http://overpass-api.de/api/interpreter"
    dat <- httr::POST (base_url, body=query)
    doc_xml <- xml2::read_xml (httr::content (dat, as="text", encoding="UTF-8"))
    xml2::write_xml (doc_xml, file="export.osm")

    objs <- c ("points", "lines", "multipolygons", "other_relations")
    mt_sf <- size_sf <- NULL
    for (i in seq (objs))
    {
        mb <- microbenchmark::microbenchmark (
           dat <- sf::st_read ("export.osm", layer=objs [i], quiet=TRUE) , times=10L)
        size_sf <- c (size_sf, object.size (dat))
        mt_sf <- c (mt_sf, median (mb$time))
        cat ("\r", i, " / ", length (objs))
    }
    mt_sf <- mt_sf / 1e6 # nano-seconds to milli-seconds
    cat ("\rSF: Median times (in ms) for (", paste (objs), "):\n")
    cat ("\t(", mt_sf, "); total = ", sum (mt_sf), "\n")

    # Code from overpass_query
    # TODO: modify overpass_query to pre-downloaded data can be passed
    res <- httr::POST (base_url, body=query)
    doc <- httr::content (res, as="text", encoding="UTF-8")

    f <- function ()
    {
        obj <- osmdata () # uses class def
        obj$bbox <- q1$bbox
        obj$overpass_call <- query
        obj$timestamp <- timestamp (quiet=TRUE, prefix="[ ", suffix=" ]")
        res <- rcpp_get_osmdata (doc)
        obj$osm_points <- res$points
        obj$osm_lines <- res$lines
        obj$osm_polygons <- res$polygons
        return (obj)
    }
    mb <- microbenchmark::microbenchmark ( dat <- f() , times=10L)
    mt <- median (mb$time / 1e6)
    cat ("osmdata: Median time = ", mt, " ms\n")
    size_od <- object.size (dat)

    cat ("\nosmdata took ", mt / sum (mt_sf), " times longer to extract ",
         size_od / sum (size_sf), " times as much data\n")
}
