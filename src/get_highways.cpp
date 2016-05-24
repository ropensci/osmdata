#include "get_highways.h"
#include <unordered_set>
#include <Rcpp.h>

using namespace Rcpp;

const float FLOAT_MAX = std::numeric_limits<float>::max ();

Rcpp::NumericMatrix rcpp_get_bbox (float xmin, float xmax, float ymin, float ymax)
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
Rcpp::S4 rcpp_get_highways (std::string st)
{
    Xml xml (st);

    int tempi, coli, rowi, count = 0;
    long long ni;
    float lon, lat;
    float tempf, xmin = FLOAT_MAX, xmax = -FLOAT_MAX, 
          ymin = FLOAT_MAX, ymax = -FLOAT_MAX;
    std::vector <float> lons, lats;
    std::string id, key;
    std::unordered_set <std::string> idset; // see TODO below
    std::vector <std::string> colnames, rownames, waynames, varnames;
    Rcpp::List dimnames (0), dummy_list (0), result (xml.ways.size ());
    Rcpp::NumericMatrix nmat (Dimension (0, 0));

    // TODO: delete umapitr
    umapPair_Itr umapitr;
    typedef std::vector <long long>::iterator ll_Itr;

    colnames.push_back ("lon");
    colnames.push_back ("lat");
    waynames.resize (0);
    varnames.push_back ("name");
    varnames.push_back ("type");
    // other varnames added below

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

    for (Ways_Itr wi = xml.ways.begin(); wi != xml.ways.end(); ++wi)
    {
        // Collect all unique keys
        for (kv_iter = (*wi).key_val.begin (); kv_iter != (*wi).key_val.end ();
                ++kv_iter)
        {
            key = (*kv_iter).first;
            if (std::find (varnames.begin (), varnames.end (), key) == varnames.end ())
                varnames.push_back (key);
        }
        
        /*
         * The following lines check for duplicate way IDs -- which do very
         * occasionally occur -- and ensures unique values as required by 'sp'
         * through appending decimal digits to <long long> OSM IDs.
         * TODO: This uses an unordered_set: check if it's faster with a simple
         * vector and std::find
         */
        id = std::to_string ((*wi).id);
        while (idset.find (id) != idset.end ())
        {
            tempi = 0;
            id = std::to_string ((*wi).id) + "." + std::to_string (tempi);
        }
        auto si = idset.insert (id);

        waynames.push_back (id);
        // Set up first origin node
        ni = (*wi).nodes.front ();

        lons.resize (0);
        lats.resize (0);
        // TODO: Find out why the following pointer lines do not work here
        // assert ((umapitr = xml.nodes.find (ni)) != xml.nodes.end ());
        //lon = (*umapitr).second.first;
        //lat = (*umapitr).second.second;
        lon = xml.nodes [ni].first;
        lat = xml.nodes [ni].second;
        lons.push_back (lon);
        lats.push_back (lat);
        if (lon < xmin)
            xmin = lon;
        else if (lon > xmax)
            xmax = lon;
        if (lat < ymin)
            ymin = lat;
        else if (lat > ymax)
            ymax = lat;

        rownames.resize (0);
        rownames.push_back (std::to_string (ni));

        // Then iterate over the remaining nodes of that way
        for (ll_Itr it = std::next ((*wi).nodes.begin ());
                it != (*wi).nodes.end (); it++)
        {
            lon = xml.nodes [*it].first;
            lat = xml.nodes [*it].second;
            lons.push_back (lon);
            lats.push_back (lat);
            rownames.push_back (std::to_string (*it));
            if (lon < xmin)
                xmin = lon;
            else if (lon > xmax)
                xmax = lon;
            if (lat < ymin)
                ymin = lat;
            else if (lat > ymax)
                ymax = lat;
        }

        nmat = NumericMatrix (Dimension (lons.size (), 2));
        std::copy (lons.begin (), lons.end (), nmat.begin ());
        std::copy (lats.begin (), lats.end (), nmat.begin () + lons.size ());

        // This only works with push_back, not with direct re-allocation
        dimnames.push_back (rownames);
        dimnames.push_back (colnames);
        nmat.attr ("dimnames") = dimnames;
        while (dimnames.size () > 0)
            dimnames.erase (0);

        line = line_call.eval ();
        line.slot ("coords") = nmat;
        dummy_list.push_back (line);
        lines = lines_call.eval ();
        lines.slot ("Lines") = dummy_list;
        lines.slot ("ID") = std::to_string ((*wi).id);
        result [count++] = lines;
        
        dummy_list.erase (0);
    }
    result.attr ("names") = waynames;

    // Store all key-val pairs in one massive DF
    int nrow = xml.ways.size (), ncol = varnames.size ();
    Rcpp::CharacterVector kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na());
    for (Ways_Itr wi = xml.ways.begin(); wi != xml.ways.end(); ++wi)
    {
        auto it = std::find (varnames.begin (), varnames.end (), "name");
        coli = it - varnames.begin (); 
        rowi = wi - xml.ways.begin ();
        kv_vec (coli * nrow + rowi) = (*wi).name;
        it = std::find (varnames.begin (), varnames.end (), "type");
        coli = it - varnames.begin (); 
        rowi = wi - xml.ways.begin ();
        kv_vec (coli * nrow + rowi) = (*wi).type;
        for (kv_iter = (*wi).key_val.begin (); kv_iter != (*wi).key_val.end ();
                ++kv_iter)
        {
            key = (*kv_iter).first;
            it = std::find (varnames.begin (), varnames.end (), key);
            // key must exist in varnames!
            coli = it - varnames.begin (); 
            rowi = wi - xml.ways.begin ();
            kv_vec (coli * nrow + rowi) = (*kv_iter).second;
        }
    }

    Rcpp::Language sp_lines_call ("new", "SpatialLinesDataFrame");
    Rcpp::S4 sp_lines;
    sp_lines = sp_lines_call.eval ();
    sp_lines.slot ("lines") = result;

    sp_lines.slot ("bbox") = rcpp_get_bbox (xmin, xmax, ymin, ymax);

    Rcpp::Language crs_call ("new", "CRS");
    Rcpp::S4 crs = crs_call.eval ();
    crs.slot ("projargs") = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0";
    sp_lines.slot ("proj4string") = crs;

    Rcpp::CharacterMatrix kv_mat (nrow, ncol, kv_vec.begin());
    Rcpp::DataFrame kv_df = kv_mat;
    kv_df.attr ("names") = varnames;
    sp_lines.slot ("data") = kv_df;

    lons.resize (0);
    lats.resize (0);
    waynames.resize (0);
    colnames.resize (0);
    rownames.resize (0);
    varnames.resize (0);

    return sp_lines;
}
