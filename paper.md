---
title: osmdata
tags:
    - openstreetmap
    - spatial
    - R
    - Simple Features
authors:
    - name: Mark Padgham
      affiliation: 1
    - name: Robin Lovelace
      affiliation: 3
    - name: Maëlle Salmon
      affiliation: 2
    - name: Bob Rudis
      affiliation: 4
affiliations:
    - name: Department of Geoinformatics, University of Salzburg, Austria
      index: 1
    - name: ISGlobal, Centre for Research in Environmental Epidemiology,Universitat Pompeu Fabra, CIBER Epidemiología y Salud Pública, Barcelona, Spain.
      index: 2
    - name: Institute of Transport Studies, University of Leeds, U.K.
      index: 3
    - name: Rapid7
      index: 4
date: 8 March 2017
bibliography: vignettes/osmdata-refs.bib
nocite: |
  @*
---

# Summary

`osmdata` imports OpenStreetMap (OSM) data into R as either Simple Features or
`R` Spatial objects, respectively able to be processed with the R packages `sf`
and `sp`.  OSM data are extracted from the Overpass API and processed with very
fast C++ routines for return to R.  The package enables simple Overpass queries
to be constructed without the user necessarily understanding the syntax of the
Overpass query language, while retaining the ability to handle arbitrarily
complex queries. Functions are also provided to enable recursive searching
between different kinds of OSM data (for example, to find all lines which
intersect a given point). The package is faster than current alternatives for importing 
OSM data into R and is the only one compatible with `sf`.

# References
