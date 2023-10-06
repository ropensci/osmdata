
0.2.5.00x (dev version)
===================

## Major changes

- Implemented `c.osmdata_sc` method to join `osmdata_sc` objects (#333)


0.2.5
===================

## Major changes

- v0.2.4 was removed without notice from CRAN because of #329; this is a rapid re-submission

0.2.4
===================

## Minor changes

- Bug fix to stop getbb call to Nominatim returning 405 error (#328)


0.2.3
===================

## Minor changes

- Fix failing test due to changes to 'sp' moving towards deprecation.


0.2.2
===================

## Major changes:

- `osmdata_data_frame` adds columns `osm_center_lat` and `osm_center_lon` for `out * center;` queries (#316, #319).
- Add parameters from `opq` to `opq_osm_id`: out, datetime, datetime2, adiff, timeout and memsize (#320)
- Fix `available_tags()` function which no longer worked (#322 thanks to @boiled-data)
- Implement `out:csv` queries (#321).

## Minor changes

- Fix queries with `!match_case` and only one value (#317).
- Fix queries with multiple features & multiple osm_types (#318).

0.2.1
===================

## Major changes:

- Very soft deprecation of `nodes_only` parameter in `opq` (#308, #312).

## Minor changes

- Couple of minor memory leak bug fixes in `osmdata_data_frame` C++ code.

0.2.0
===================

This release welcomes a new package author @jmaspons. The lists of changes here gives an overview of the amazing work he has contributed to this new major version.

## Major changes:

- New `osmdata_data_frame()` function to return non-spatial `data.frame` structures directly from overpass; thanks to @jmaspons (#285).
- Improved `add_osm_features` so that key-values pairs can be submitted as a list, rather than escape-delimited character strings; thanks to @elipousson (#277, #278).
- `opq()` can now utilise overpass ability to filter results by area; thanks to @jmaspons (#286).
- `opq()` now has additional "out" parameter to control the kinds of data returned by overpass; thanks to @jmaspons (#288).
- `opq()` now has additional "osm_types" parameter to provide finer control of which kinds of data are returned by overpass; thanks to @jmaspons (#295).
- Fix key modifications for non-valid column names and handle duplicated column names in `osmdata_*` functions; by @jmaspons (#303)
- @elipousson is new package contributor, thanks to the above work.
- @jmaspons is new package author, thanks to #285 (plus most of the above, and a whole lot more!)

## Minor changes:

- Downgraded `sp` from "Imports" to "Suggests"; thanks to @jmaspons (#302)
- Improved `osm_osm_id()` to accept vectors of ids and types; thanks to @jmaspons (#268, #282, #283)
- "get-osmdata.R" file now split into several smaller and more manageable files (#306, thanks to @jmaspons)

0.1.10
===================

## Major changes:

- Changed httr dependency for httr2 (#272)
- Removed two authors of code formerly including for stubbing results; which is now done via `httptest2` package.

## Minor changes:

- Moved jsonlite from Imports to Suggests (now only used in tests).

0.1.9
===================

## Major changes:

- New function `opq_around` to query features within a specified radius
  *around* a defined location; thanks to @barryrowlingson via #199 and
  @maellecoursonnais via #238
- New vignette on splitting large queries thanks to @Machin6 (via #262)

## Minor changes:

- New dependency on `reproj` package, so that `trim_osmdata()` can be applied
  to re-projected coordinates.

0.1.8
===================

## Minor changes:

- Fix some failing CRAN checks (no change to functionality)


0.1.7
===================

## Minor changes:

- `add_osm_feature` bug fix to revert AND behaviour (#240 thanks to @anthonynorth)

0.1.6
===================

## Major changes:

- New function `add_osm_features` to enable OR-combinations of features in
  single queries.

0.1.5
===================

## Minor changes:

- Bug fix in `getbb()` via #232, thanks to @changwoo-lee
- hard-code WKT string for EPSG:4326, to avoid obsolete proj4strings (#218)
- bug fix in `print` method via #236; thanks to @odeleongt 

0.1.4
===================

## Major changes:

- New `osm_enclosing()` function; thanks to @barryrowlingson via #199
- `opq()` now has additional `datetime` and `datetime2` parameters which can be
  used to extract historical data prior to `datetime`, or differences between
  two datetimes by specifying `datetime2`; thanks to @neogeomat for the idea in
  issue#179.
- opq() also has additional `nodes_only` parameter to return nodes as points
  only, for efficient extraction of strictly point-based OSM data; thanks to
  @gdkrmr for the idea in issue#221.

## Minor changes:

- New contributor Enrico Spinielli (@espinielli), via #207, #210, #211, #212 - Thanks!


0.1.3
===================

## Major changes:

- `osmdata_pbf` function removed as the overpass server no longer provides the
  experimental API for pbf-format data.
- Remove deprecated `add_feature()` function; entirely replaced by
  `add_osm_feature()`.
- `get_bb()` with polygon output formats now returns ALL polygon and
  multipolygon objects by default (issue#195)

## Minor changes:

- New Contributors: Andrea Gilardi (@agila5)
- Bug fix for issue#205

0.1.2
===================

## Major changes:

- New function `unname_osmdata_sf`, to remove row names from `sf`-format
  geometry objects that may cause issues with some plotting routines such as
  leaflet.

## Minor changes:

- `getbb` now allows arbitrary `featuretype` specification, no longer just
  those pertaining to settlement forms.
- available_tags returns tags with underscore precisely as required for
  `add_osm_feature` - previous version returned text values with spaces instead
  of underscore.
- Fix bug in `osmdata_sf` for data with no names and/or no key-val pairs
- Fix bug in `trim_osmdata` for multi\* objects; thanks to @stragu
- Implement `trim_osmdata.sc` method
- retry httr calls to nominatim, which has lately been timing out quite often

0.1.1
===================

## Minor changes:

- bug fix in `trim_osmdata` function

0.1.0
===================

## Major changes:

- New function, `osm_elevation` to insert elevation data into `SC`-format data
  returned by `osmdata_sc` function.
- New vignette on `osmdata_sc` function and elevation data.
- `opq()` function now accepts polygonal bounding boxes generated with
  `getbb(..., format_out = "polygon")`.

0.0.10
===================

## Minor changes:

- Bug fix for vectorized lists of values in `add_osm_feature`, so only listed
  items are returns (see #139; thanks @loreabad6)
- But fix to ensure all `sf` `data.frame` objects have `stringsAsFactors =
  FALSE`

0.0.9
===================

## Major changes:

- New function `osmdata_sc` to return data in `silicate::SC` format (see
  github.com/hypertidy/silicate; this also requires additional dependency on
  `tibble`)
- Structure of `osmdata` object modified to replace former `$timestamp` field
  with `$meta` field containing a list of `$timestamp`, `$OSM_version`
  (currently 0.6), and `$overpass_version`.
- add_osm_feature() now accepts vectors of multiple values (see #139).
- osmdata_sf() objects default to character vectors, not factors (see #44).

## Minor changes:

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
