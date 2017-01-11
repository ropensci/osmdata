Construction of `sf` objects
============================

This document demonstrates construction of the three types of `sf` objects returned by the GDAL OSM driver: `POINTS`, `LINESTRING`s, AND `MULTIPOLYGON`s, read with `sf` like this:

``` r
pts <- sf::st_read ("../export.osm",layer="points")
lns <- sf::st_read ("../export.osm",layer="lines")
ply <- sf::st_read ("../export.osm",layer="multipolygons")
```

This document directly reflects the code of `tests/testthat/test-sf-construction.R`, and exists just to add a few explanatory comments on the importance of those tests. The code is translated into `Rcpp` code to enable `osmdata` to directly return `sf` objects, and teh tests ensure that the `sf` objects returned by `osmdata` are consistent with those returned by `sf`.

The following code currently needs the dev version of `sf`:

``` r
devtools::load_all ("/data/Dropbox/mark/code/forks/sfr", export_all=FALSE)
```

Contents
--------

[1. Function definitions](#1%20fn%20defs)

[2. `sf::POINT`](#2%20point)

[2.1 `sf::POINT` with fields](#2.1%20point%20fields)

[2.2 Multiple `sf::POINT`s](#2.2%20multiple%20points)

[3. `sf::LINESTRING`](#3%20lines)

[3.1 Multiple `sf::LINESTRING`s](#3.1%20multiple%20lines)

[3.2 Multiple `sf::LINESTRING`s with fields](#3.2%20lines%20with%20fields)

[4 `sf::MULTIPOLYGON`](#4%20polygons)

[4.1 Multiple `sf::MULTIPOLYGON`s](#4.1%20multiple%20polygons)

[4.2 `sf::MULTIPOLYGON`s with features](#4.2%20polygons%20with%20features)

[5 A note on bounding boxes](#5%20bounding%20boxes)

------------------------------------------------------------------------

<a name="1 fn defs"></a>1---Function definitions
------------------------------------------------

Two generic function are required to make Simple Features Collections (`sfc`) and Simple Features Objects (`sf`), largely taken from the repsective functions [`sfc.R`](https://github.com/edzer/sfr/blob/master/R/sfc.R) and [`sf.R`](https://github.com/edzer/sfr/blob/master/R/sf.R). Note that these are simplified versions of the `sf` code because simple features collections for OSM data are only ever of single objects, and because only `sfg` .objects of class `XY` (rather than `XYZ` or `XYZM` are needed).

``` r
make_sfc <- function (x, type) {
    if (!is.list (x)) x <- list (x)
    type <- toupper (type)
    stopifnot (type %in% c ("POINT", "LINESTRING", "MULTIPOLYGON"))
    xy <- do.call (rbind, x)
    xvals <- xy [,1]
    yvals <- xy [,2]
    bb <- structure(rep(NA_real_, 4), names = c("xmin", "ymin", "xmax", "ymax"))
    bb [1:4] <- c (min (xvals), min (yvals), max (xvals), max (yvals))
    if (type == "MULTIPOLYGON") x <- lapply (x, function (i) list (list (i)))
    x <- lapply (x, function (i) structure (i, class = c ("XY", type, "sfg")))
    attr (x, "n_empty") = sum(sapply(x, function(x) length(x) == 0))
    class(x) = c(paste0("sfc_", class(x[[1L]])[2L]), "sfc")
    attr(x, "precision") = 0.0
    attr(x, "bbox") = bb
    NA_crs_ = structure(list(epsg = NA_integer_, proj4string = NA_character_), class = "crs")
    attr(x, "crs") = NA_crs_
    x
}
```

``` r
make_sf <- function (...)
{
    x <- list (...)
    sf = sapply(x, function(i) inherits(i, "sfc"))
    sf_column <- which (sf)
    row.names <- seq_along (x [[sf_column]])
    df <- if (length(x) == 1) # ONLY sfc
                data.frame(row.names = row.names)
            else # create a data.frame from list:
                    data.frame(x[-sf_column], row.names = row.names, 
                           stringsAsFactors = TRUE)

    object = as.list(substitute(list(...)))[-1L] 
    arg_nm = sapply(object, function(x) deparse(x))
    sfc_name <- make.names(arg_nm[sf_column])
    df [[sfc_name]] <- x [[sf_column]]
    attr(df, "sf_column") = sfc_name
    f = factor(rep(NA_character_, length.out = ncol(df) - 1), 
               levels = c ("constant", "aggregate", "identity"))
    # The right way to do it - not yet in "sf"!
    names(f) = names(df)[-ncol (df)]
    # The current, wrong way as done in sf:
    #names(f) = names(df)[-sf_column]
    attr(df, "relation_to_geometry") = f
    class(df) = c("sf", class(df))
    return (df)
}
```

Note in `make_sfc` that non-NA `crs` is more complex:

``` r
pts <- sf::st_read ("../export.osm",layer="points")
```

    ## Reading layer `points' from data source `/data/Dropbox/mark/code/repos/osmdata/export.osm' using driver `OSM'
    ## Simple feature collection with 137 features and 10 fields
    ## geometry type:  POINT
    ## dimension:      XY
    ## bbox:           xmin: -0.1205772 ymin: 51.51014 xmax: -0.1093308 ymax: 51.51979
    ## epsg (SRID):    4326
    ## proj4string:    +proj=longlat +datum=WGS84 +no_defs

``` r
crs0 <- attr (pts [1,]$geometry, "crs")
crs <- list ("epsg"=4326L, "proj4string"="+proj=longlat +datum=WGS84 +no_defs")
class (crs) <- "crs"
identical (crs0, crs)
```

    ## [1] TRUE

------------------------------------------------------------------------

<a name="2 point"></a>2---sf::POINT
-----------------------------------

First confirm that these functions construct `sfc` point objects correctly.

``` r
x <- make_sfc (1:2, type="POINT") # POINT
x2 = sf::st_sfc (sf::st_point(1:2))
identical (x, x2)
```

    ## [1] TRUE

Then construct equivalent full `sf` objects. Note that the `sfc` objects need to be constructed with identical names (`x`).

``` r
x <- sf::st_sfc (sf::st_point(1:2))
identical (x, make_sfc (1:2, "POINT"))
```

    ## [1] TRUE

``` r
x0 <- make_sf (x)
x1 <- sf::st_sf (x)
identical (x0, x1)
```

    ## [1] TRUE

The following section then adds fields to these simple objects.

### 2.1<a name="2.1 point fields"></a>---sf::POINT with fields

The following only works with my local `sf`, and fails for Edzer's current version.

``` r
x <- sf::st_sfc (sf::st_point(1:2))
x0 <- make_sf (a=3, b="blah", x)
x1 <- sf::st_sf (x, a=3, b="blah")
identical (x0, x1)
```

    ## [1] TRUE

The following:

``` r
attr (x1, "relation_to_geometry")
```

    ##    a    b 
    ## <NA> <NA> 
    ## Levels: constant aggregate identity

differ in Edzer's version, and give `b x` instead of `a b`.

### <a name="2.2 multiple points"></a>2.2---Multiple points

``` r
x <- make_sfc (list (1:2, 3:4), type="POINT")
y <- sf::st_sfc (sf::st_point (1:2), sf::st_point (3:4))
identical (x, y)
```

    ## [1] TRUE

``` r
y <- sf::st_sf (x, a=7:8, b=c("blah", "junk")) # has to be made from "x"
x <- make_sf (x, a=7:8, b=c("blah", "junk"))
identical (x, y)
```

    ## [1] TRUE

Finally, note that fields can be defined by a single `data.frame`

``` r
x <- make_sfc (list (1:2, 3:4, 5:6), type="POINT")
# x <- sf::st_sfc (sf::st_point (1:2), sf::st_point (3:4), sf::st_point (5:6))
dat <- data.frame (a=11:13, txt=c("junk", "blah", "stuff"))
y <- sf::st_sf (x, dat)
x <- make_sf (x, dat)
identical (x, y)
```

    ## [1] TRUE

``` r
x
```

    ## Simple feature collection with 3 features and 2 fields
    ## geometry type:  POINT
    ## dimension:      XY
    ## bbox:           xmin: 1 ymin: 2 xmax: 5 ymax: 6
    ## epsg (SRID):    NA
    ## proj4string:    NA
    ##    a   txt          x
    ## 1 11  junk POINT(1 2)
    ## 2 12  blah POINT(3 4)
    ## 3 13 stuff POINT(5 6)

------------------------------------------------------------------------

<a name="3 lines"></a>3---sf::LINESTRING
----------------------------------------

OSM lines are collections of `sf::LINESTRING` objects. The rest is largely identical to the preceding code for points. First check that the `sfc` objects are identical:

``` r
x <- make_sfc (cbind (1:4,5:8), "LINESTRING")
x2 <- sf::st_sfc (sf::st_linestring (cbind (1:4, 5:8)))
identical (x, x2)
```

    ## [1] TRUE

Then make the `sf` objects from these `sfc` objects, first without fields:

``` r
x1 <- make_sf (x)
x <- sf::st_sfc (sf::st_linestring (cbind (1:4, 5:8)))
x2 <- sf::st_sf (x)
identical (x1, x2)
```

    ## [1] TRUE

Then with fields:

``` r
x <- make_sfc (cbind (1:4,5:8), "LINESTRING")
x1 <- make_sf (x, a=3, b="blah")
x <- sf::st_sfc (sf::st_linestring (cbind (1:4, 5:8)))
x2 <- sf::st_sf (x, a=3, b="blah")
identical (x1, x2)
```

    ## [1] TRUE

Once again, the following values differ in Edzer's current `sf`:

``` r
attr (x2, "relation_to_geometry")
```

    ##    a    b 
    ## <NA> <NA> 
    ## Levels: constant aggregate identity

where they are `b x` instead of `a b`.

### <a name="3.1 multiple lines"></a>3.1---Multiple lines

`sfc` objects of type `LINESTRING` are just matrices: with multiple objects each assigned their own `sfg` geometry in `make_sfc` above.

``` r
x1 <- cbind (1:4, 5:8)
x2 <- cbind (11:13, 25:27)
x <- make_sfc (list (x1, x2), type="LINESTRING")
y <- sf::st_sfc (sf::st_linestring (x1), sf::st_linestring (x2))
identical (x, y)
```

    ## [1] TRUE

Then `sf` objects from multiple lines

``` r
x2 <- make_sf (x)
y2 <- sf::st_sf (x) # has to be "x" to match the sfc names
identical (x2, y2)
```

    ## [1] TRUE

### <a name="3.2 lines with fields"></a>3.2---Multiple lines with fields

And `sf` objects with fields

``` r
x1 <- cbind (1:4, 5:8)
x2 <- cbind (11:13, 25:27)
x <- sf::st_sfc (sf::st_linestring (x1), sf::st_linestring (x2))
y <- sf::st_sf (x, a=1:2, b="blah")
x <- make_sfc (list (x1, x2), type="LINESTRING")
x <- make_sf (x, a=1:2, b="blah")
identical (x, y)
```

    ## [1] TRUE

And again defining the fields in a `data.frame`:

``` r
x1 <- cbind (1:4, 5:8)
x2 <- cbind (11:13, 25:27)
x3 <- cbind (9:12, 39:42)
x <- sf::st_sfc (sf::st_linestring (x1), sf::st_linestring (x2),
                 sf::st_linestring (x3))
dat <- data.frame (a=1:3, b=c("blah", "junk", "stuff"), c=c (TRUE, FALSE, "XXX"))
y <- sf::st_sf (x, dat)
x <- make_sfc (list (x1, x2, x3), type="LINESTRING")
x <- make_sf (x, dat)
identical (x, y)
```

    ## [1] TRUE

``` r
x
```

    ## Simple feature collection with 3 features and 3 fields
    ## geometry type:  LINESTRING
    ## dimension:      XY
    ## bbox:           xmin: 1 ymin: 5 xmax: 13 ymax: 42
    ## epsg (SRID):    NA
    ## proj4string:    NA
    ##   a     b     c                              x
    ## 1 1  blah  TRUE LINESTRING(1 5, 2 6, 3 7, 4 8)
    ## 2 2  junk FALSE LINESTRING(11 25, 12 26, 13...
    ## 3 3 stuff   XXX LINESTRING(9 39, 10 40, 11 ...

------------------------------------------------------------------------

<a name="4 polygons"></a>4---sf::MULTIPOLYGONS
----------------------------------------------

OSM polygons are collections of `sf::MULTIPOLYGON` objects. First the construction of `st_multipolygon` geometries the `sf` way:

``` r
p1 <- matrix(c(0,0,10,0,10,10,0,10,0,0),ncol=2, byrow=TRUE)
pts <- list (list (p1))
mp <- sf::st_multipolygon (pts)
```

And the translation, which uses the function `MtrxSetSet()` from [`sfg.R`](https://github.com/edzer/sfr/blob/master/R/sfg.R), which does this:

``` r
mp1 <- structure (pts, class=c ("XY", "MULTIPOLYGON", "sfg"))
identical (mp, mp1)
```

    ## [1] TRUE

The conversion to `sfc`:

``` r
xsf <- sf::st_sfc (mp) # needs 2 steps to get MULTIPOLYGON name correct
x <- make_sfc (p1, type="MULTIPOLYGON")
identical (x, xsf)
```

    ## [1] TRUE

Then final conversion to `sf` (which requires passing `x` to `st_sf`):

``` r
x <- sf::st_sfc (mp) 
xsf <- sf::st_sf (x)
x <- make_sfc (p1, type="MULTIPOLYGON")
x <- make_sf (x)
identical (x, xsf)
```

    ## [1] TRUE

### <a name="4.1 multiple polygons"></a>4.1---Multiple Multipolygons

`sfc` construction:

``` r
x1 <- cbind (c (1:4, 1), c (5:8, 5))
x2 <- cbind (c (11:13, 11), c (25:27, 25))
x <- make_sfc (list (x1, x2), type="MULTIPOLYGON")
y <- sf::st_sfc (sf::st_multipolygon (list (list (x1))), 
                 sf::st_multipolygon (list (list (x2))))
identical (x, y)
```

    ## [1] TRUE

Then `sf`:

``` r
x1 <- cbind (c (1:4, 1), c (5:8, 5))
x2 <- cbind (c (11:13, 11), c (25:27, 25))
x <- make_sfc (list (x1, x2), type="MULTIPOLYGON")
y <- sf::st_sf (x)
x <- make_sf (x)
identical (x, y)
```

    ## [1] TRUE

### <a name="4.2 polygons with features"></a>4.2---Multipolygons with features

First just a single multipolygon with features.

``` r
x <- sf::st_sfc (mp) 
y <- sf::st_sf (x, a=3, b="blah")
x <- make_sfc (p1, type="MULTIPOLYGON")
x <- make_sf (a=3, b="blah", x)
identical (x, y)
```

    ## [1] TRUE

Then multiple multipolygons

``` r
x1 <- cbind (c (1:4, 1), c (5:8, 5))
x2 <- cbind (c (11:13, 11), c (25:27, 25))
x <- make_sfc (list (x1, x2), type="MULTIPOLYGON")
dat <- data.frame (a=1:2, b=c("blah", "junk"))
y <- sf::st_sf (x, dat)
x <- make_sf (x, dat)
identical (x, y)
```

    ## [1] TRUE

------------------------------------------------------------------------

<a name="5 bounding boxes"></a>5---A note on bounding boxes
-----------------------------------------------------------

Note the following behaviour of `sf`:

``` r
x1 <- cbind (1:4, 5:8)
x2 <- cbind (11:13, 25:27)
x <- sf::st_sfc (sf::st_linestring (x1), sf::st_linestring (x2))
x <- sf::st_sf (x) 
x
```

    ## Simple feature collection with 2 features and 0 fields
    ## geometry type:  LINESTRING
    ## dimension:      XY
    ## bbox:           xmin: 1 ymin: 5 xmax: 13 ymax: 27
    ## epsg (SRID):    NA
    ## proj4string:    NA
    ##                                x
    ## 1 LINESTRING(1 5, 2 6, 3 7, 4 8)
    ## 2 LINESTRING(11 25, 12 26, 13...

``` r
x[1,]
```

    ## Geometry set for 1 feature 
    ## geometry type:  LINESTRING
    ## dimension:      XY
    ## bbox:           xmin: 1 ymin: 5 xmax: 4 ymax: 8
    ## epsg (SRID):    NA
    ## proj4string:    NA

    ## LINESTRING(1 5, 2 6, 3 7, 4 8)

The bounding box in the second case reflects the data selected. These bounding boxes are, however, dynamically calculated by calling [`[.sfc`](https://github.com/edzer/sfr/blob/master/R/sfc.R#L90-L91), rather than being pre-defined, as can be seen by sub-selecting the same object created using the functions here, which definitely do not calculated bounding boxes for individual components of simple features collections:

``` r
x1 <- cbind (1:4, 5:8)
x2 <- cbind (11:13, 25:27)
x <- make_sfc (list (x1, x2), type="LINESTRING")
x <- make_sf (x)
x
```

    ## Simple feature collection with 2 features and 0 fields
    ## geometry type:  LINESTRING
    ## dimension:      XY
    ## bbox:           xmin: 1 ymin: 5 xmax: 13 ymax: 27
    ## epsg (SRID):    NA
    ## proj4string:    NA
    ##                                x
    ## 1 LINESTRING(1 5, 2 6, 3 7, 4 8)
    ## 2 LINESTRING(11 25, 12 26, 13...

``` r
x[1,]
```

    ## Geometry set for 1 feature 
    ## geometry type:  LINESTRING
    ## dimension:      XY
    ## bbox:           xmin: 1 ymin: 5 xmax: 4 ymax: 8
    ## epsg (SRID):    NA
    ## proj4string:    NA

    ## LINESTRING(1 5, 2 6, 3 7, 4 8)
