#include "get-bbox.h"

Rcpp::NumericMatrix rcpp_get_bbox (float xmin, float xmax, float ymin, float ymax)
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
};
