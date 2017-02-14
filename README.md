<!-- README.md is generated from README.Rmd. Please edit that file -->
[![Build Status](https://travis-ci.org/osmdatar/osmdata.svg?branch=master)](https://travis-ci.org/osmdatar/osmdata) [![Build status](https://ci.appveyor.com/api/projects/status/github/osmdatar/osmdata?svg=true)](https://ci.appveyor.com/project/mpadge/osmdata) [![codecov](https://codecov.io/gh/osmdatar/osmdata/branch/master/graph/badge.svg)](https://codecov.io/gh/osmdatar/osmdata) [![Project Status: WIP](http://www.repostatus.org/badges/0.1.0/wip.svg)](http://www.repostatus.org/#wip) [![CRAN\_Status\_Badge](http://www.r-pkg.org/badges/version/osmdata)](http://cran.r-project.org/web/packages/osmdata)

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

[Overpass API](http://wiki.openstreetmap.org/wiki/Overpass_API) queries can be built from a base query constructed with `opq` followed by `add_feature`. The corresponding OSM objects are then downloaded and converted to `sf` objects with `osmdata_sf` or to `sp` objects with `osmdata_sp`. For example,

``` r
q0 <- opq (bbox=c(-0.27,51.47,-0.20,51.50)) # Chiswick Eyot in London, U.K.
q1 <- add_feature (q0, key='name', value="Thames", exact=FALSE)
x <- osmdata_sf (q1)
x
#> Object of class 'osmdata' with:
#>                  $bbox : 51.47,-0.27,51.5,-0.2
#>         $overpass_call : The call submitted to the overpass API
#>             $timestamp : [ Tue Feb 14 18:36:41 2017 ]
#>            $osm_points : 'sf' Simple Features Collection with 21249 points
#>             $osm_lines : 'sf' Simple Features Collection with 1871 linestrings
#>          $osm_polygons : 'sf' Simple Features Collection with 22 polygons
#>        $osm_multilines : 'sf' Simple Features Collection with 5 multilinestrings
#>     $osm_multipolygons : 'sf' Simple Features Collection with 3 multipolygons
```

``` r
q0 <- opq (bbox=c(-0.12,51.51,-0.11,51.52)) # Central London, U.K.
q1 <- add_feature (q0, key='building')
bu <- osmdata_sp (q1)
bu
#> Object of class 'osmdata' with:
#>                  $bbox : 51.51,-0.12,51.52,-0.11
#>         $overpass_call : The call submitted to the overpass API
#>             $timestamp : [ Tue Feb 14 18:36:43 2017 ]
#>            $osm_points : 'sp' SpatialpointsDataFrame with 5049 points
#>             $osm_lines : 'sp' SpatiallinesDataFrame with 12 lines
#>          $osm_polygons : 'sp' SpatialpolygonsDataFrame with 564 polygons
#>        $osm_multilines : 'sp' SpatialmultilinesDataFrame with 0 multilines
#>     $osm_multipolygons : 'sp' SpatialmultipolygonsDataFrame with 15 multipolygons
```

or,

``` r
q2 <- add_feature (q0, key='highway')
hs <- osmdata_sp (q2)
hs
#> Object of class 'osmdata' with:
#>                  $bbox : 51.51,-0.12,51.52,-0.11
#>         $overpass_call : The call submitted to the overpass API
#>             $timestamp : [ Tue Feb 14 18:36:54 2017 ]
#>            $osm_points : 'sp' SpatialpointsDataFrame with 1984 points
#>             $osm_lines : 'sp' SpatiallinesDataFrame with 550 lines
#>          $osm_polygons : 'sp' SpatialpolygonsDataFrame with 30 polygons
#>        $osm_multilines : 'sp' SpatialmultilinesDataFrame with 0 multilines
#>     $osm_multipolygons : 'sp' SpatialmultipolygonsDataFrame with 3 multipolygons
```

Plotting with `sp`:

``` r
sp::plot (bu$osm_polygons)
lines (hs$osm_lines, col="red")
```

![](./fig/README-plot1.png)

``` r
q0 <- opq (bbox=getbb ("London, UK"))
q1 <- add_feature (q0, key="highway", value="motorway")
lon <- osmdata_sp (q1, quiet=TRUE)
sp::plot (lon$osm_lines)
```

![](./fig/README-london-motorways.png)

OSM data can also be downloaded in OSM XML format with `osmdata_xml` and saved for use with other software.

``` r
osmdata_xml (q1, "data.xml")
```

The `XML` document is returned silently and can be passed directly to `osmdata_sp` or `osmdata_sf`

``` r
doc <- osmdata_xml (q1, "data.xml")
x <- osmdata_sf (q1, doc)
```

Or data can be read from a previously downloaded file:

``` r
x <- osmdata_sf (q1, "data.xml")
```

The [Overpass API](http://wiki.openstreetmap.org/wiki/Overpass_API) provides access to OSM elements selected by search criteria such as location, types of objects, tag properties, proximity, or combinations of these.

To explore simple Overpass queries interactively, try [overpass turbo](http://overpass-turbo.eu/), and to find out more about building queries see the [Language Guide](http://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide) or the more comprehensive [Language Reference](http://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL).

### Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CONDUCT.md). By participating in this project you agree to abide by its terms.
