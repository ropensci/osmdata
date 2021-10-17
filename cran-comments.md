# CRAN notes for osmdata_0.1.8 submission

This submission fixes some check failures on previous version. These were due to external calls in vignettes which have now been switched off, and so will no longer fail.

## Test environments

This submission generates NO notes on:

* Linux (via github actions): R-release, R-oldrelease
* Windows (via github actions): R-release, R-oldrelease, R-devel
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using `Clang++ -Weverything and local memory sanitzer with clean results.
