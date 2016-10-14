#include "get-polygons.h"
#include "get-bbox.h"
#include <Rcpp.h>

// [[Rcpp::depends(sp)]]

//' rcpp_get_polygons
//'
//' Extracts all polygons from an overpass API query
//'
//' @param st Text contents of an overpass API query
//' @return A \code{SpatialLinesDataFrame} contains all polygons and associated data
// [[Rcpp::export]]
Rcpp::S4 rcpp_get_polygons (const std::string& st)
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

    XmlPolys xml (st);

    const std::map <long long, Node>& nodes = xml.nodes ();
    const std::map <long long, OneWay>& ways = xml.ways ();
    const std::vector <Relation>& rels = xml.relations ();

    int count = 0;
    float xmin = FLOAT_MAX, xmax = -FLOAT_MAX,
          ymin = FLOAT_MAX, ymax = -FLOAT_MAX;
    std::vector <float> lons, lats;
    std::unordered_set <std::string> idset; 
    std::vector <std::string> colnames, rownames, polynames;
    std::set <std::string> varnames;
    Rcpp::List dimnames (0), dummy_list (0);
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    idset.clear ();

    colnames.push_back ("lon");
    colnames.push_back ("lat");
    varnames.insert ("name");
    // other varnames added below

    /*
     * NOTE: Nodes are first loaded into the 2 vectors of (lon, lat), and these
     * are then copied into nmat. This intermediate can be avoided by loading
     * directly into nmat using direct indexing rather than iterators, however
     * this does *NOT* make the routine any faster, and so the current version
     * which more safely uses iterators is kept instead.
     */

    Rcpp::Environment sp_env = Rcpp::Environment::namespace_env ("sp");
    Rcpp::Function Polygon = sp_env ["Polygon"];
    Rcpp::Language polygons_call ("new", "Polygons");
    Rcpp::S4 polygons;

    /*
     * Polygons are extracted from the XmlPolys class in three setps:
     *  1. Get the names of all polygons that are part of multipolygon relations
     *  2. Get the names of any remaining ways that are polygonal (start == end)
     *  3. From the resultant list, extract the actual polygonal ways
     *
     * NOTE: OSM polygons are stored as ways, and thus all objects in the class
     * xmlPolys are rightly referred to as ways. Here within this Rcpp function,
     * these are referred to as Polygons, but the iteration is over the actual
     * polygonal ways.
     */

    // Step#1
    std::set <osmid_t> the_ways; // Set will only insert unique values
    //const std::vector <Relation>& rels = xml.relations ();
    for (auto it = rels.begin (); it != rels.end (); ++it)
        for (auto itw = (*it).ways.begin (); itw != (*it).ways.end (); ++itw)
        {
            assert (ways.find (itw->first) != ways.end ());
            the_ways.insert (itw->first);
        }

    // Step#2
    //const std::map <long long, OneWay>& ways = xml.ways ();
    for (auto it = ways.begin (); it != ways.end (); ++it)
    {
        if (the_ways.find ((*it).first) == the_ways.end ())
            if ((*it).second.nodes.begin () == (*it).second.nodes.end ())
                the_ways.insert ((*it).first);
    }
    // Step#2b - Erase any ways that contain no data (should not happen).
    for (auto it = the_ways.begin (); it != the_ways.end (); )
    {
        auto itw = ways.find (*it);
        if (itw->second.nodes.size () == 0)
            it = the_ways.erase (it);
        else
            ++it;
    }
    Rcpp::List polyList (the_ways.size ());

    // Step#3 - Extract and store the_ways
    for (auto it = the_ways.begin (); it != the_ways.end (); ++it)
    {
        auto itw = ways.find (*it);
        // Collect all unique keys
        std::for_each (itw->second.key_val.begin (), 
                itw->second.key_val.end (),
                [&](const std::pair <std::string, std::string>& p) 
                { 
                    varnames.insert (p.first); 
                });

        /*
         * The following lines check for duplicate way IDs -- which do very
         * occasionally occur -- and ensures unique values as required by 'sp'
         * through appending decimal digits to <long long> OSM IDs.
         */
        std::string id = std::to_string (itw->first);
        int tempi = 0;
        while (idset.find (id) != idset.end ())
            id = std::to_string (itw->first) + "." + std::to_string (tempi++);
        idset.insert (id);
        polynames.push_back (id);

        // Then iterate over nodes of that way and store all lat-lons
        size_t n = itw->second.nodes.size ();
        lons.clear ();
        lats.clear ();
        rownames.clear ();
        lons.reserve (n);
        lats.reserve (n);
        rownames.reserve (n);
        for (auto itn = itw->second.nodes.begin ();
                itn != itw->second.nodes.end (); ++itn)
        {
            // TODO: Propoer exception handler
            assert (nodes.find (*itn) != nodes.end ()); 
            lons.push_back (nodes.find (*itn)->second.lon);
            lats.push_back (nodes.find (*itn)->second.lat);
            rownames.push_back (std::to_string (*itn));
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

        //Rcpp::S4 poly = Rcpp::Language ("Polygon", nmat).eval ();
        Rcpp::S4 poly = Polygon (nmat);
        dummy_list.push_back (poly);
        polygons = polygons_call.eval ();
        polygons.slot ("Polygons") = dummy_list;
        polygons.slot ("ID") = std::to_string (itw->first);
        polyList [count++] = polygons;

        dummy_list.erase (0);
    } // end for it over the_ways
    lons.clear ();
    lats.clear ();
    polyList.attr ("names") = polynames;

    // Store all key-val pairs in one massive DF
    int nrow = the_ways.size (), ncol = varnames.size ();
    Rcpp::CharacterVector kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na());
    int namecoli = std::distance (varnames.begin (), varnames.find ("name"));
    for (auto it = the_ways.begin (); it != the_ways.end (); ++it)
    {
        int rowi = std::distance (the_ways.begin (), it);
        auto itw = ways.find (*it);
        kv_vec (namecoli * nrow + rowi) = itw->second.name;
        for (auto kv_iter = itw->second.key_val.begin ();
                kv_iter != itw->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto ni = varnames.find (key);
            // key must exist in varnames!
            int coli = std::distance (varnames.begin (), ni);
            kv_vec (coli * nrow + rowi) = (*kv_iter).second;
        }
    }

    Rcpp::Language sp_polys_call ("new", "SpatialPolygonsDataFrame");
    Rcpp::S4 sp_polys = sp_polys_call.eval ();
    sp_polys.slot ("polygons") = polyList;

    sp_polys.slot ("bbox") = rcpp_get_bbox (xmin, xmax, ymin, ymax);

    Rcpp::Language crs_call ("new", "CRS");
    Rcpp::S4 crs = crs_call.eval ();
    crs.slot ("projargs") = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0";
    sp_polys.slot ("proj4string") = crs;

    Rcpp::CharacterMatrix kv_mat (nrow, ncol, kv_vec.begin());
    Rcpp::DataFrame kv_df = kv_mat;
    kv_df.attr ("names") = varnames;
    sp_polys.slot ("data") = kv_df;

    return sp_polys;
}
