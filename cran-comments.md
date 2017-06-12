# CRAN notes for osmdata_0.0.2 submission

The errors on some windows machines previously discussed with Brian Ripley were
due to me failing to properly check the `_R_CHECK_CRAN_INCOMING_` environment
variable which led to these machines running tests in a different way than
intended.

I now have
```
is_cran <- identical (Sys.getenv ("_R_CHECK_CRAN_INCOMING_"), 'true')
```
and skip the previously offending parts of tests if `is_cran` is TRUE.

Additional notes regarding possibly invalid URL in one man/ entry and possibly
mis-spelled word in DESCRIPTION have also been resolved.

## Test environments

This submission generates NO notes on:
* Linux (via Travis-ci): R-release, R-devl
* OSX (via Travis-ci): R-release
* Windows Visual Studio 2015 x64 (via appveyor)
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using both local memory sanitzer and `rocker/r-devel-san`
with clean results. 
