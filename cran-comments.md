# CRAN notes for osmdata_0.2.5 submission

The previous submission was removed from CRAN shortly after submission without any notice or consultation. The reason was because of a "pragma" warning-suppression statement in one C++ file which has been in that state throughout the entire package history. This submission removes that statement, resulting in the package now issuing around 20 compiler warnings. Absent any public reference from CRAN of which classes of warnings may or may not be acceptable, I trust these warnings will be ignored.

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
