0.0.5.99
===================
- Add `timeout` and `memsize` options to `opq()` to improve handling large
  queries.
- Fix minor yet important C++ code lines that prevented package being used as
  dependency by other packages on some systems

0.0.5
===================
- Add extraction of bounding polygons with `getbb (..., format_out = "polygon")`
- Add `trim_osmdata` function to trim an `osmdata` object to within a bounding
  polygon (thanks @sytpp)
- Add `unique_osmdata` function which reduces each component of an `osmdata`
  object only to unique elements (so `$osm_points`, for example, only contains
  points that are not represented in other - line, polygon, whatever -
  objects).
- Rename `add_feature` to `add_osm_feature` (and deprecate old version)


0.0.4
===================
- Enable alternative overpass API services through `get_overpass_url()` and
  `set_overpass_url()` functions
- Extend and improve vignette

0.0.3
===================
- Change tests only, no functional difference

0.0.2
===================
- Rename function `opq_to_string()` to `opq_string()`

0.0.1 (19 May 2017)
===================
- Remove configure and Makevars files
- Fix tests

0.0.0 (18 May 2017)
===================
- Initial CRAN release
