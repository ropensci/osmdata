# CRAN notes for osmdata_0.1.5 submission

CRAN win-builder generates one note on some systems regarding a possibly valid URL at https://overpass-api.de/api/interpreter/, because of a tlsvl alert protocol version. The associated URL is valid, but can not be queried with an empty body, which is perhaps the reason your CRAN tests generate this note?

## Test environments

Other than the above, this submission generates NO notes on:
* Linux (via github actions): R-release, R-oldrelease
* Windows (via github actions): R-release, R-oldrelease, R-devel
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using `Clang++ -Weverything`, and both local memory sanitzer and `rocker/r-devel-san` with clean results.
