/***************************************************************************
 *  Project:    osmdata
 *  File:       sf-tests.cpp
 *  Language:   C++
 *
 *  osmdata is free software: you can redistribute it and/or modify it under
 *  the terms of the GNU General Public License as published by the Free
 *  Software Foundation, either version 3 of the License, or (at your option)
 *  any later version.
 *
 *  osmdata is distributed in the hope that it will be useful, but WITHOUT ANY
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 *  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 *  details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  osm-router.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Author:     Mark Padgham / Andrew Smith
 *  E-Mail:     mark.padgham@email.com / andrew@casacazaz.net
 *
 *  Description:    Functions only used in tests/testthat/test-sf-rcpp.R to
 *                  compare construction of 'sf' objects in 'osmdata' with
 *                  equivalent objects constructed using 'sf'.  These functions
 *                  are necessary because the results of 'sf::st_read()' can not
 *                  be directly compared with the output of 'omsdata', because
 *                  GDAL does not return all key-value pairs, whereas 'osmdata'
 *                  does, and the two will never be identical.
 *
 *  Limitations:
 *
 *  Dependencies:       none 
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/


#include <Rcpp.h>

//' rcpp_test_points
//'
//' Reproduces code used in src/osmdata.cpp to compare Rcpp construction of
//' sfg::POINT' objects in ' osmdata with equivalent construction in sf. 
//'
//' @return An sf Simple Features Collection object of 'sfg::POINT' objects
//' equivalent to the R code 
//' 'sf::st_sfc (a=sf::st_point (c(1.0,2.0)), b=sf::st_point (c(3.0,4.0)))
//
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

    // Just for this test
    Rcpp::CharacterVector ptnms = Rcpp::CharacterVector::create ("a", "b");
    // Actual code from rcpp_osmdata_sf:
    //std::vector <std::string> ptnames;
    //ptnames.reserve (2);

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
