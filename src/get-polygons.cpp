#include "get-polygons.h"
#include <unordered_set>
#include <Rcpp.h>

using namespace Rcpp;

const float FLOAT_MAX = std::numeric_limits<float>::max ();

Rcpp::NumericMatrix rcpp_get_bbox3 (float xmin, float xmax, float ymin, float ymax)
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

//' rcpp_get_polys
//'
//' Extracts all polygons from an overpass API query
//'
//' @param st Text contents of an overpass API query
//' @return A SpatialLinesDataFrame contains all polygons and associated data
//' @export
// [[Rcpp::export]]
Rcpp::S4 rcpp_get_polygons (std::string st)
{
    XmlPolys xml (st);

    int tempi, coli, rowi, count = 0;
    long long ni;
    float lon, lat;
    float tempf, xmin = FLOAT_MAX, xmax = -FLOAT_MAX, 
          ymin = FLOAT_MAX, ymax = -FLOAT_MAX;
    std::vector <float> lons, lats;
    std::string id, key;
    std::unordered_set <std::string> idset; // see TODO below
    std::vector <std::string> colnames, rownames, polynames, varnames;
    Rcpp::List dimnames (0), dummy_list (0), polyList (xml.polys.size ());
    Rcpp::NumericMatrix nmat (Dimension (0, 0));

    // TODO: delete umapitr
    umapPair_Itr umapitr;
    typedef std::vector <long long>::iterator ll_Itr;

    colnames.push_back ("lon");
    colnames.push_back ("lat");
    polynames.resize (0);
    varnames.push_back ("name");
    // other varnames added below

    /*
     * NOTE: Nodes are first loaded into the 2 vectors of (lon, lat), and these
     * are then copied into nmat. This intermediate can be avoided by loading
     * directly into nmat using direct indexing rather than iterators, however
     * this does *NOT* make the routine any faster, and so the current version
     * which more safely uses iterators is kept instead.
     */
    std::vector <std::pair <std::string, std::string> >::iterator kv_iter;

    for (Polys_Itr wi = xml.polys.begin(); wi != xml.polys.end(); ++wi)
    {
        // Only proceed if start and end points are the same, otherwise it's
        // just a normal way
        if ((*wi).nodes.size () > 0 && 
                (*(*wi).nodes.begin () == *(*wi).nodes.end ()))
        {
            // Collect all unique keys
            for (kv_iter = (*wi).key_val.begin (); 
                    kv_iter != (*wi).key_val.end (); ++kv_iter)
            {
                key = (*kv_iter).first;
                if (std::find (varnames.begin (), 
                            varnames.end (), key) == varnames.end ())
                    varnames.push_back (key);
            }
        
            /*
             * The following lines check for duplicate way IDs -- which do very
             * occasionally occur -- and ensures unique values as required by 'sp'
             * through appending decimal digits to <long long> OSM IDs.
             */
            id = std::to_string ((*wi).id);
            tempi = 0;
            while (idset.find (id) != idset.end ())
                id = std::to_string ((*wi).id) + "." + std::to_string (tempi++);
            auto si = idset.insert (id);

            polynames.push_back (id);
            // Set up first origin node
            ni = (*wi).nodes.front ();

            lons.resize (0);
            lats.resize (0);
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

            Rcpp::S4 poly = Rcpp::Language ("Polygon", nmat).eval ();
            polyList [count++] = poly;
        }
    }
    polyList.attr ("names") = polynames;

    // Store all key-val pairs in one massive DF
    int nrow = xml.polys.size (), ncol = varnames.size ();
    Rcpp::CharacterVector kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na());
    for (Polys_Itr wi = xml.polys.begin(); wi != xml.polys.end(); ++wi)
    {
        if ((*wi).nodes.size () > 0 && 
                ((*wi).nodes.begin () == (*wi).nodes.end ()))
        {
            auto it = std::find (varnames.begin (), varnames.end (), "name");
            coli = it - varnames.begin (); 
            rowi = wi - xml.polys.begin ();
            kv_vec (coli * nrow + rowi) = (*wi).name;

            for (kv_iter = (*wi).key_val.begin (); kv_iter != (*wi).key_val.end ();
                    ++kv_iter)
            {
                key = (*kv_iter).first;
                it = std::find (varnames.begin (), varnames.end (), key);
                // key must exist in varnames!
                coli = it - varnames.begin (); 
                rowi = wi - xml.polys.begin ();
                kv_vec (coli * nrow + rowi) = (*kv_iter).second;
            }
        }
    }

    Rcpp::Language sp_polys_call ("new", "SpatialPolygonsDataFrame");
    Rcpp::S4 sp_polys = sp_polys_call.eval ();
    sp_polys.slot ("polygons") = polyList;

    sp_polys.slot ("bbox") = rcpp_get_bbox3 (xmin, xmax, ymin, ymax);

    Rcpp::Language crs_call ("new", "CRS");
    Rcpp::S4 crs = crs_call.eval ();
    crs.slot ("projargs") = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0";
    sp_polys.slot ("proj4string") = crs;

    Rcpp::CharacterMatrix kv_mat (nrow, ncol, kv_vec.begin());
    Rcpp::DataFrame kv_df = kv_mat;
    kv_df.attr ("names") = varnames;
    sp_polys.slot ("data") = kv_df;

    lons.resize (0);
    lats.resize (0);
    polynames.resize (0);
    colnames.resize (0);
    rownames.resize (0);
    varnames.resize (0);

    return sp_polys;
}
