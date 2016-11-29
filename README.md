
<!-- README.md is generated from README.Rmd. Please edit that file -->
[![Build Status](https://travis-ci.org/osmdatar/osmdata.svg?branch=master)](https://travis-ci.org/osmdatar/osmdata) [![codecov](https://codecov.io/gh/osmdatar/osmdata/branch/master/graph/badge.svg)](https://codecov.io/gh/osmdatar/osmdata)

![](./fig/title.png)

`osmdata` is an R package for accessing OpenStreetMap (OSM) data using the [Overpass API](http://wiki.openstreetmap.org/wiki/Overpass_API). The Overpass API (or OSM3S) is a read-only API that serves up custom selected parts of the OSM map data. Map data are returned as [`sp`](https://cran.r-project.org/package=sp) objects.

<https://github.com/mtennekes/tmap/blob/master/pkg/R/bb.R> plus <https://github.com/mtennekes/tmap/blob/master/pkg/R/end_of_the_world.R> plus `maybe_longlat` from <https://github.com/mtennekes/tmap/blob/master/pkg/R/is_projected.R> plus raster::extent, rgeos::gIntersection

### Installation

``` r
devtools::install_github("osmdatar/osmdata")
```

Current verison:

``` r
library(osmdata)
packageVersion("osmdata")
#> [1] '0.0.0'
```

### Usage

[Overpass API](http://wiki.openstreetmap.org/wiki/Overpass_API) queries can be built from a base query constructed with `opq` followed by `add_features`. The corresponding OSM objects are then downloaded and converted to `sp` objects with `overpass_query`. For example,

``` r
q0 <- opq (bbox=c(-0.12,51.11,-0.11,51.12)) # Central London, U.K.
q1 <- add_feature (q0, key='building')
bh <- overpass_query (q1)
class (bh); sapply (bh, summary)
#> [1] "list"    "osmdata"
#>        bbox        overpass_call osm_points              
#> Length "1"         "1"           "48"                    
#> Class  "character" "character"   "SpatialPointsDataFrame"
#> Mode   "character" "character"   "S4"                    
#>        osm_lines               osm_polygons timestamp  
#> Length "9"                     "0"          "1"        
#> Class  "SpatialLinesDataFrame" "NULL"       "character"
#> Mode   "S4"                    "NULL"       "character"
```

or,

``` r
q2 <- add_feature (q0, key='highway', value='tertiary')
hs <- overpass_query (q2)
class (hs); sapply (hs, summary)
#> [1] "list"    "osmdata"
#>        bbox        overpass_call osm_points              
#> Length "1"         "1"           "43"                    
#> Class  "character" "character"   "SpatialPointsDataFrame"
#> Mode   "character" "character"   "S4"                    
#>        osm_lines               osm_polygons timestamp  
#> Length "2"                     "0"          "1"        
#> Class  "SpatialLinesDataFrame" "NULL"       "character"
#> Mode   "S4"                    "NULL"       "character"
```

``` r
q1 <- opq (bbox=c(-0.12,51.51,-0.1,51.52)) 
q1 <- add_feature (q1, key='building')
b <- overpass_query (q1)
summary (overpass_query (q1))
#>               Length Class                    Mode     
#> bbox             1   -none-                   character
#> overpass_call    1   -none-                   character
#> osm_points    9272   SpatialPointsDataFrame   S4       
#> osm_lines     1095   SpatialLinesDataFrame    S4       
#> osm_polygons    45   SpatialPolygonsDataFrame S4       
#> timestamp        1   -none-                   character

q2 <- opq (bbox=c(-0.12,51.51,-0.11,51.52)) 
q2 <- add_feature (q2, key='highway', value='primary')
hs <- overpass_query (q2)
summary (hs)
#>               Length Class                  Mode     
#> bbox            1    -none-                 character
#> overpass_call   1    -none-                 character
#> osm_points    364    SpatialPointsDataFrame S4       
#> osm_lines      77    SpatialLinesDataFrame  S4       
#> osm_polygons    0    -none-                 NULL     
#> timestamp       1    -none-                 character

q3 <- opq (bbox=c(-0.12,51.51,-0.1,51.52)) 
q3 <- add_feature (q3, key='building')
q3 <- add_feature (q3, key='highway', 'secondary')
summary (overpass_query (q3))
#>               Length Class                    Mode     
#> bbox             1   -none-                   character
#> overpass_call    1   -none-                   character
#> osm_points    9348   SpatialPointsDataFrame   S4       
#> osm_lines     1112   SpatialLinesDataFrame    S4       
#> osm_polygons    45   SpatialPolygonsDataFrame S4       
#> timestamp        1   -none-                   character
```

It acts as a database over the web: the client sends a query to the API and gets back the data set that corresponds to the query. To explore simple Overpass queries interactively, try [overpass turbo](http://overpass-turbo.eu/).

Here's an [RPub](http://rpubs.com/hrbrmstr/overpass) for `overpass` that I'll continually update as this goes (that will eventually be a vignette).

Unlike the main API, which is optimized for editing, Overpass API is optimized for data consumers that need a few elements within a glimpse or up to roughly 100 million elements in some minutes, both selected by search criteria like e.g. location, type of objects, tag properties, proximity, or combinations of them.

Overpass API has a powerful query language (language guide, language reference, an IDE) beyond XAPI, but also has a compatibility layer to allow a smooth transition from XAPI.

This package pairs nicely with [nominatim](http://github.com/hrbrmstr/nominatim).

The following functions are implemented:

-   `add_feature`: Add a feature to an Overpass query
-   `available_features`: List recognized features in OSM Overpass
-   `available_tags`: List tags associated with a feature
-   `bbox_to_string`: Convert a named matrix or a named vector (or an unnamed vector) return a string
-   `opq`: Begin building an Overpass query
-   `overpass_query`: Issue OSM Overpass Query
-   `overpass_status`: Retrieve status of the Overpass API
-   `read_osm`: Read an XML OSM Overpass response from path

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

<img src="./fig/README-only_nodes.png" width="672" />

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

<img src="./fig/README-nodes_and_ways.png" width="672" />

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

<img src="./fig/README-actual_ways.png" width="672" />

``` r
# more complex example from Robin: motorways surrounding London
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

``` r
library(tmap)
qtm(frb)
```

<img src="./fig/README-london-motorways.png" width="672" />

### Test Results

``` r
date()
#> [1] "Sat Nov 19 08:53:33 2016"

testthat::test_dir("tests/")
#> testthat results ===========================================================
#> OK: 12 SKIPPED: 0 FAILED: 0
#> 
#> DONE ======================================================================
```

### Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CONDUCT.md). By participating in this project you agree to abide by its terms.
