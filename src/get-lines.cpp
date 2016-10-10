#include "get-lines.h"
#include "get-bbox.h"

#include <Rcpp.h>

#include <map>
#include <unordered_set>
#include <algorithm>

// APS uncomment to save xml input string to a file
//#define DUMP_INPUT

#ifdef DUMP_INPUT
#include <fstream>
#endif


const float FLOAT_MAX = std::numeric_limits<float>::max ();

//' rcpp_get_lines
//'
//' Extracts all ways from an overpass API query
//'
//' @param st Text contents of an overpass API query
//' @return A \code{SpatialLinesDataFrame} contains all ways and associated data
// [[Rcpp::export]]
Rcpp::S4 rcpp_get_lines (const std::string& st)
{
#ifdef DUMP_INPUT
    {
        std::ofstream dump("./get-lines.xml");
        if (dump.is_open())
        {
            dump.write(st.c_str(), st.size());
        }
    }
#endif

    XmlWays xml (st);
    const umapPair& xmlnodes = xml.nodes();
    const Ways& xmlways = xml.ways();

    int count = 0;
    float xmin = FLOAT_MAX, xmax = -FLOAT_MAX,
          ymin = FLOAT_MAX, ymax = -FLOAT_MAX;
    std::vector <float> lons, lats;
    std::unordered_set <std::string> idset; // see TODO below
    std::vector <std::string> colnames, rownames, waynames;
    std::set<std::string> varnames;
    Rcpp::List dimnames (0), dummy_list (0), wayList (xmlways.size ());
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    // TODO: delete umapitr
    umapPair_Itr umapitr;
    typedef std::vector <long long>::const_iterator ll_Itr;

    colnames.push_back ("lon");
    colnames.push_back ("lat");
    varnames.insert ("name");
    varnames.insert ("type");
    varnames.insert ("oneway");
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
    std::map<std::string, std::string>::const_iterator kv_iter;

    /// APS prealloc memory for all the way names
    waynames.reserve(xmlways.size());

    for (Ways_Itr wi = xmlways.begin(); wi != xmlways.end(); ++wi)
    {
        // Collect all unique keys
        std::for_each (wi->key_val.begin (), wi->key_val.end (),
                      [&](const std::pair<std::string, std::string>& p) 
                      { 
                          varnames.insert(p.first); 
                      });
        /*
         * The following lines check for duplicate way IDs -- which do very
         * occasionally occur -- and ensures unique values as required by 'sp'
         * through appending decimal digits to <long long> OSM IDs.
         * TODO: This uses an unordered_set: check if it's faster with a simple
         * vector and std::find
         */
        std::string id = std::to_string ((*wi).id);
        int tempi = 0;
        while (idset.find (id) != idset.end ())
            id = std::to_string ((*wi).id) + "." + std::to_string (tempi++);
        idset.insert (id);

        waynames.push_back (id);
        // Set up first origin node
        long long ni = (*wi).nodes.front ();

        lons.clear();
        lats.clear();
        rownames.clear();
        // APS we can alloc the right amount of memory upfront since we know the
        // size of xml.ways this will avoid potentially expensive reallocs as
        // the vector grows in size
        lons.reserve(wi->nodes.size());
        lats.reserve(wi->nodes.size());
        rownames.reserve(wi->nodes.size());

        // TODO: Find out why the following pointer lines do not work here
        // assert ((umapitr = xml.nodes.find (ni)) != xml.nodes.end ());
        //lon = (*umapitr).second.first;
        //lat = (*umapitr).second.second;
        // APS probably need some protection in case ni doesnt exist in xmlnodes
        float lon = xmlnodes.find(ni)->second.first;
        float lat = xmlnodes.find(ni)->second.second;
        lons.push_back (lon);
        lats.push_back (lat);

        rownames.push_back (std::to_string (ni));

        // Then iterate over the remaining nodes of that way
        for (ll_Itr it = std::next ((*wi).nodes.begin ());
                it != (*wi).nodes.end (); it++)
        {
            // APS probably need some protection in case *it doesnt exist in
            // xmlnodes
            lon = xmlnodes.find(*it)->second.first;
            lat = xmlnodes.find(*it)->second.second;
            lons.push_back (lon);
            lats.push_back (lat);
            rownames.push_back (std::to_string (*it));
        }

        xmin = std::min(xmin, *std::min_element(lons.begin(), lons.end()));
        xmax = std::max(xmax, *std::max_element(lons.begin(), lons.end()));
        ymin = std::min(ymin, *std::min_element(lats.begin(), lats.end()));
        ymax = std::max(ymax, *std::max_element(lats.begin(), lats.end()));

        nmat = Rcpp::NumericMatrix (Rcpp::Dimension (lons.size (), 2));
        std::copy (lons.begin (), lons.end (), nmat.begin ());
        std::copy (lats.begin (), lats.end (), nmat.begin () + lons.size ());

        // This only works with push_back, not with direct re-allocation
        dimnames.push_back (rownames);
        dimnames.push_back (colnames);
        nmat.attr ("dimnames") = dimnames;
        dimnames.erase(0, dimnames.size());

        // sp::Line and sp::Lines objects can be constructed directly from the
        // data with the following two lines, but this is *enormously* slower:
        //Rcpp::S4 line = Rcpp::Language ("Line", nmat).eval ();
        //Rcpp::S4 lines = Rcpp::Language ("Lines", line, id).eval ();
        // This way of constructing "new" objects and feeding slots is much
        // faster:
        line = line_call.eval ();
        line.slot ("coords") = nmat;
        dummy_list.push_back (line);
        lines = lines_call.eval ();
        lines.slot ("Lines") = dummy_list;
        lines.slot ("ID") = std::to_string ((*wi).id);
        wayList [count++] = lines;

        dummy_list.erase (0);
    }
    wayList.attr ("names") = waynames;

    // Store all key-val pairs in one massive DF
    int nrow = xmlways.size (), ncol = varnames.size ();
    Rcpp::CharacterVector kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na());
    // APS precalc repeated column names. Also use container's find
    // implementation which is likely more efficient than the generic find.
    int namecoli = std::distance(varnames.begin (), varnames.find("name"));
    int typecoli = std::distance(varnames.begin (), varnames.find("type"));
    int onewaycoli = std::distance(varnames.begin (), varnames.find("oneway"));
    for (Ways_Itr wi = xmlways.begin(); wi != xmlways.end(); ++wi)
    {
        int rowi = wi - xmlways.begin ();
        kv_vec (namecoli * nrow + rowi) = (*wi).name;
        kv_vec (typecoli * nrow + rowi) = (*wi).type;

        if ((*wi).oneway)
            kv_vec (onewaycoli * nrow + rowi) = "true";
        else
            kv_vec (onewaycoli * nrow + rowi) = "false";

        for (kv_iter = (*wi).key_val.begin (); kv_iter != (*wi).key_val.end ();
                ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto it = varnames.find(key);
            // key must exist in varnames!
            int coli = std::distance(varnames.begin (), it);
            kv_vec (coli * nrow + rowi) = (*kv_iter).second;
        }
    }

    Rcpp::Language sp_lines_call ("new", "SpatialLinesDataFrame");
    Rcpp::S4 sp_lines;
    sp_lines = sp_lines_call.eval ();
    sp_lines.slot ("lines") = wayList;

    sp_lines.slot ("bbox") = rcpp_get_bbox (xmin, xmax, ymin, ymax);

    Rcpp::Language crs_call ("new", "CRS");
    Rcpp::S4 crs = crs_call.eval ();
    crs.slot ("projargs") = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0";
    sp_lines.slot ("proj4string") = crs;

    Rcpp::CharacterMatrix kv_mat (nrow, ncol, kv_vec.begin());
    Rcpp::DataFrame kv_df = kv_mat;
    kv_df.attr ("names") = varnames;
    sp_lines.slot ("data") = kv_df;

    return sp_lines;
}
