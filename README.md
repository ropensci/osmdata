<!-- README.md is generated from README.Rmd. Please edit that file -->
[![Build Status](https://travis-ci.org/osmdatar/osmdata.svg?branch=master)](https://travis-ci.org/osmdatar/osmdata) [![codecov](https://codecov.io/gh/osmdatar/osmdata/branch/master/graph/badge.svg)](https://codecov.io/gh/osmdatar/osmdata)

`osmdata` is a packge with tools to work with the OpenStreetMap (OSM) [Overpass API](http://wiki.openstreetmap.org/wiki/Overpass_API). To explore simple Overpass queries interactively, try [overpass turbo](http://overpass-turbo.eu/).

Here's an [RPub](http://rpubs.com/hrbrmstr/overpass) for `overpass` that I'll continually update as this goes (that will eventually be a vignette).

The Overpass API (or OSM3S) is a read-only API that serves up custom selected parts of the OSM map data. It acts as a database over the web: the client sends a query to the API and gets back the data set that corresponds to the query.

Unlike the main API, which is optimized for editing, Overpass API is optimized for data consumers that need a few elements within a glimpse or up to roughly 100 million elements in some minutes, both selected by search criteria like e.g. location, type of objects, tag properties, proximity, or combinations of them. It acts as a database backend for various services.

Overpass API has a powerful query language (language guide, language reference, an IDE) beyond XAPI, but also has a compatibility layer to allow a smooth transition from XAPI.

This package pairs nicely with [nominatim](http://github.com/hrbrmstr/nominatim).

The following functions are implemented:

-   `add_feature`: Add a feature to an Overpass query
-   `available_features`: List recognized features in OSM Overpass
-   `available_tags`: List tags associated with a feature
-   `bbox_to_string`: Convert a named matrix or a named vector (or an unnamed vector) return a string
-   `issue_query`: Finalize and issue an Overpass query
-   `opq`: Begin building an Overpass query
-   `overpass_query`: Issue OSM Overpass Query
-   `overpass_status`: Retrieve status of the Overpass API
-   `read_osm`: Read an XML OSM Overpass response from path

### Installation

``` r
devtools::install_github("osmdatar/osmdata")
```

### Usage

``` r
library(osmdata)
library(sp)
library(ggmap)
```

``` r
# current verison
packageVersion("osmdata")
#> [1] '0.0.0'
```

``` r
# CSV example
osmcsv <- '[out:csv(::id,::type,"name")];
area[name="Bonn"]->.a;
( node(area.a)[railway=station];
  way(area.a)[railway=station];
  rel(area.a)[railway=station]; );
out;'

opq <- overpass_query(osmcsv)
read.table(text = opq, sep="\t", header=TRUE, 
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

pts <- overpass_query(only_nodes)$osm_nodes
sp::plot(pts)
```

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
sp::plot(wys$osm_ways)
```

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
sp::plot(awy$osm_ways)
```

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

frb <- overpass_query(from_robin)$osm_ways

gg <- ggplot2::ggplot()
gg <- gg + ggplot2::geom_path(data=ggplot2::fortify(frb), 
                     ggplot2::aes(x=long, y=lat, group=group),
                     color="black", size=0.25)
gg <- gg + ggplot2::coord_quickmap()
gg <- gg + ggthemes::theme_map()
gg
```

``` r
#ggsave("README-from_robin-1.png")
```

### Test Results

``` r
date()
#> [1] "Wed Oct 19 21:49:15 2016"

testthat::test_dir("tests/")
#> testthat results ===========================================================
#> OK: 0 SKIPPED: 0 FAILED: 0
#> 
#> DONE ======================================================================
```

### Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CONDUCT.md). By participating in this project you agree to abide by its terms.
