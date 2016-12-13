<!-- README.md is generated from README.Rmd. Please edit that file -->
[![Build Status](https://travis-ci.org/osmdatar/osmdata.svg?branch=master)](https://travis-ci.org/osmdatar/osmdata) [![codecov](https://codecov.io/gh/osmdatar/osmdata/branch/master/graph/badge.svg)](https://codecov.io/gh/osmdatar/osmdata) [![Project Status: WIP](http://www.repostatus.org/badges/0.1.0/wip.svg)](http://www.repostatus.org/#wip) [![CRAN\_Status\_Badge](http://www.r-pkg.org/badges/version/osmdata)](http://cran.r-project.org/web/packages/osmdata)

![](./fig/title.png)

`osmdata` is an R package for accessing OpenStreetMap (OSM) data using the [Overpass API](http://wiki.openstreetmap.org/wiki/Overpass_API). The Overpass API (or OSM3S) is a read-only API that serves up custom selected parts of the OSM map data. Map data are returned as [`sp`](https://cran.r-project.org/package=sp) objects.

### Installation

``` r
devtools::install_github("osmdatar/osmdata")
```

    #> Loading osmdata
    #> Data (c) OpenStreetMap contributors, ODbL 1.0. http://www.openstreetmap.org/copyright

Current verison:

``` r
library(osmdata)
packageVersion("osmdata")
#> [1] '0.0.0'
```

### Usage

[Overpass API](http://wiki.openstreetmap.org/wiki/Overpass_API) queries can be built from a base query constructed with `opq` followed by `add_feature`. The corresponding OSM objects are then downloaded and converted to `sp` objects with `overpass_query`. For example,

``` r
q0 <- opq (bbox=c(-0.12,51.51,-0.11,51.52)) # Central London, U.K.
q1 <- add_feature (q0, key='building')
bu <- overpass_query (q1, quiet=TRUE)
bu
#> Object of class 'osmdata' with:
#>   $bbox          : 51.51,-0.12,51.52,-0.11
#>   $overpass_call : The call submitted to the overpass API
#>   $timestamp     : [ Tue Dec 13 15:33:04 2016 ]
#>   $osm_points    : 'sp' SpatialPointsDataFrame   with 5071 points
#>   $osm_lines     : 'sp' SpatialLinesDataFrame    with 14 lines
#>   $osm_polygons  : 'sp' SpatialPolygonsDataFrame with 578 polygons
```

or,

``` r
q2 <- add_feature (q0, key='highway', value='secondary')
q2 <- add_feature (q0, key='highway')
hs <- overpass_query (q2, quiet=TRUE)
hs
#> Object of class 'osmdata' with:
#>   $bbox          : 51.51,-0.12,51.52,-0.11
#>   $overpass_call : The call submitted to the overpass API
#>   $timestamp     : [ Tue Dec 13 15:33:05 2016 ]
#>   $osm_points    : 'sp' SpatialPointsDataFrame   with 1984 points
#>   $osm_lines     : 'sp' SpatialLinesDataFrame    with 545 lines
#>   $osm_polygons  : 'sp' SpatialPolygonsDataFrame with 34 polygons
```

Plotting with `sp`:

``` r
sp::plot (bu$osm_polygons)
lines (hs$osm_lines, col="red")
```

![](./fig/README-plot1.png)

The [Overpass API](http://wiki.openstreetmap.org/wiki/Overpass_API) provides access to OSM elements selected by search criteria such as location, types of objects, tag properties, proximity, or combinations of these.

To explore simple Overpass queries interactively, try [overpass turbo](http://overpass-turbo.eu/), and to find out more about building queries see the [Language Guide](http://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide) or the more comprehensive [Language Reference](http://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL).

<!--
The following functions are implemented:

- `add_feature`:    Add a feature to an Overpass query
- `available_features`: List recognized features in OSM Overpass
- `available_tags`: List tags associated with a feature
- `bbox_to_string`: Convert a named matrix or a named vector (or an unnamed vector) return a string
- `opq`:    Begin building an Overpass query
- `overpass_query`: Issue OSM Overpass Query
- `overpass_status`:    Retrieve status of the Overpass API
- `read_osm`:   Read an XML OSM Overpass response from path
-->
### Further examples

``` r
q0 <- opq (bbox=getbb ("Bonn")) # Bonn, Germany
q1 <- add_feature (q0, key="railway", value="station")
overpass_query (q1, quiet=TRUE)
#> Object of class 'osmdata' with:
#>   $bbox          : 50.575851,6.94066,50.895851,7.26066
#>   $overpass_call : The call submitted to the overpass API
#>   $timestamp     : [ Tue Dec 13 15:33:09 2016 ]
#>   $osm_points    : 'sp' SpatialPointsDataFrame   with 43 points
#>   $osm_lines     : 'sp' SpatialLinesDataFrame    with 0 lines
#>   $osm_polygons  : 'sp' SpatialPolygonsDataFrame with 1 polygons
```

``` r
q0 <- opq (bbox=c(7.1,50.7,7.25,50.8))
q1 <- add_feature (q0, key="highway", value="bus_stop")
q1 <- add_feature (q1, key="shelter")
q1 <- add_feature (q1, key="shelter", value="!no")
pts <- overpass_query (q1, quiet=TRUE)
sp::plot (pts$osm_points)
```

![](./fig/README-only_nodes.png)

``` r
q0 <- opq (bbox=getbb ("London, UK"))
q1 <- add_feature (q0, key="highway", value="motorway")
lon <- overpass_query (q1, quiet=TRUE)
sp::plot (lon$osm_lines)
```

![](./fig/README-london-motorways.png)

### Test Results

``` r
date()
#> [1] "Tue Dec 13 15:33:09 2016"

testthat::test_dir("tests/")
#> testthat results ===========================================================
#> OK: 12 SKIPPED: 0 FAILED: 0
#> 
#> DONE ======================================================================
```

### Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CONDUCT.md). By participating in this project you agree to abide by its terms.
