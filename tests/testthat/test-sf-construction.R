context ("sf-construction")

#Needs this function from `sf::sfg.R`:
getClassDim <- function(x, d, dim = "XYZ", type) {
    stopifnot(d > 1)
    type = toupper(type)
    if (d == 2)
        c("XY", type, "sfg")
    else if (d == 3) {
        stopifnot(dim %in% c("XYZ", "XYM"))
        c(dim, type, "sfg")
    } else if (d == 4)
        c("XYZM", type, "sfg")
    else stop(paste(d, "is an illegal number of columns for a", type))
}

make_one_point <- function (x) {
               x <- structure (x, class = getClassDim(x, length(x), type="POINT"))
               x <- list (x)
               attr (x, "n_empty") = sum(sapply(x, function(x) length(x) == 0))
               class(x) = c(paste0("sfc_", class(x[[1L]])[2L]), "sfc")
               attr(x, "precision") = 0.0
               bb <- structure(rep(NA_real_, 4), names = c("xmin", "ymin", "xmax", "ymax")) 
               bb [1:4] <- c (1, 2, 1, 2) # (xmin, ymin, xmax, ymax), where max==min
               attr(x, "bbox") = bb
               NA_crs_ = structure(list(epsg = NA_integer_, proj4string = NA_character_), class = "crs")
               attr(x, "crs") = NA_crs_
               x
}

test_that ("sfc-single-point", {
               x <- make_one_point (1:2)
               x2 = sf::st_sfc (sf::st_point(1:2))
               attr (x, "bbox") <- attr (x2, "bbox")
               expect_identical (x, x2)
})

test_that ("sf-single-point", {
               # From `sf::sf.R`:
               x <- make_one_point (1:2)
               # L#154-156 have to come first, but don't work here because
               # substitute defaults to this evaluation env, so that arg_nm =
               # deparse(x), rather than just "x"
               object = as.list(substitute(list(x)))[-1L] 
               arg_nm = sapply(x, function(i) deparse(i))
               sfc_name <- make.names(arg_nm[1])
               sfc_name <- "x"
               # Then back up to L#125
               x <- list (x)
               sf = sapply(x, function(i) inherits(i, "sfc"))
               sf_column <- 1 # which (sf)
               row_names <- seq_along (x [[1]])
               df <- data.frame (row.names=row_names)
               df [[sfc_name]] <- x [[1]]
               attr(df, "sf_column") = sfc_name
               f = factor(rep(NA_character_, length.out = ncol(df) - 1), 
                          levels = c("field", "lattice", "entity"))
               names(f) = names(df)[-sf_column]
               attr(df, "relation_to_geometry") = f
               class(df) = c("sf", class(df))
               # confirm that this is identical with `sf` output:
               x <- sf::st_sfc (sf::st_point(1:2))
               x <- sf::st_sf (x)
               expect_identical (df, x)
})
