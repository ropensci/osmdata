osmdatar
========

R package for downloading OSM data

------------------------------------------------------------------------

Speed comparisons
-----------------

The `osmplotr` package uses `XML` to process the API query, and `osmar` to convert the result to `sp` structures. The [overpass](https://github.com/hrbrmstr/overpass/) repo of [hrbrmstr](https://github.com/hrbrmstr) uses `xml2` and thus all cribbed functions are called `_xml2_`.

``` r
library (microbenchmark)
```

The **examples** code is repeated here with `microbenchmark` comparisons

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

``` r
doc2 <- get_xml2_doc (bbox=bbox)
mb2 <- microbenchmark ( obj2 <- process_xml2_doc (doc2), times=100L )
tt2 <- formatC (mean (mb2$time) / 1e9, format="f", digits=2)
```

``` r
cat ("Mean time to convert with hrbrmstr code =", tt2, "\n")
```

    ## Mean time to convert with hrbrmstr code = 1.48

The code of **hrbrmstr** using `dplyr` is (only) around 30% faster than using `osmar`. Definitely time to try a C++ version ...
