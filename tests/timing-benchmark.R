#library (osmdata)
# NOTE: Currently requires devtools::load_all ("osmdata", export_all = TRUE)!

benchmark <- function (times = 100)
{
    devtools::load_all (".", export_all = FALSE)
    q0 <- opq (bbox = c(-0.27, 51.47, -0.20, 51.50))
    q1 <- add_feature (q0, key = 'name', value = "Thames", exact = FALSE)
    # contains both multipolygons and multilinestrings
    doc <- osmdata_xml (q1, "export.osm")

    objs <- c ("points", "lines", "multilinestrings", "multipolygons",
               "other_relations")
    mt_sf <- size_sf <- NULL
    for (i in seq (objs))
    {
        mb <- microbenchmark::microbenchmark (
           dat <- sf::st_read ("export.osm", layer = objs [i], quiet = TRUE),
           times = times)
        size_sf <- c (size_sf, object.size (dat))
        mt_sf <- c (mt_sf, median (mb$time))
        cat ("\r", i, " / ", length (objs))
    }
    mt_sf <- mt_sf / 1e6 # nano-seconds to milli-seconds
    cat ("\rSF: Median times (in ms) for (", paste (objs), "):\n")
    cat ("\t(", mt_sf, "); total = ", sum (mt_sf), "\n")

    mb <- microbenchmark::microbenchmark ( x <- osmdata_sf (q1, doc),
                                          times = times)
    #mb <- microbenchmark::microbenchmark ( x <- osmdata_sf (q1, "export.osm"),
    #                                      times = 10L)
    mt <- median (mb$time / 1e6)
    cat ("osmdata: Median time = ", mt, " ms\n")
    size_od <- object.size (x)

    cat ("\nosmdata took ", mt / sum (mt_sf), " times longer to extract ",
         size_od / sum (size_sf), " times as much data\n")
}
