# CRAN notes for osmdata_0.2.6 submission

This submission updates some example code to include the native pipe. This is only done within '\dontrun' blocks, and so the 'DESCRIPTION' file has no minimum R version requirement. Vignettes also demonstrate use of native pipe within non-executed code blocks.

## Test environments

This submission generates NO notes on:

* Linux (via github actions): R-release, R-oldrelease, R-devel
* Windows (via github actions): R-release
* MacOS (via github actions): R-release
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using `Clang++ -Weverything and local memory sanitzer with clean results.

## revdepcheck results

We checked 9 reverse dependencies (0 from CRAN + 9 from Bioconductor), comparing R CMD check results across CRAN and dev versions of this package.

 * We saw 0 new problems
 * We failed to check 0 packages
