#include "get-polygons.h"
#include "get-bbox.h"
#include <Rcpp.h>
#include <unordered_set>

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
    XmlPolys xml (st);

    int count = 0;
    float xmin = FLOAT_MAX, xmax = -FLOAT_MAX,
          ymin = FLOAT_MAX, ymax = -FLOAT_MAX;
    std::vector <float> lons, lats;
    std::unordered_set <std::string> idset; // see TODO below
    std::vector <std::string> colnames, rownames, polynames;
    std::set <std::string> varnames;
    Rcpp::List dimnames (0), dummy_list (0), polyList (xml.ways().size ());
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    typedef std::vector <long long>::const_iterator ll_Itr;

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
    std::map<std::string, std::string>::const_iterator kv_iter;

    Rcpp::Environment sp_env = Rcpp::Environment::namespace_env ("sp");
    Rcpp::Function Polygon = sp_env ["Polygon"];
    Rcpp::Language polygons_call ("new", "Polygons");
    Rcpp::S4 polygons;

    /*
     * NOTE: OSM polygons are stored as ways, and thus all objects in the class
     * xmlPolys are rightly referred to as ways. Here within this Rcpp function,
     * these are referred to as Polygons, but the iteration is over the actual
     * polygonal ways.
     */
    for (Ways_Itr wi = xml.ways().begin(); wi != xml.ways().end(); ++wi)
    {
        // Only proceed if start and end points are the same, otherwise it's
        // just a normal way
        if (wi->second.nodes.size () > 0 &&
                (wi->second.nodes.front () == wi->second.nodes.back ()))
        {
            // Collect all unique keys
            std::for_each (wi->second.key_val.begin (), 
                    wi->second.key_val.end (),
                    [&](const std::pair <std::string, std::string>& p) 
                    { 
                    varnames.insert (p.first); 
                    });

            /*
             * The following lines check for duplicate way IDs -- which do very
             * occasionally occur -- and ensures unique values as required by 'sp'
             * through appending decimal digits to <long long> OSM IDs.
             */
            std::string id = std::to_string (wi->first);

            int tempi = 0;
            while (idset.find (id) != idset.end ())
                id = std::to_string (wi->first) + "." + std::to_string (tempi++);
            idset.insert (id);

            polynames.push_back (id);
            // Set up first origin node
            int ni = wi->second.nodes.front ();

            const std::map <long long, Node>& nodes = xml.nodes ();
            lons.clear ();
            lats.clear ();
            lons.reserve (nodes.size ());
            lats.reserve (nodes.size ());

            // APS using find segfaults on the test data so need to check
            // iterator validity 
            // MP Done, but TODO: Proper exception handler
            auto it = nodes.find (ni);
            assert (it != nodes.end ());
            lons.push_back (it->second.lon);
            lats.push_back (it->second.lat);

            rownames.clear ();
            rownames.reserve (nodes.size ());
            rownames.push_back (std::to_string (ni));

            // Then iterate over the remaining nodes of that way
            for (ll_Itr it = std::next (wi->second.nodes.begin ());
                    it != wi->second.nodes.end (); it++)
            {
                // APS needs protection from invalid iterator
                // MP Done, but TODO: Proper exception handler
                assert (nodes.find (*it) != nodes.end ());
                lons.push_back (nodes.find (*it)->second.lon);
                lats.push_back (nodes.find (*it)->second.lat);
                rownames.push_back (std::to_string (*it));
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
            polygons.slot ("ID") = std::to_string (wi->first);
            polyList [count++] = polygons;

            dummy_list.erase (0);
        }
    }
    polyList.attr ("names") = polynames;

    // Store all key-val pairs in one massive DF
    int nrow = xml.ways().size (), ncol = varnames.size ();
    Rcpp::CharacterVector kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na());
    int namecoli = std::distance (varnames.begin (), varnames.find ("name"));
    for (Ways_Itr wi = xml.ways().begin(); wi != xml.ways().end(); ++wi)
    {
        int rowi = std::distance (std::begin (xml.ways ()), wi);

        if (wi->second.nodes.size () > 0 &&
                (wi->second.nodes.front () == wi->second.nodes.back ()))
        {
            kv_vec (namecoli * nrow + rowi) = wi->second.name;

            for (kv_iter = wi->second.key_val.begin ();
                    kv_iter != wi->second.key_val.end (); ++kv_iter)
            {
                const std::string& key = (*kv_iter).first;
                auto it = varnames.find (key);
                // key must exist in varnames!
                int coli = std::distance(varnames.begin (), it);
                kv_vec (coli * nrow + rowi) = (*kv_iter).second;
            }
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

    idset.clear ();

    return sp_polys;
}
