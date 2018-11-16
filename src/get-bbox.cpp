/***************************************************************************
 *  Project:    osmdata
 *  File:       get-bbox.cpp
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
 *  Author:     Mark Padgham 
 *  E-Mail:     mark.padgham@email.com 
 *
 *  Description:    Header for rcpp_get_bbox
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdata)
 *
 *  Compiler Options:   -std=c++11 
 ***************************************************************************/

#include "get-bbox.h"

Rcpp::NumericMatrix rcpp_get_bbox (double xmin, double xmax, double ymin, double ymax)
{
    std::vector <std::string> colnames, rownames;
    colnames.push_back ("min");
    colnames.push_back ("max");
    rownames.push_back ("x");
    rownames.push_back ("y");
    Rcpp::List dimnames (2);
    dimnames (0) = rownames;
    dimnames (1) = colnames;

    Rcpp::NumericMatrix bbox (Rcpp::Dimension (2, 2));
    bbox (0, 0) = xmin;
    bbox (0, 1) = xmax;
    bbox (1, 0) = ymin;
    bbox (1, 1) = ymax;

    bbox.attr ("dimnames") = dimnames;

    return bbox;
}

Rcpp::NumericVector rcpp_get_bbox_sf (double xmin, double xmax, double ymin, double ymax)
{
    std::vector <std::string> names;
    names.push_back ("xmin");
    names.push_back ("ymin");
    names.push_back ("xmax");
    names.push_back ("ymax");

    Rcpp::NumericVector bbox (4, NA_REAL);
    bbox (0) = xmin;
    bbox (1) = xmax;
    bbox (2) = ymin;
    bbox (3) = ymax;

    bbox.attr ("names") = names;
    bbox.attr ("class") = "bbox";

    return bbox;
}
