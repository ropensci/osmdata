# CRAN notes for osmdata_0.0.3 submission

Previous fails were due to running full tests instead of CRAN-restricted set.
Full tests are now only run for particular environment variables that will not
exist on CRAN.

## Test environments

This submission generates NO notes on:
* Linux (via Travis-ci): R-release, R-devl
* OSX (via Travis-ci): R-release
* Windows Visual Studio 2015 x64 (via appveyor)
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using both local memory sanitzer and `rocker/r-devel-san`
with clean results. 
