#include <Rcpp.h>

//' rcpp_test_points
//'
//' Reproduces code used in src/osmdata.cpp to compare Rcpp construction in
//' osmdata with equivalent construction in sf. The results of 'sf::st_read()'
//' can not be directly compared with the results of 'omsdata', because GDAL does
//' not return all key-value pairs, whereas 'osmdata' does, and the two will never
//' be identical. The 'Rcpp' construction of 'sf' objects can thus only be checked
//' in highly simplified examples like this. This function is only used in
//' 'tests/testthat/test-sf-rcpp.R'.
//'
//' @return An sf Simple Features Collection object
// [[Rcpp::export]]
Rcpp::List rcpp_test_points () {
    Rcpp::List crs = Rcpp::List::create (NA_INTEGER, 
            Rcpp::CharacterVector::create (NA_STRING));
    crs.attr ("class") = "crs";
    crs.attr ("names") = Rcpp::CharacterVector::create ("epsg", "proj4string");

    std::vector <std::string> names;
    names.push_back ("xmin");
    names.push_back ("ymin");
    names.push_back ("xmax");
    names.push_back ("ymax");
    Rcpp::NumericVector bbox (4, NA_REAL);
    bbox (0) = 1;
    bbox (1) = 2;
    bbox (2) = 3;
    bbox (3) = 4;
    bbox.attr ("names") = names;

    Rcpp::List pointList (2);
    std::vector <std::string> ptnames;
    ptnames.reserve (2);

    Rcpp::CharacterVector ptnms = Rcpp::CharacterVector::create ("a", "b");

    for (int i=0; i<2; i++)
    {
        Rcpp::NumericVector ptxy = Rcpp::NumericVector::create (NA_REAL, NA_REAL);
        ptxy.attr ("class") = Rcpp::CharacterVector::create ("XY", "POINT", "sfg");
        ptxy [0] = 2 * i + 1;
        ptxy [1] = 2 * i + 2;
        pointList (i) = ptxy;
    }

    pointList.attr ("names") = ptnms;
    pointList.attr ("n_empty") = 0;
    pointList.attr ("class") = Rcpp::CharacterVector::create ("sfc_POINT", "sfc");
    pointList.attr ("precision") = 0.0;
    pointList.attr ("bbox") = bbox;
    pointList.attr ("crs") = crs;
    return pointList;
}
