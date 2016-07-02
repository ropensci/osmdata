[![Build Status](https://travis-ci.org/osmdatar/osmdatar.svg?branch=master)](https://travis-ci.org/osmdatar/osmdatar) [![codecov](https://codecov.io/gh/osmdatar/osmdatar/branch/master/graph/badge.svg)](https://codecov.io/gh/osmdatar/osmdatar)

![](./figure/map.png)

R package for downloading OpenStreetMap data and converting to `sp` objects *really quickly*! It does not do anything not currently possible with [`osmar`](https://cran.r-project.org/package=osmar) or [`osmplotr`](https://cran.r-project.org/package=osmplotr), but what these packages do `osmdatar` does a heck of a lot faster.

`osmdatar`, like [`osmplotr`](https://cran.r-project.org/package=osmplotr), uses the [overpass](http://overpass-api.de/) API, which allows specific `key-value` queries, along with additional `extra_pairs` for more specific requests and much faster downloads. The real advantage nevertheless lies in the processing. Conversion of the streets in the above map to a `SpatialLinesDataFrame` is 25 times faster with `osmdatar` than `osmar`.

Given that specific downloading with the [`overpass`](http://overpass-api.de/) API is likely to be at least 10 times faster than the generic downloads of [`osmar`](https://cran.r-project.org/package=osmar), `osmdatar` is likely to be several hundred times faster than other current options for accessing OpenStreetMap data.

------------------------------------------------------------------------

Install
-------

``` r
devtools::install_github ('osmdatar/osmdatar')
```

------------------------------------------------------------------------

Usage
-----

The package currently downloads and converts points, lines, and polygons, with the three respective functions:

1.  `get_points`

2.  `get_lines`

3.  `get_polygons`

Points generally correspond to OSM nodes, and ways to OSM highways, with the exact case dependending on the specific `key-value` pairs passed to the [overpass](http://overpass-api.de/) API.

Note that `get_polygons` does not yet have the capability to process OpenStreetMap `multipolygon` objects.

------------------------------------------------------------------------

Demonstration
-------------

An example in a small part of central London, U.K.

``` r
bbox <- matrix (c (-0.11, 51.51, -0.10, 51.52), nrow=2, ncol=2) 
system.time ( dat_H <- get_lines (bbox=bbox, key='highway'))
```

    ##    user  system elapsed 
    ##   0.240   0.008   1.981

``` r
class (dat_H)
```

    ## [1] "SpatialLinesDataFrame"
    ## attr(,"package")
    ## [1] "sp"

``` r
dat_HP <- get_lines (bbox=bbox, key='highway', value='primary')
dat_HNP <- get_lines (bbox=bbox, key='highway', value='!primary')
length (dat_HP); length (dat_HNP); length (dat_H)
```

    ## [1] 100

    ## [1] 618

    ## [1] 718

And obviously the primary plus non-primary highways give the same result as without `value`.
