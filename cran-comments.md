# CRAN notes for osmdata_0.0.3 submission

The two remaining test fails were due to me failing to omit the last remaining
offending line of tests. This has now been rectified, and all tests really
should always pass from here on.

## Test environments

This submission generates NO notes on:
* Linux (via Travis-ci): R-release, R-devl
* OSX (via Travis-ci): R-release
* Windows Visual Studio 2015 x64 (via appveyor)
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using both local memory sanitzer and `rocker/r-devel-san`
with clean results. 
