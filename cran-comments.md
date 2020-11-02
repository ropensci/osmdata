# CRAN notes for osmdata_0.1.4 submission

This package fixes URL redirects. Please note that this includes complying with instructions from a previous submission to redirect http://srtm.csi.cgiar.org/ to https, even though the https server very frequently times out and returns an error. This error can only be avoided through reverting to https, against your prior instructions.

The submission also fixes an intermittent error in previous version which called an occasionally unreliable URL in one example. That call has now been \dontrun{}.

One NOTE is generated on some systems regarding installed size, which is unavoidable due to very large C++ code base.

## Test environments

Other than the above, this submission generates NO notes on:
* Linux (via Travis-ci): R-release, R-devel, R-oldrelease
* OSX (via Travis-ci): R-release
* Windows Visual Studio 2015 x64 (via appveyor)
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using `Clang++ -Weverything`, and both local memory sanitzer and `rocker/r-devel-san` with clean results.
