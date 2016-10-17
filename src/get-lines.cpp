#include "get-lines.h"
#include "get-bbox.h"

#include <Rcpp.h>

#include <algorithm> // TODO: Really?


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
        std::ofstream dump ("./get-lines.xml");
        if (dump.is_open())
        {
            dump.write (st.c_str(), st.size());
        }
    }
#endif

    XmlWays xml (st);

    const std::map <long long, Node>& nodes = xml.nodes ();
    const std::map <long long, OneWay>& ways = xml.ways ();

    int count = 0;
    float xmin = FLOAT_MAX, xmax = -FLOAT_MAX,
          ymin = FLOAT_MAX, ymax = -FLOAT_MAX;
    std::vector <float> lons, lats;
    std::unordered_set <std::string> idset; // see TODO below
    std::vector <std::string> colnames, rownames, waynames;
    std::set<std::string> varnames;
    Rcpp::List dimnames (0), dummy_list (0), wayList (ways.size ());
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    idset.clear ();

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

    /// APS prealloc memory for all the way names
    waynames.reserve (ways.size());

    for (auto wi = ways.begin(); wi != ways.end(); ++wi)
    {
        // Collect all unique keys
        std::for_each (wi->second.key_val.begin (), wi->second.key_val.end (),
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
        std::string id = std::to_string (wi->first);
        int tempi = 0;
        while (idset.find (id) != idset.end ())
            id = std::to_string (wi->first) + "." + std::to_string (tempi++);
        idset.insert (id);
        waynames.push_back (id);

        // Then iterate over nodes of that way and store all lat-lons
        size_t n = wi->second.nodes.size ();
        lons.clear ();
        lats.clear ();
        rownames.clear ();
        lons.reserve (n);
        lats.reserve (n);
        rownames.reserve (n);
        for (auto ni = wi->second.nodes.begin ();
                ni != wi->second.nodes.end (); ++ni)
        {
            // TODO: Propoer exception handler
            assert (nodes.find (*ni) != nodes.end ()); 
            lons.push_back (nodes.find (*ni)->second.lon);
            lats.push_back (nodes.find (*ni)->second.lat);
            rownames.push_back (std::to_string (*ni));
        }

        xmin = std::min (xmin, *std::min_element (lons.begin(), lons.end()));
        xmax = std::max (xmax, *std::max_element (lons.begin(), lons.end()));
        ymin = std::min (ymin, *std::min_element (lats.begin(), lats.end()));
        ymax = std::max (ymax, *std::max_element (lats.begin(), lats.end()));

        nmat = Rcpp::NumericMatrix (Rcpp::Dimension (lons.size (), 2));
        std::copy (lons.begin (), lons.end (), nmat.begin ());
        std::copy (lats.begin (), lats.end (), nmat.begin () + lons.size ());

        // This only works with push_back, not with direct re-allocation
        dimnames.push_back (rownames);
        dimnames.push_back (colnames);
        nmat.attr ("dimnames") = dimnames;
        dimnames.erase (0, dimnames.size());

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
        lines.slot ("ID") = id;
        wayList [count++] = lines;

        dummy_list.erase (0);
    }
    wayList.attr ("names") = waynames;

    // Store all key-val pairs in one massive DF
    int nrow = ways.size (), ncol = varnames.size ();
    Rcpp::CharacterVector kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na ());
    // APS precalc repeated column names. Also use container's find
    // implementation which is likely more efficient than the generic find.
    int namecoli = std::distance (varnames.begin (), varnames.find ("name"));
    int typecoli = std::distance (varnames.begin (), varnames.find ("type"));
    int onewaycoli = std::distance (varnames.begin (), varnames.find ("oneway"));
    for (auto wi = ways.begin(); wi != ways.end(); ++wi)
    {
        //int rowi = wi - xmlways.begin ();
        int rowi = std::distance (ways.begin (), wi);
        kv_vec (namecoli * nrow + rowi) = wi->second.name;
        kv_vec (typecoli * nrow + rowi) = wi->second.type;

        if (wi->second.oneway)
            kv_vec (onewaycoli * nrow + rowi) = "true";
        else
            kv_vec (onewaycoli * nrow + rowi) = "false";

        for (auto kv_iter = wi->second.key_val.begin (); 
                kv_iter != wi->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto it = varnames.find (key); // key must exist in varnames!
            int coli = std::distance (varnames.begin (), it);
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
