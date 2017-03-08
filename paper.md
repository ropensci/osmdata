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
      affiliation: 2
    - name: Maëlle Salmon
      affiliation: 3
affiliations:
    - name: Department of Geoinformatics, University of Salzburg, Austria
      index: 1
    - name: Institute of Transport Studies, University of Leeds, U.K.
      index: 2
    - name: Centre for Research in Environmental Epidemiology, Universitat Pompeu Fabra, Spain
date: 8 March 2017
bibliography: vignettes/osmdata-refs.bib
---

# Summary

`osmdata` imports OpenStreetMap (OSM) data into R as either Simple Features or
`R` Spatial objects, respectively able to be processed with the R packages `sf`
and `sp`.  OSM data are extracted from the overpass API and processed with very
fast C++ routines for return to R.  The package enables simple overpass queries
to be constructed without the user necessarily understanding the syntax of the
overpass query language, while retaining the ability to handle arbitrarily
complex queries. Functions are also provided to enable recursive searching
between different kinds of OSM data (for example, to find all lines which
intersect a given point).

# References

(see bibliography)
