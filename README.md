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
#>   $timestamp     : [ Tue Dec 13 15:11:49 2016 ]
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
#>   $timestamp     : [ Tue Dec 13 15:11:52 2016 ]
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
### Usage

``` r
# CSV example
osmcsv <- '[out:csv(::id,::type,"name")];
area[name="Bonn"]->.a;
( node(area.a)[railway=station];
  way(area.a)[railway=station];
  rel(area.a)[railway=station]; );
out;'

obj <- overpass_query(osmcsv)
read.table(text = obj, sep="\t", header=TRUE, 
           check.names=FALSE, stringsAsFactors=FALSE)
```

``` r
# just nodes
only_nodes <- '[out:xml];
node
  ["highway"="bus_stop"]
  ["shelter"]
  ["shelter"!~"no"]
  (50.7,7.1,50.8,7.25);
out body;'

pts <- overpass_query(only_nodes)$osm_points
sp::plot(pts)
```

![](./fig/README-only_nodes.png)

``` r
# ways & nodes
nodes_and_ways <- '[out:xml];
(node["amenity"="fire_station"]
    (50.6,7.0,50.8,7.3);
  way["amenity"="fire_station"]
    (50.6,7.0,50.8,7.3);
  rel["amenity"="fire_station"]
    (50.6,7.0,50.8,7.3););
(._;>;);
out;'

wys <- overpass_query(nodes_and_ways)
sp::plot(wys$osm_lines)
```

![](./fig/README-nodes_and_ways.png)

``` r
# xml version of the query
actual_ways <- '<osm-script output="xml">
  <query type="way">
    <bbox-query e="7.157" n="50.748" s="50.746" w="7.154"/>
  </query>
  <union>
    <item/>
    <recurse type="down"/>
  </union>
  <print/>
</osm-script>'

awy <- overpass_query(actual_ways)
sp::plot(awy$osm_lines)
```

![](./fig/README-actual_ways.png)

``` r
# more complex example: motorways surrounding London
# warning: may take a few minutes to run
from_robin <- '[out:xml][timeout:100];
(
  node["highway"="motorway"](51.24,-0.61,51.73,0.41);
  way["highway"="motorway"](51.24,-0.61,51.73,0.41);
  relation["highway"="motorway"](51.24,-0.61,51.73,0.41);
);
out body;
>;
out skel qt;'

res <- overpass_query(from_robin)
frb <- res$osm_lines
```

![](./fig/README-london-motorways.png)

### Test Results

``` r
date()
#> [1] "Tue Dec 13 15:11:52 2016"

testthat::test_dir("tests/")
#> testthat results ===========================================================
#> OK: 12 SKIPPED: 0 FAILED: 0
#> 
#> DONE ======================================================================
```

### Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CONDUCT.md). By participating in this project you agree to abide by its terms.
