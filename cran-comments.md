# CRAN notes for osmdata_0.4.1 submission

Patch release to remove failing servers from the default options and checks to ensure the selected server works + bug fix.


## Test environments

This submission generates NO notes on:

* Linux (via github actions): R-release, R-oldrelease, R-devel
* Windows (via github actions): R-release
* MacOS (via github actions): R-release
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using:
rhub::rhub_check(platform = c("m1-san", "clang-asan", "clang-ubsan", "gcc-asan", "rchk", "valgrind"))

Platforms "clang-asan", "clang-ubsan", "rchk", "valgrind" fail with errors in dependencies (terra, libudunits2)
See https://github.com/ropensci/osmdata/actions/runs/33199908632 for details.
