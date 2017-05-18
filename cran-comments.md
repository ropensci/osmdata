# Test environments

* Ubuntu 12.04 (on `travis-ci`): R-release, R-devel
* Windows Visual Studio 2015 (on `appveyor`; `x64`)
* win-builder (R-release, R-devel, R-oldrelease)

# R CMD check results

0 errors | 0 warnings | 1 note
checking installed package size ... NOTE
* installed size is  7.2Mb
    sub-directories of 1Mb or more:
        doc    2.8Mb
        libs   4.3Mb
            
Large size primarily due to libs, which is unavoidable due in turn to extensive
C++ routines
