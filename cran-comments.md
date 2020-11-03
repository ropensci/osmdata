# CRAN notes for osmdata_0.1.4 submission

This submission attempts to once again fix URL redirects. Please note that a previous attempt to submit this version complied with instructions to redirect http://srtm.csi.cgiar.org/ to https, but the https server generally times out and errors. This submission reverts all of those URLs to "http" and not "https". Even then, the server is very slow, and may not respond to automated status queries. This URL is nevertheless only given in documentation, and not directly called by any functions within the package. Slowness or errors in responding to this URL thus do not affect package functionality in any way.

The submission also fixes an intermittent error in previous version which called an occasionally unreliable URL in one example. That call has now been \dontrun{}.

One NOTE is generated on some systems regarding installed size, which is unavoidable due to very large C++ code base.

## Test environments

Other than the above, this submission generates NO notes on:
* Linux (via Travis-ci): R-release, R-devel, R-oldrelease
* OSX (via Travis-ci): R-release
* Windows Visual Studio 2015 x64 (via appveyor)
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using `Clang++ -Weverything`, and both local memory sanitzer and `rocker/r-devel-san` with clean results.
