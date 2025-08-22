# CRAN notes for osmdata_0.3.0 submission

This submission updates some example code to include the native pipe and bump dependencies to R >= 4.1.
Updates where possible and deprecates functions using sp package and update the use of raster functions to terra.
Joan Maspons will be the package mantainer as Mark Padgham communicate to CRAN in a recent mail.

## Test environments

This submission generates NO notes on:

* Linux (via github actions): R-release, R-oldrelease, R-devel
* Windows (via github actions): R-release
* MacOS (via github actions): R-release
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using `Clang++ -Weverything and local memory sanitzer with clean results.

## revdepcheck results

We checked 13 reverse dependencies (0 from CRAN + 13 from Bioconductor), comparing R CMD check results across CRAN and dev versions of this package.

 * We saw 0 new problems
 * We failed to check 0 packages
