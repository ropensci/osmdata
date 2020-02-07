# CRAN notes for osmdata_0.1.3 submission

This submission rectifies the issue identified in recent CRAN email regarding "..." arguments "not in \usage"

One NOTE is generated on some systems regarding installed size, which is unavoidable due to very large C++ code base.

## Test environments

Other than the above, this submission generates NO notes on:
* Linux (via Travis-ci): R-release, R-devel, R-oldrelease
* OSX (via Travis-ci): R-release
* Windows Visual Studio 2015 x64 (via appveyor)
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using `Clang++ -Weverything`, and both local memory sanitzer and `rocker/r-devel-san` with clean results.
