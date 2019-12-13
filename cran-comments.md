# CRAN notes for osmdata_0.1.2 submission

This submission rectifies the three previous issues identified in recent CRAN emails:

1. All URLs now fully specified with protocol.
2. The 'class(obj)=="matrix"' calls have been rectified to ensure return values of 'c("matrix","array")' are anticipated.
3. Previously unreliable http calls performed during testing are now all mocked, so testing on CRAN should perform no actual calls at all.

Other than that, only NOTE generated on some systems regards installed size, which is unavoidable due to very large C++ code base.

## Test environments

Other than the above, this submission generates NO notes on:
* Linux (via Travis-ci): R-release, R-devel, R-oldrelease
* OSX (via Travis-ci): R-release
* Windows Visual Studio 2015 x64 (via appveyor)
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using `Clang++ -Weverything`, and both local memory sanitzer and `rocker/r-devel-san` with clean results.
