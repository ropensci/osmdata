<!-- README.md is generated from README.Rmd. Please edit that file -->
overpass is a packge with tools to work with the OpenStreetMap (OSM) [Overpass API](http://wiki.openstreetmap.org/wiki/Overpass_API)

The following functions are implemented:

-   `overpass_query`: Issue OSM Overpass Query

### News

-   Version 0.0.0.9000 released

### Installation

``` r
devtools::install_github("hrbrmstr/overpass")
```

### Usage

``` r
library(overpass)
library(sp)
library(ggplot2)

# current verison
packageVersion("overpass")
#> [1] '0.0.0.9000'
```

``` r
# CSV example
osmcsv <- '[out:csv(::id,::type,"name")];
area[name="Bonn"]->.a;
( node(area.a)[railway=station];
  way(area.a)[railway=station];
  rel(area.a)[railway=station]; );
out;'

read.table(text=overpass_query(osmcsv), sep="\t", header=TRUE, 
           check.names=FALSE, stringsAsFactors=FALSE)
#>          @id @type               name
#> 1   26945519  node    Bonn-Oberkassel
#> 2 1271017705  node         Bonn-Beuel
#> 3 2428355974  node Bonn-Bad Godesberg
#> 4 2713060210  node  Bonn Hauptbahnhof
#> 5 3400717493  node        Bonn-Mehlem
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

pts <- overpass_query(only_nodes)
plot(pts)
```

<img src="README-only_nodes-1.png" title="" alt="" width="672" />

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
plot(wys)
```

<img src="README-nodes_and_ways-1.png" title="" alt="" width="672" />

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
plot(awy)
```

<img src="README-actual_ways-1.png" title="" alt="" width="672" />

``` r
# more complex example from Robin

from_robin <- '<osm-script output="xml" timeout="25">
<union into="_">
<query into="_" type="node">
<has-kv k="highway" modv="" v="motorway"/>
<bbox-query e="-1.9267272949218748" into="_" n="53.62550271303527" s="53.372678592569365" w="-2.44171142578125"/>
</query>
<query into="_" type="way">
<has-kv k="highway" modv="" v="motorway"/>
<bbox-query e="-1.9267272949218748" into="_" n="53.62550271303527" s="53.372678592569365" w="-2.44171142578125"/>
</query>
<query into="_" type="relation">
<has-kv k="highway" modv="" v="motorway"/>
<bbox-query e="-1.9267272949218748" into="_" n="53.62550271303527" s="53.372678592569365" w="-2.44171142578125"/>
</query>
</union>
<print e="" from="_" geometry="skeleton" limit="" mode="body" n="" order="id" s="" w=""/>
<recurse from="_" into="_" type="down"/>
<print e="" from="_" geometry="skeleton" limit="" mode="skeleton" n="" order="quadtile" s="" w=""/>
</osm-script>'

frb <- overpass_query(from_robin)

gg <- ggplot()
gg <- gg + geom_path(data=fortify(frb), 
                     aes(x=long, y=lat, group=group),
                     color="black", size=0.25)
gg <- gg + coord_quickmap()
gg <- gg + ggthemes::theme_map()
gg
```

<img src="README-from_robin-1.png" title="" alt="" width="672" />

### Test Results

``` r
library(overpass)
library(testthat)

date()
#> [1] "Mon Aug 10 12:25:46 2015"

test_dir("tests/")
#> testthat results ===========================================================
#> OK: 0 SKIPPED: 0 FAILED: 0
#> 
#> DONE
```

### Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CONDUCT.md). By participating in this project you agree to abide by its terms.
