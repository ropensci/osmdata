# CRAN notes for osmdata_0.0.6 submission

Passes all tests on the listed test environments. Generates the single note regarding large package size which is unavoidable due to internally-bundled C++ libraries.

## Test environments

Other than the above, this submission generates NO notes on:
* Linux (via Travis-ci): R-release, R-devel, R-oldrelease
* OSX (via Travis-ci): R-release
* Windows Visual Studio 2015 x64 (via appveyor)
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using `Clang++ -Weverything`, and both local memory sanitzer and `rocker/r-devel-san` with clean results.
