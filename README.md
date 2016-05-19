osmdatar
========

R package for downloading OSM data

------------------------------------------------------------------------

Install
-------

``` r
Sys.setenv ('PKG_CXXFLAGS'='-std=c++11')
setwd ("..")
#devtools::document ("osmdatar")
devtools::load_all ("osmdatar")
setwd ("./osmdatar")
Sys.unsetenv ('PKG_CXXFLAGS')
```

------------------------------------------------------------------------

Speed comparisons
-----------------

The `osmplotr` package uses `XML` to process the API query, and `osmar` to convert the result to `sp` structures. The [overpass](https://github.com/hrbrmstr/overpass/) repo of [hrbrmstr](https://github.com/hrbrmstr) uses `xml2` and thus all cribbed functions are called `_xml2_`. All of my new `Rcpp` functions are then `_3`.

``` r
library (microbenchmark)
```

Osmar / osmplotr
----------------

``` r
bbox <- matrix (c (-0.12, 51.51, -0.11, 51.52), nrow=2, ncol=2)
doc <- get_xml_doc (bbox=bbox)
mb <- microbenchmark ( obj <- process_xml_doc (doc), times=100L)
tt <- formatC (mean (mb$time) / 1e9, format="f", digits=2)
```

``` r
cat ("Mean time to convert with osmar =", tt, "s\n")
```

    ## Mean time to convert with osmar = 2.05 s

hrbrmstr
--------

``` r
doc2 <- get_xml2_doc (bbox=bbox)
mb2 <- microbenchmark ( obj2 <- process_xml2_doc (doc2), times=100L )
tt2 <- formatC (mean (mb2$time) / 1e9, format="f", digits=2)
```

``` r
cat ("Mean time to convert with hrbrmstr code =", tt2, "\n")
```

    ## Mean time to convert with hrbrmstr code = 1.48

The code of **hrbrmstr** using `dplyr` is (only) around 30% faster than using `osmar`. And then for the C++ version ...

Rcpp
----

The function calls *should* compile properly within the `load_all` call, but in case they don't they can be loaded manually here:

``` r
Sys.setenv ('PKG_CXXFLAGS'='-std=c++11')
Rcpp::sourceCpp('src/get_highways.cpp')
Sys.unsetenv ('PKG_CXXFLAGS')
```

(One reason this might be necesssary is because `devtools::document` fails to insert the necessary line `useDynLib(osmdatar)` in `NAMESPACE`. Re-inserting this manually should fix the problem.)

And then the actual test, using `process_xml_doc3`:

``` r
txt <- get_xml_doc3 (bbox=bbox)
mb3 <- microbenchmark ( obj3 <- process_xml_doc3 (txt), times=100L )
tt3 <- formatC (mean (mb3$time) / 1e9, format="f", digits=2)
```

``` r
cat ("Mean time to convert with Rcpp code =", tt3, "\n")
```

    ## Mean time to convert with Rcpp code = 0.34

It's a promising start, and admittedly slow at present because it relies on a loop within `process_xml_doc3` that ought definitely be able to be constructed in a much faster way.
