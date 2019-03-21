# CRAN notes for osmdata_0.0.10 submission

Note that one of the vignettes currently generates several NOTEs about "libcurl error code 7: failed to connect to www.opengeospatial.org". As the time of this submission, this website appears to be down, but I hope we may confidently assume the problem will be rectified as soon as possible.

## Test environments

Other than the above, this submission generates NO notes on:
* Linux (via Travis-ci): R-release, R-devel, R-oldrelease
* OSX (via Travis-ci): R-release
* Windows Visual Studio 2015 x64 (via appveyor)
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using `Clang++ -Weverything`, and both local memory sanitzer and `rocker/r-devel-san` with clean results.
