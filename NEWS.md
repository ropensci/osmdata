0.1.0
===================

Major changes:
- New function, `osm_elevation` to insert elevation data into `SC`-format data
  returned by `osmdata_sc` function.
- New vignette on `osmdata_sc` function and elevation data.
- `opq()` function now accepts polygonal bounding boxes generated with
  `getbb(..., format_out = "polygon")`.

0.0.10
===================

Minor changes:
- Bux fix for vectorized lists of values in `add_osm_feature`, so only listed
  items are returns (see #139; thanks @loreabad6)
- But fix to ensure all `sf` `data.frame` objects have `stringsAsFactors =
  FALSE`

0.0.9
===================
Major changes:
- New function `osmdata_sc` to return data in `silicate::SC` format (see
  github.com/hypertidy/silicate; this also requires additional dependency on
  `tibble`)
- Structure of `osmdata` object modified to replace former `$timestamp` field
  with `$meta` field containing a list of `$timestamp`, `$OSM_version`
  (currently 0.6), and `$overpass_version`.
- add_osm_feature() now accepts vectors of multiple values (see #139).
- osmdata_sf() objects default to character vectors, not factors (see #44).

Minor changes:
- vignette updated
- Overpass URL now randomly selected from the four primary servers (see
  https://wiki.openstreetmap.org/wiki/Overpass_API#Public_Overpass_API_instances),
  thanks to @JimShady.
- bug fix for osmdata_sp() (see #56)
- osmdata_sp() fixed to return osm_id values (see #131; thanks @JimShady).

0.0.8
===================
- Fix bug in `trim_osmdata` so that all sf attributes are reinstated, and also
  issue message that sf-preload is necessary for this function
- Fix bug with opq (key_exact = FALSE) so value_exact is always also set to
  FALSE

0.0.7
===================
- Fix bug in `c` method so it works when `sf` not loaded
- Fix bug in overpass query syntax to match new QL requirements

0.0.6
===================
- Add new function 'osm_poly2line()' to coerce the 'osmdata$odm_polygons' object
  for 'osmdata_sf' objects to lines, and append to 'osmdata$osm_lnes'. This is
  important for street networks ('add_osm_objects (key = "highway")'), which are
  otherwise separated between these two components. 
- Add new function `opq_osm_id` to query by OSM identifier alone
- Add `timeout` and `memsize` options to `opq()` to improve handling large
  queries.
- Return useful information from overpass server when it returns neither error
  nor useful data
- Make C++ code interruptible so long processing can be cancelled
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
