<!-- README.md is generated from README.Rmd. Please edit that file -->

osmdata <a href='https://docs.ropensci.org/osmdata/'><img src='man/figures/osmhex.png' align="right" height=210 width=182/></a>
===============================================================================================================================

<!-- badges: start -->

[![R build
status](https://github.com/ropensci/osmdata/workflows/R-CMD-check/badge.svg)](https://github.com/ropensci/osmdata/actions?query=workflow%3AR-CMD-check)
[![codecov](https://codecov.io/gh/ropensci/osmdata/branch/master/graph/badge.svg)](https://codecov.io/gh/ropensci/osmdata)
[![Project Status:
Active](http://www.repostatus.org/badges/latest/active.svg)](http://www.repostatus.org/#active)
[![CRAN\_Status\_Badge](http://www.r-pkg.org/badges/version/osmdata)](http://cran.r-project.org/web/packages/osmdata)
[![CRAN
Downloads](http://cranlogs.r-pkg.org/badges/grand-total/osmdata?color=orange)](http://cran.r-project.org/package=osmdata)

<!--![](./man/figures/title.png)-->

[![](https://badges.ropensci.org/103_status.svg)](https://github.com/ropensci/onboarding/issues/103)
[![status](http://joss.theoj.org/papers/0f59fb7eaeb2004ea510d38c00051dd3/status.svg)](http://joss.theoj.org/papers/0f59fb7eaeb2004ea510d38c00051dd3)

<!-- badges: end -->

`osmdata` is an R package for accessing the data underlying
OpenStreetMap (OSM), delivered via the [Overpass
API](https://wiki.openstreetmap.org/wiki/Overpass_API). (Other packages
such as
[`OpenStreetMap`](https://cran.r-project.org/web/packages/OpenStreetMap/index.html)
can be used to download raster tiles based on OSM data.)
[Overpass](https://overpass-turbo.eu) is a read-only API that extracts
custom selected parts of OSM data. Data can be returned in a variety of
formats, including as [Simple Features
(`sf`)](https://cran.r-project.org/package=sf), [Spatial
(`sp`)](https://cran.r-project.org/package=sp), or [Silicate
(`sc`)](https://github.com/hypertidy/silicate) objects. The package is
designed to allow access to small-to-medium-sized OSM datasets (see
[`geofabrik`](https://github.com/ITSLeeds/geofabrik) for an approach for
reading-in bulk OSM data extracts).

Installation
------------

To install latest CRAN version:

    install.packages("osmdata")

Alternatively, install the development version with any one of the
following options:

    # install.packages("remotes")
    remotes::install_git("https://git.sr.ht/~mpadge/osmdata")
    remotes::install_bitbucket("mpadge/osmdata")
    remotes::install_gitlab("mpadge/osmdata")
    remotes::install_github("ropensci/osmdata")

To load the package and check the version:

    library(osmdata)
    #> Data (c) OpenStreetMap contributors, ODbL 1.0. https://www.openstreetmap.org/copyright
    packageVersion("osmdata")
    #> [1] '0.1.3'

Usage
-----

[Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API) queries
can be built from a base query constructed with `opq` followed by
`add_osm_feature`. The corresponding OSM objects are then downloaded and
converted to [Simple Feature
(`sf`)](https://cran.r-project.org/package=sf) objects with
`osmdata_sf()`, [Spatial (`sp`)](https://cran.r-project.org/package=sp)
objects with `osmdata_sp()` or [Silicate
(`sc`)](https://github.com/hypertidy/silicate) objects with
`osmdata_sc()`. For example,

    x <- opq(bbox = c(-0.27, 51.47, -0.20, 51.50)) %>% # Chiswick Eyot in London, U.K.
        add_osm_feature(key = 'name', value = "Thames", value_exact = FALSE) %>%
        osmdata_sf()
    x

    #> Object of class 'osmdata' with:
    #>                  $bbox : 51.47,-0.27,51.5,-0.2
    #>         $overpass_call : The call submitted to the overpass API
    #>                  $meta : metadata including timestamp and version numbers
    #>            $osm_points : 'sf' Simple Features Collection with 24548 points
    #>             $osm_lines : 'sf' Simple Features Collection with 2219 linestrings
    #>          $osm_polygons : 'sf' Simple Features Collection with 33 polygons
    #>        $osm_multilines : 'sf' Simple Features Collection with 6 multilinestrings
    #>     $osm_multipolygons : 'sf' Simple Features Collection with 3 multipolygons

OSM data can also be downloaded in OSM XML format with `osmdata_xml()`
and saved for use with other software.

    osmdata_xml(q1, "data.osm")

### Bounding Boxes

All `osmdata` queries begin with a bounding box defining the area of the
query. The [`getbb()`
function](https://docs.ropensci.org/osmdata/reference/getbb.html) can be
used to extract bounding boxes for specified place names.

    getbb ("astana kazakhstan")
    #>        min      max
    #> x 71.22444 71.78519
    #> y 51.00068 51.35111

The next step is to convert that to an overpass query object with the
[`opq()`
function](https://docs.ropensci.org/osmdata/reference/opq.html):

    q <- opq (getbb ("astana kazakhstan"))
    q <- opq ("astana kazakhstan") # identical result

It is also possible to use bounding polygons rather than rectangular
boxes:

    b <- getbb ("bangalore", format_out = "polygon")
    class (b); head (b [[1]])
    #> [1] "matrix" "array"
    #> [1] 77.4601

### Features

The next step is to define features of interest using the
[`add_osm_feature()`
function](https://docs.ropensci.org/osmdata/reference/add_osm_feature.html).
This function accepts `key` and `value` parameters specifying desired
features in the [OSM key-vale
schema](https://wiki.openstreetmap.org/wiki/Map_Features). Multiple
`add_osm_feature()` calls may be combined as illustrated below, with the
result being a logical AND operation, thus returning all amenities that
are labelled both as restaurants and also as pubs:

    q <- opq ("portsmouth usa") %>%
        add_osm_feature(key = "amenity", value = "restaurant") %>%
        add_osm_feature(key = "amenity", value = "pub") # There are none of these

(Logical OR combinations are demonstrated [below](#additional).)
Negation can also be specified by pre-pending an exclamation mark so
that the following requests all amenities that are NOT labelled as
restaurants and that are not labelled as pubs:

    q <- opq ("portsmouth usa") %>%
        add_osm_feature(key = "amenity", value = "!restaurant") %>%
        add_osm_feature(key = "amenity", value = "!pub") # There are a lot of these

Additional arguments allow for more refined matching, such as the
following request for all pubs with “irish” in the name:

    q <- opq ("washington dc") %>%
        add_osm_feature(key = "amenity", value = "pub") %>%
        add_osm_feature(key = "name", value = "irish",
                        value_exact = FALSE, match_case = FALSE)

See
[`?available_features`](https://docs.ropensci.org/osmdata/reference/available_features.html)
and
[`?available_tags`](https://docs.ropensci.org/osmdata/reference/available_tags.html)
for further information.

### Data Formats

An overpass query constructed with the `opq()` and `add_osm_feature()`
functions is then sent to the [overpass
server](https://overpass-turbo.eu) to request data. These data may be
returned in a variety of formats, currently including:

1.  XML data (downloaded locally) via
    [`osmdata_xml()`](https://docs.ropensci.org/osmdata/reference/osmdata_xml.html);
2.  [Simple Features (sf)](https://cran.r-project.org/package=sf) format
    via
    [`osmdata_sf()`](https://docs.ropensci.org/osmdata/reference/osmdata_sf.html);
3.  [R Spatial (sp)](https://cran.r-project.org/package=sp) format via
    [`osmdata_sp()`](https://docs.ropensci.org/osmdata/reference/osmdata_sp.html);
    and
4.  [Silicate (SC)](https://github.com/hypertidy/silicate) format via
    [`osmdata_sc()`](https://docs.ropensci.org/osmdata/reference/osmdata_sc.html).

### Additional Functionality

Logical OR combinations can be implemented with the package’s internal
`c` method, so that the above example can be extended to all amenities
that are either restaurants OR pubs with

    pubs <- opq ("portsmouth usa") %>%
        add_osm_feature(key = "amenity", value = "pub") %>%
        osmdata_sf()
    restaurants <- opq ("portsmouth usa") %>%
        add_osm_feature(key = "amenity", value = "restaurant") %>%
        osmdata_sf()
    c (pubs, restaurants)

    #> Object of class 'osmdata' with:
    #>                  $bbox : 43.0135509,-70.8229994,43.0996118,-70.7279298
    #>         $overpass_call : The call submitted to the overpass API
    #>                  $meta : metadata including timestamp and version numbers
    #>            $osm_points : 'sf' Simple Features Collection with 325 points
    #>             $osm_lines : NULL
    #>          $osm_polygons : 'sf' Simple Features Collection with 24 polygons
    #>        $osm_multilines : NULL
    #>     $osm_multipolygons : NULL

Data may also be trimmed to within a defined polygonal shape with the
[`trim_osmdata()`](https://docs.ropensci.org/osmdata/reference/trim_osmdata.html)
function. Full package functionality is described on the
[website](https://docs.ropensci.org/osmdata/)

Citation
--------

    citation ("osmdata")
    #> 
    #> To cite osmdata in publications use:
    #> 
    #>   Mark Padgham, Bob Rudis, Robin Lovelace, Maëlle Salmon (2017).
    #>   osmdata Journal of Open Source Software, 2(14). URL
    #>   https://doi.org/10.21105/joss.00305
    #> 
    #> A BibTeX entry for LaTeX users is
    #> 
    #>   @Article{,
    #>     title = {osmdata},
    #>     author = {Mark Padgham and Bob Rudis and Robin Lovelace and Maëlle Salmon},
    #>     journal = {The Journal of Open Source Software},
    #>     year = {2017},
    #>     volume = {2},
    #>     number = {14},
    #>     month = {jun},
    #>     publisher = {The Open Journal},
    #>     url = {https://doi.org/10.21105/joss.00305},
    #>     doi = {10.21105/joss.00305},
    #>   }

Data licensing
--------------

All data that you access using `osmdata` is licensed under
[OpenStreetMap’s license, the Open Database
Licence](https://wiki.osmfoundation.org/wiki/Licence). Any derived data
and products must also carry the same licence. You should make sure you
understand that licence before publishing any derived datasets.

Code of Conduct
---------------

Please note that this project is released with a [Contributor Code of
Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree
to abide by its terms.

Contributors
------------


## Contributors


<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->

This project uses the [`allcontributor` package](https://github.com/mpadge/allcontributor) following the [all-contributors](https://allcontributors.org) specification. Contributions of any kind are welcome!

## Code

<table>

<tr>
<td align="center">
<a href="https://github.com/mpadge">
<img src="https://avatars1.githubusercontent.com/u/6697851?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=mpadge">mpadge</a>
</td>
<td align="center">
<a href="https://github.com/Robinlovelace">
<img src="https://avatars2.githubusercontent.com/u/1825120?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=Robinlovelace">Robinlovelace</a>
</td>
<td align="center">
<a href="https://github.com/hrbrmstr">
<img src="https://avatars2.githubusercontent.com/u/509878?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=hrbrmstr">hrbrmstr</a>
</td>
<td align="center">
<a href="https://github.com/virgesmith">
<img src="https://avatars3.githubusercontent.com/u/19323577?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=virgesmith">virgesmith</a>
</td>
<td align="center">
<a href="https://github.com/maelle">
<img src="https://avatars0.githubusercontent.com/u/8360597?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=maelle">maelle</a>
</td>
<td align="center">
<a href="https://github.com/espinielli">
<img src="https://avatars0.githubusercontent.com/u/891692?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=espinielli">espinielli</a>
</td>
<td align="center">
<a href="https://github.com/agila5">
<img src="https://avatars1.githubusercontent.com/u/22221146?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=agila5">agila5</a>
</td>
</tr>


<tr>
<td align="center">
<a href="https://github.com/jeroen">
<img src="https://avatars3.githubusercontent.com/u/216319?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=jeroen">jeroen</a>
</td>
<td align="center">
<a href="https://github.com/neogeomat">
<img src="https://avatars1.githubusercontent.com/u/2562658?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=neogeomat">neogeomat</a>
</td>
<td align="center">
<a href="https://github.com/angela-li">
<img src="https://avatars3.githubusercontent.com/u/15808896?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=angela-li">angela-li</a>
</td>
<td align="center">
<a href="https://github.com/Tazinho">
<img src="https://avatars1.githubusercontent.com/u/11295192?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=Tazinho">Tazinho</a>
</td>
<td align="center">
<a href="https://github.com/karpfen">
<img src="https://avatars3.githubusercontent.com/u/11758039?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=karpfen">karpfen</a>
</td>
<td align="center">
<a href="https://github.com/arfon">
<img src="https://avatars1.githubusercontent.com/u/4483?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=arfon">arfon</a>
</td>
<td align="center">
<a href="https://github.com/brry">
<img src="https://avatars0.githubusercontent.com/u/8860095?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=brry">brry</a>
</td>
</tr>


<tr>
<td align="center">
<a href="https://github.com/ccamara">
<img src="https://avatars1.githubusercontent.com/u/706549?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=ccamara">ccamara</a>
</td>
<td align="center">
<a href="https://github.com/danstowell">
<img src="https://avatars1.githubusercontent.com/u/202965?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=danstowell">danstowell</a>
</td>
<td align="center">
<a href="https://github.com/dpprdan">
<img src="https://avatars2.githubusercontent.com/u/1423562?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=dpprdan">dpprdan</a>
</td>
<td align="center">
<a href="https://github.com/JimShady">
<img src="https://avatars1.githubusercontent.com/u/2901470?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=JimShady">JimShady</a>
</td>
<td align="center">
<a href="https://github.com/karthik">
<img src="https://avatars2.githubusercontent.com/u/138494?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=karthik">karthik</a>
</td>
<td align="center">
<a href="https://github.com/MHenderson">
<img src="https://avatars0.githubusercontent.com/u/23988?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=MHenderson">MHenderson</a>
</td>
<td align="center">
<a href="https://github.com/patperu">
<img src="https://avatars0.githubusercontent.com/u/82020?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=patperu">patperu</a>
</td>
</tr>


<tr>
<td align="center">
<a href="https://github.com/stragu">
<img src="https://avatars0.githubusercontent.com/u/1747497?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=stragu">stragu</a>
</td>
<td align="center">
<a href="https://github.com/fzenoni">
<img src="https://avatars3.githubusercontent.com/u/6040873?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=fzenoni">fzenoni</a>
</td>
<td align="center">
<a href="https://github.com/rgzn">
<img src="https://avatars2.githubusercontent.com/u/1675905?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/commits?author=rgzn">rgzn</a>
</td>
</tr>

</table>


## Issue Authors

<table>

<tr>
<td align="center">
<a href="https://github.com/lbuk">
<img src="https://avatars2.githubusercontent.com/u/7860160?u=82d4376c97dbee9ec8bebd1ca0de3da8e5ddb300&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Albuk">lbuk</a>
</td>
<td align="center">
<a href="https://github.com/sckott">
<img src="https://avatars0.githubusercontent.com/u/577668?u=c54eb1ce08ff22365e094559a109a12437bdca40&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Asckott">sckott</a>
</td>
<td align="center">
<a href="https://github.com/prokulski">
<img src="https://avatars3.githubusercontent.com/u/19608488?u=cf3c1f9249688cd14fd04004efa67f4d9c67cf1e&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Aprokulski">prokulski</a>
</td>
<td align="center">
<a href="https://github.com/loreabad6">
<img src="https://avatars3.githubusercontent.com/u/10034237?u=53193bed2fad4f0808b55a227f99897a8d63ebc2&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Aloreabad6">loreabad6</a>
</td>
<td align="center">
<a href="https://github.com/waholulu">
<img src="https://avatars1.githubusercontent.com/u/2868000?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Awaholulu">waholulu</a>
</td>
<td align="center">
<a href="https://github.com/ibarraespinosa">
<img src="https://avatars0.githubusercontent.com/u/27447280?u=3f76b8aa4674890e136fbb15ea884c6d20e9b530&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Aibarraespinosa">ibarraespinosa</a>
</td>
<td align="center">
<a href="https://github.com/tbuckl">
<img src="https://avatars1.githubusercontent.com/u/98956?u=9580c2ee3c03cbbe44ac8180b0f6a6725b0415f0&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Atbuckl">tbuckl</a>
</td>
</tr>


<tr>
<td align="center">
<a href="https://github.com/morellek">
<img src="https://avatars2.githubusercontent.com/u/38642291?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Amorellek">morellek</a>
</td>
<td align="center">
<a href="https://github.com/mdsumner">
<img src="https://avatars1.githubusercontent.com/u/4107631?u=c7a3627c592123651d51d002f421c2bd00be172f&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Amdsumner">mdsumner</a>
</td>
<td align="center">
<a href="https://github.com/michielvandijk">
<img src="https://avatars0.githubusercontent.com/u/5227806?u=956e61310e9c7ee08749ddb95458c571eafa76e3&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Amichielvandijk">michielvandijk</a>
</td>
<td align="center">
<a href="https://github.com/SymbolixAU">
<img src="https://avatars2.githubusercontent.com/u/18344164?u=022e0d3bdcca3e224021bae842672bda12b599df&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3ASymbolixAU">SymbolixAU</a>
</td>
<td align="center">
<a href="https://github.com/Dris101">
<img src="https://avatars2.githubusercontent.com/u/11404162?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3ADris101">Dris101</a>
</td>
<td align="center">
<a href="https://github.com/slow-data">
<img src="https://avatars2.githubusercontent.com/u/20839947?u=436db5fe0fff455c09d436b4a36e67232fa63c5b&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Aslow-data">slow-data</a>
</td>
<td align="center">
<a href="https://github.com/mroorda">
<img src="https://avatars1.githubusercontent.com/u/41475296?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Amroorda">mroorda</a>
</td>
</tr>


<tr>
<td align="center">
<a href="https://github.com/MiKatt">
<img src="https://avatars1.githubusercontent.com/u/19970683?u=1d21f231f6c2b14ce65c740014612d5e1e2ff080&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3AMiKatt">MiKatt</a>
</td>
<td align="center">
<a href="https://github.com/alanlzl">
<img src="https://avatars0.githubusercontent.com/u/15748113?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Aalanlzl">alanlzl</a>
</td>
<td align="center">
<a href="https://github.com/PublicHealthDataGeek">
<img src="https://avatars1.githubusercontent.com/u/43342160?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3APublicHealthDataGeek">PublicHealthDataGeek</a>
</td>
<td align="center">
<a href="https://github.com/TomBor">
<img src="https://avatars1.githubusercontent.com/u/8322713?u=bf72198850753d4eb709b2b17d89b4afa68936a1&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3ATomBor">TomBor</a>
</td>
<td align="center">
<a href="https://github.com/mgageo">
<img src="https://avatars0.githubusercontent.com/u/2681495?u=a98e4f2bcb64aa79f87f9e16029c8a0d3cd69768&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Amgageo">mgageo</a>
</td>
<td align="center">
<a href="https://github.com/polettif">
<img src="https://avatars3.githubusercontent.com/u/17431069?u=757eac2821736acbb02e7c90b456411d256d5780&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Apolettif">polettif</a>
</td>
<td align="center">
<a href="https://github.com/edzer">
<img src="https://avatars0.githubusercontent.com/u/520851?u=9bc892c3523be428dc211f2ccbcf04e8e0e564ff&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Aedzer">edzer</a>
</td>
</tr>


<tr>
<td align="center">
<a href="https://github.com/marcusyoung">
<img src="https://avatars2.githubusercontent.com/u/10391966?u=0a04c8fedb59cd34404dabc66979bf91c4a1978c&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Amarcusyoung">marcusyoung</a>
</td>
<td align="center">
<a href="https://github.com/barryrowlingson">
<img src="https://avatars0.githubusercontent.com/u/888980?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Abarryrowlingson">barryrowlingson</a>
</td>
<td align="center">
<a href="https://github.com/ChrisWoodsSays">
<img src="https://avatars3.githubusercontent.com/u/42043980?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3AChrisWoodsSays">ChrisWoodsSays</a>
</td>
<td align="center">
<a href="https://github.com/daluna1">
<img src="https://avatars3.githubusercontent.com/u/60740817?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Adaluna1">daluna1</a>
</td>
<td align="center">
<a href="https://github.com/khzannat26">
<img src="https://avatars3.githubusercontent.com/u/63047666?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Akhzannat26">khzannat26</a>
</td>
<td align="center">
<a href="https://github.com/gdkrmr">
<img src="https://avatars1.githubusercontent.com/u/12512930?u=75e643ebcbe5e613fe9eeff8e2cf749d43ead9ea&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Agdkrmr">gdkrmr</a>
</td>
<td align="center">
<a href="https://github.com/dipenpatel235">
<img src="https://avatars0.githubusercontent.com/u/8135097?u=57ce3616c4b1eb8928d0eb049d58866f7990e43c&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Adipenpatel235">dipenpatel235</a>
</td>
</tr>


<tr>
<td align="center">
<a href="https://github.com/matkoniecz">
<img src="https://avatars2.githubusercontent.com/u/899988?u=1a682cd39f51bb0224a52c7640a040c849b73ae8&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Amatkoniecz">matkoniecz</a>
</td>
<td align="center">
<a href="https://github.com/robitalec">
<img src="https://avatars3.githubusercontent.com/u/16324625?u=a7a98d4e17a14bf97383a5059ef4a079e15438d7&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Arobitalec">robitalec</a>
</td>
<td align="center">
<a href="https://github.com/nfruehADA">
<img src="https://avatars2.githubusercontent.com/u/69671715?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3AnfruehADA">nfruehADA</a>
</td>
<td align="center">
<a href="https://github.com/orlandoandradeb">
<img src="https://avatars0.githubusercontent.com/u/48104481?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+author%3Aorlandoandradeb">orlandoandradeb</a>
</td>
</tr>

</table>


## Issue Contributors

<table>

<tr>
<td align="center">
<a href="https://github.com/nsfinkelstein">
<img src="https://avatars1.githubusercontent.com/u/2919482?u=eb162d42c4563f2cef29a6eef1d8e9e28862242d&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Ansfinkelstein">nsfinkelstein</a>
</td>
<td align="center">
<a href="https://github.com/gawbul">
<img src="https://avatars3.githubusercontent.com/u/321291?u=56cf9ff94bf27ed9a5c1e6734629ce9da7969e3e&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Agawbul">gawbul</a>
</td>
<td align="center">
<a href="https://github.com/sytpp">
<img src="https://avatars1.githubusercontent.com/u/8035937?u=8efe7a4f4c3088bb35974e7488950c25658693ae&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Asytpp">sytpp</a>
</td>
<td align="center">
<a href="https://github.com/MAnalytics">
<img src="https://avatars1.githubusercontent.com/u/27354347?u=47f4c742c95c72b88a07ac1cb6406c9e1d186a54&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3AMAnalytics">MAnalytics</a>
</td>
<td align="center">
<a href="https://github.com/niklaas">
<img src="https://avatars1.githubusercontent.com/u/705637?u=49c24f75feb39718a9082a8e2f8b2010c8ac5127&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Aniklaas">niklaas</a>
</td>
<td align="center">
<a href="https://github.com/RoyalTS">
<img src="https://avatars0.githubusercontent.com/u/702580?u=e7d21835a6f7ba3a2f1ea7a573266708d62b1af7&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3ARoyalTS">RoyalTS</a>
</td>
<td align="center">
<a href="https://github.com/lrob">
<img src="https://avatars0.githubusercontent.com/u/1830221?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Alrob">lrob</a>
</td>
</tr>


<tr>
<td align="center">
<a href="https://github.com/mem48">
<img src="https://avatars1.githubusercontent.com/u/15819577?u=4a4078aff5fa01d9ef82b5a504c3068d3ad21f0d&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Amem48">mem48</a>
</td>
<td align="center">
<a href="https://github.com/richardellison">
<img src="https://avatars0.githubusercontent.com/u/10625733?u=8d7cd55a61f1a1b3f9973ddff5adbb45e0b193c6&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Arichardellison">richardellison</a>
</td>
<td align="center">
<a href="https://github.com/cboettig">
<img src="https://avatars3.githubusercontent.com/u/222586?u=dfbe54d3b4d538dc2a8c276bb5545fdf4684752f&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Acboettig">cboettig</a>
</td>
<td align="center">
<a href="https://github.com/beingalink">
<img src="https://avatars0.githubusercontent.com/u/871741?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Abeingalink">beingalink</a>
</td>
<td align="center">
<a href="https://github.com/prise6">
<img src="https://avatars3.githubusercontent.com/u/6558161?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Aprise6">prise6</a>
</td>
<td align="center">
<a href="https://github.com/yaakovfeldman">
<img src="https://avatars0.githubusercontent.com/u/17687145?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Ayaakovfeldman">yaakovfeldman</a>
</td>
<td align="center">
<a href="https://github.com/gregor-d">
<img src="https://avatars2.githubusercontent.com/u/33283245?u=3d70f9d18b0be2c20cf08a9c7d51353797d61208&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Agregor-d">gregor-d</a>
</td>
</tr>


<tr>
<td align="center">
<a href="https://github.com/gregmacfarlane">
<img src="https://avatars3.githubusercontent.com/u/2234830?u=954f7029df0417634df181e7a27c5e163ebc8c6d&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Agregmacfarlane">gregmacfarlane</a>
</td>
<td align="center">
<a href="https://github.com/legengliu">
<img src="https://avatars0.githubusercontent.com/u/7606454?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Alegengliu">legengliu</a>
</td>
<td align="center">
<a href="https://github.com/PaoloFrac">
<img src="https://avatars3.githubusercontent.com/u/38490683?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3APaoloFrac">PaoloFrac</a>
</td>
<td align="center">
<a href="https://github.com/mtennekes">
<img src="https://avatars3.githubusercontent.com/u/2444081?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ropensci/osmdata/issues?q=is%3Aissue+commenter%3Amtennekes">mtennekes</a>
</td>
</tr>

</table>

<!-- markdownlint-enable -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->


[![ropensci\_footer](https://ropensci.org/public_images/github_footer.png)](https://ropensci.org)
