.onAttach <- function(libname, pkgname) {
    msg <- paste0 ("Data (c) OpenStreetMap contributors,",
                   " ODbL 1.0. http://www.openstreetmap.org/copyright")
    packageStartupMessage (msg)
}
