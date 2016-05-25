#include "get-nodes.h"
#include <unordered_set>
#include <Rcpp.h>

using namespace Rcpp;

const float FLOAT_MAX = std::numeric_limits<float>::max ();

Rcpp::NumericMatrix rcpp_get_bbox2 (float xmin, float xmax, float ymin, float ymax)
{
    std::vector <std::string> colnames, rownames;
    colnames.push_back ("min");
    colnames.push_back ("max");
    rownames.push_back ("x");
    rownames.push_back ("y");
    List dimnames (2);
    dimnames (0) = rownames;
    dimnames (1) = colnames;

    NumericMatrix bbox (Dimension (2, 2));
    bbox (0, 0) = xmin;
    bbox (0, 1) = xmax;
    bbox (1, 0) = ymin;
    bbox (1, 1) = ymax;

    bbox.attr ("dimnames") = dimnames;

    return bbox;
};


// [[Rcpp::export]]
Rcpp::S4 rcpp_get_nodes (std::string st)
{
    XmlNodes xmlNodes (st);

    int tempi, coli, rowi, count = 0;
    long long ni;
    float lon, lat;
    float tempf, xmin = FLOAT_MAX, xmax = -FLOAT_MAX, 
          ymin = FLOAT_MAX, ymax = -FLOAT_MAX;
    std::vector <float> lons, lats;
    std::string id, key;
    std::unordered_set <std::string> idset; // see TODO below
    std::vector <std::string> colnames, rownames, varnames;
    Rcpp::List dimnames (0), dummy_list (0), result (xmlNodes.nodes.size ());
    Rcpp::NumericMatrix nmat (Dimension (0, 0));

    typedef std::vector <long long>::iterator ll_Itr;

    colnames.push_back ("lon");
    colnames.push_back ("lat");

    Rcpp::Language points_call ("new", "SpatialPoints");
    Rcpp::Language line_call ("new", "Line");
    Rcpp::Language lines_call ("new", "Lines");
    Rcpp::S4 line;
    Rcpp::S4 lines;

    /*
     * NOTE: Nodes are first loaded into the 2 vectors of (lon, lat), and these
     * are then copied into nmat. This intermediate can be avoided by loading
     * directly into nmat using direct indexing rather than iterators, however
     * this does *NOT* make the routine any faster, and so the current version
     * which more safely uses iterators is kept instead.
     */
    std::vector <std::pair <std::string, std::string> >::iterator kv_iter;

    for (Nodes_Itr ni = xmlNodes.nodes.begin ();
            ni != xmlNodes.nodes.end (); ++ni)
    {
    }


    Rcpp::Language sp_points_call ("new", "SpatialPointsDataFrame");
    Rcpp::S4 sp_points;
    sp_points = sp_points_call.eval ();
    //sp_points.slot ("SpatialPoints") = result;

    sp_points.slot ("bbox") = rcpp_get_bbox2 (xmin, xmax, ymin, ymax);

    Rcpp::Language crs_call ("new", "CRS");
    Rcpp::S4 crs = crs_call.eval ();
    crs.slot ("projargs") = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0";
    sp_points.slot ("proj4string") = crs;

    /*
    Rcpp::CharacterMatrix kv_mat (nrow, ncol, kv_vec.begin());
    Rcpp::DataFrame kv_df = kv_mat;
    kv_df.attr ("names") = varnames;
    sp_lines.slot ("data") = kv_df;
    */

    lons.resize (0);
    lats.resize (0);
    colnames.resize (0);
    rownames.resize (0);
    varnames.resize (0);

    return sp_points;
}
