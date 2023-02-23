# CRAN notes for osmdata_0.2.1 submission

This submission fixes the two valgrind memleak errors from the previous submission. Both the uninitialised variable and possible memory leak errors were able to be precisely reproduced and fixed in this submission.

## Test environments

This submission generates NO notes on:

* Linux (via github actions): R-release, R-oldrelease
* Windows (via github actions): R-release, R-oldrelease, R-devel
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using `Clang++ -Weverything and local memory sanitzer with clean results.
