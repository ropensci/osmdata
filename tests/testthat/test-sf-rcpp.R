context ("sf-rcpp")
require (Rcpp)

cppFunction ("
    Rcpp::List junk () {
        const std::string p4s = \"+proj=longlat +datum=WGS84 +no_defs\";
        //Rcpp::List crs = Rcpp::List::create ((int) 4326, p4s);
        Rcpp::List crs = Rcpp::List::create (NA_INTEGER, 
                                             Rcpp::CharacterVector::create (NA_STRING));
        crs.attr (\"class\") = \"crs\";
        crs.attr (\"names\") = Rcpp::CharacterVector::create (\"epsg\", \"proj4string\");

        std::vector <std::string> names;
        names.push_back (\"xmin\");
        names.push_back (\"ymin\");
        names.push_back (\"xmax\");
        names.push_back (\"ymax\");
        Rcpp::NumericVector bbox (4, NA_REAL);
        bbox (0) = 1;
        bbox (1) = 2;
        bbox (2) = 3;
        bbox (3) = 4;
        bbox.attr (\"names\") = names;
                 
        Rcpp::List pointList (2);
        std::vector <std::string> ptnames;
        ptnames.reserve (2);

        Rcpp::CharacterVector ptnms = Rcpp::CharacterVector::create (\"a\", \"b\");

        for (int i=0; i<2; i++)
        {
            Rcpp::NumericVector ptxy = Rcpp::NumericVector::create (NA_REAL, NA_REAL);
            ptxy.attr (\"class\") = Rcpp::CharacterVector::create (\"XY\", \"POINT\", \"sfg\");
            ptxy [0] = 2 * i + 1;
            ptxy [1] = 2 * i + 2;
            pointList (i) = ptxy;
        }

        pointList.attr (\"names\") = ptnms;
        pointList.attr (\"n_empty\") = 0;
        pointList.attr (\"class\") = Rcpp::CharacterVector::create (\"sfc_POINT\", \"sfc\");
        pointList.attr (\"precision\") = 0.0;
        pointList.attr (\"bbox\") = bbox;
        pointList.attr (\"crs\") = crs;
        return pointList;
}")

test_that ("sf-rcpp-points", {
               x <- junk ()
               y <- sf::st_sfc (a=sf::st_point (c(1.0,2.0)), b=sf::st_point (c(3.0,4.0)))
               expect_identical (x, y)
})

