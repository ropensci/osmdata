#include "get-points.h"
#include "get-bbox.h"

#include <Rcpp.h>

#include <algorithm> // for min_element/max_element

//' rcpp_get_points
//'
//' Extracts all nodes from an overpass API query
//'
//' @param st Text contents of an overpass API query
//' @return A \code{SpatialPointsDataFrame} contains all nodes and associated data
// [[Rcpp::export]]
Rcpp::S4 rcpp_get_points (const std::string& st)
{
#ifdef DUMP_INPUT
    {
        std::ofstream dump ("./get-points.xml");
        if (dump.is_open())
        {
            dump.write (st.c_str(), st.size());
        }
    }
#endif

    XmlNodes xml (st);

    const std::map <osmid_t, Node>& nodes = xml.nodes ();

    float xmin = FLOAT_MAX, xmax = -FLOAT_MAX,
          ymin = FLOAT_MAX, ymax = -FLOAT_MAX;
    std::vector <std::string> colnames, rownames;
    std::set<std::string> varnames;
    Rcpp::List dimnames (0);
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    colnames.push_back ("lon");
    colnames.push_back ("lat");

    std::vector <float> lons, lats;
    lons.reserve (nodes.size ());
    lats.reserve (nodes.size ());
    rownames.reserve (nodes.size ());

    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        // Collect all unique keys
        std::for_each (ni->second.key_val.begin (), ni->second.key_val.end (),
                      [&](const std::pair<std::string, std::string>& p)
                      {
                          varnames.insert (p.first);
                      });

        lons.push_back (ni->second.lon);
        lats.push_back (ni->second.lat);
        rownames.push_back (std::to_string (ni->first));
    }

    if (nodes.size () > 0)
    {
        xmin = std::min (xmin, *std::min_element (lons.begin(), lons.end()));
        xmax = std::max (xmax, *std::max_element (lons.begin(), lons.end()));
        ymin = std::min (ymin, *std::min_element (lats.begin(), lats.end()));
        ymax = std::max (ymax, *std::max_element (lats.begin(), lats.end()));
    }

    // Store all key-val pairs in one massive DF
    int nrow = nodes.size (), ncol = varnames.size ();
    Rcpp::CharacterVector kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na ());
    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        //int rowi = ni - nodes.begin ();
        int rowi = std::distance (nodes.begin (), ni);
        for (auto kv_iter = ni->second.key_val.begin ();
                kv_iter != ni->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto it = varnames.find (key); // key must exist in varnames!
            int coli = std::distance (varnames.begin (), it);
            kv_vec (coli * nrow + rowi) = (*kv_iter).second;
        }
    }

    nmat = Rcpp::NumericMatrix (Rcpp::Dimension (lons.size (), 2));
    std::copy (lons.begin (), lons.end (), nmat.begin ());
    std::copy (lats.begin (), lats.end (), nmat.begin () + lons.size ());
    dimnames.push_back (rownames);
    dimnames.push_back (colnames);
    nmat.attr ("dimnames") = dimnames;
    dimnames.erase (0, dimnames.size());

    Rcpp::CharacterMatrix kv_mat (nrow, ncol, kv_vec.begin());
    Rcpp::DataFrame kv_df = kv_mat;
    kv_df.attr ("names") = varnames;

    Rcpp::Language points_call ("new", "SpatialPoints");
    Rcpp::Language sp_points_call ("new", "SpatialPointsDataFrame");
    Rcpp::S4 sp_points;
    sp_points = sp_points_call.eval ();
    sp_points.slot ("data") = kv_df;
    sp_points.slot ("coords") = nmat;
    sp_points.slot ("bbox") = rcpp_get_bbox (xmin, xmax, ymin, ymax);

    Rcpp::Language crs_call ("new", "CRS");
    Rcpp::S4 crs = crs_call.eval ();
    crs.slot ("projargs") = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0";
    sp_points.slot ("proj4string") = crs;

    return sp_points;
}
