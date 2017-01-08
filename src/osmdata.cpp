/***************************************************************************
 *  Project:    osmdata
 *  File:       osmdata.cpp
 *  Language:   C++
 *
 *  osmdata is free software: you can redistribute it and/or modify it under
 *  the terms of the GNU General Public License as published by the Free
 *  Software Foundation, either version 3 of the License, or (at your option)
 *  any later version.
 *
 *  osmdata is distributed in the hope that it will be useful, but WITHOUT ANY
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 *  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 *  details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  osm-router.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Author:     Mark Padgham / Andrew Smith
 *  E-Mail:     mark.padgham@email.com / andrew@casacazaz.net
 *
 *  Description:    Extract OSM data from an object of class XmlData and return
 *                  it in Rcpp::List format.
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#include "osmdata.h"
#include "get-bbox.h"

#include <Rcpp.h>

#include <algorithm> // for min_element/max_element

//' rcpp_osmdata
//'
//' Extracts all polygons from an overpass API query
//'
//' @param st Text contents of an overpass API query
//' @return Rcpp::List objects of OSM data
// [[Rcpp::export]]
Rcpp::List rcpp_osmdata (const std::string& st)
{
#ifdef DUMP_INPUT
    {
        std::ofstream dump ("./osmdata-sp.xml");
        if (dump.is_open())
        {
            dump.write (st.c_str(), st.size());
        }
    }
#endif

    XmlData xml (st);

    const std::map <osmid_t, Node>& nodes = xml.nodes ();
    const std::map <osmid_t, OneWay>& ways = xml.ways ();
    const std::vector <Relation>& rels = xml.relations ();

    int count = 0;
    std::vector <float> lons, lats;
    std::unordered_set <std::string> idset; // see TODO below
    std::vector <std::string> colnames, rownames, polynames;
    std::set <std::string> varnames;
    Rcpp::List dimnames (0);
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    idset.clear ();

    colnames.push_back ("lon");
    colnames.push_back ("lat");
    varnames.insert ("name");
    varnames.insert ("type");
    varnames.insert ("oneway");
    // other varnames added below

    /*
     * NOTE: Nodes are first loaded into the 2 vectors of (lon, lat), and these
     * are then copied into nmat. This intermediate can be avoided by loading
     * directly into nmat using direct indexing rather than iterators, however
     * this does *NOT* make the routine any faster, and so the current version
     * which more safely uses iterators is kept instead.
     */

    // non_poly_ways are returned as line objects
    std::set <osmid_t> poly_ways, non_poly_ways;

    /*
     * Polygons are extracted from the XmlData class in three setps:
     *  1. Get the names of all polygons that are part of multipolygon relations
     *  2. Get the names of any remaining ways that are polygonal (start == end)
     *  3. From the resultant list, extract the actual polygonal ways
     *
     * NOTE: OSM polygons are stored as ways, and thus all objects in the class
     * xmlPolys are rightly referred to as ways. Here within this Rcpp function,
     * these are referred to as Polygons, but the iteration is over the actual
     * polygonal ways.
     */

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                           PRE-PROCESSING                           **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    // Step#1
    for (auto it = rels.begin (); it != rels.end (); ++it)
        for (auto itw = (*it).ways.begin (); itw != (*it).ways.end (); ++itw)
        {
            assert (ways.find (itw->first) != ways.end ());
            poly_ways.insert (itw->first);
        }

    // Step#2
    //const std::map <osmid_t, OneWay>& ways = xml.ways ();
    for (auto it = ways.begin (); it != ways.end (); ++it)
    {
        if ((*it).second.nodes.front () == (*it).second.nodes.back ())
        {
            if (poly_ways.find ((*it).first) == poly_ways.end ())
                poly_ways.insert ((*it).first);
        } else if (non_poly_ways.find ((*it).first) == non_poly_ways.end ())
            non_poly_ways.insert ((*it).first);
    }

    // Step#2b - Erase any ways that contain no data (should not happen).
    for (auto it = poly_ways.begin (); it != poly_ways.end (); )
    {
        auto itw = ways.find (*it);
        if (itw->second.nodes.size () == 0)
            it = poly_ways.erase (it);
        else
            ++it;
    }
    for (auto it = non_poly_ways.begin (); it != non_poly_ways.end (); )
    {
        auto itw = ways.find (*it);
        if (itw->second.nodes.size () == 0)
            it = non_poly_ways.erase (it);
        else
            ++it;
    }

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                         STEP#3A: POLYGONS                          **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    Rcpp::List polyList (poly_ways.size ());
    polynames.reserve (poly_ways.size ());
    for (auto it = poly_ways.begin (); it != poly_ways.end (); ++it)
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
         * through appending decimal digits to <osmid_t> OSM IDs.
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

        nmat = Rcpp::NumericMatrix (Rcpp::Dimension (lons.size (), 2));
        std::copy (lons.begin (), lons.end (), nmat.begin ());
        std::copy (lats.begin (), lats.end (), nmat.begin () + lons.size ());

        // This only works with push_back, not with direct re-allocation
        dimnames.push_back (rownames);
        dimnames.push_back (colnames);
        nmat.attr ("dimnames") = dimnames;
        dimnames.erase (0, dimnames.size());

        polyList [count++] = nmat;
    } // end for it over poly_ways
    polyList.attr ("names") = polynames;

    // Store all key-val pairs in one massive DF
    int nrow = poly_ways.size (), ncol = varnames.size ();
    Rcpp::CharacterVector poly_kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na ());
    int namecoli = std::distance (varnames.begin (), varnames.find ("name"));
    int typecoli = std::distance (varnames.begin (), varnames.find ("type"));
    int onewaycoli = std::distance (varnames.begin (), varnames.find ("oneway"));
    for (auto it = poly_ways.begin (); it != poly_ways.end (); ++it)
    {
        int rowi = std::distance (poly_ways.begin (), it);
        auto itw = ways.find (*it);
        poly_kv_vec (namecoli * nrow + rowi) = itw->second.name;
        poly_kv_vec (typecoli * nrow + rowi) = itw->second.type;

        if (itw->second.oneway)
            poly_kv_vec (onewaycoli * nrow + rowi) = "true";
        else
            poly_kv_vec (onewaycoli * nrow + rowi) = "false";

        for (auto kv_iter = itw->second.key_val.begin ();
                kv_iter != itw->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto ni = varnames.find (key); // key must exist in varnames!
            int coli = std::distance (varnames.begin (), ni);
            poly_kv_vec (coli * nrow + rowi) = (*kv_iter).second;
        }
    }

    Rcpp::CharacterMatrix poly_kv_mat (nrow, ncol, poly_kv_vec.begin());
    Rcpp::DataFrame poly_kv_df = poly_kv_mat;
    poly_kv_df.attr ("names") = varnames;

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                           STEP#3B: LINES                           **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    Rcpp::List lineList (non_poly_ways.size ());
    std::vector <std::string> linenames;
    linenames.reserve (non_poly_ways.size());

    colnames.resize (0);
    colnames.push_back ("lon");
    colnames.push_back ("lat");
    varnames.clear ();
    varnames.insert ("name");
    varnames.insert ("type");
    varnames.insert ("oneway");

    count = 0;

    idset.clear ();
    dimnames.erase (0, dimnames.size());
    Rcpp::NumericMatrix nmat2 (Rcpp::Dimension (0, 0)); 
    // TODO: Things to delete and replace with resize:
    // nmat2, kv_vec2, kv_mat2, kv_df2
    // nmat3, kv_vec3, kv_mat3, kv_df3

    for (auto it = non_poly_ways.begin (); it != non_poly_ways.end (); ++it)
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
         * through appending decimal digits to <osmid_t> OSM IDs.
         */
        std::string id = std::to_string (itw->first);
        int tempi = 0;
        while (idset.find (id) != idset.end ())
            id = std::to_string (itw->first) + "." + std::to_string (tempi++);
        idset.insert (id);
        linenames.push_back (id);

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

        nmat2 = Rcpp::NumericMatrix (Rcpp::Dimension (lons.size (), 2));
        std::copy (lons.begin (), lons.end (), nmat2.begin ());
        std::copy (lats.begin (), lats.end (), nmat2.begin () + lons.size ());

        // This only works with push_back, not with direct re-allocation
        dimnames.push_back (rownames);
        dimnames.push_back (colnames);
        nmat2.attr ("dimnames") = dimnames;
        dimnames.erase (0, dimnames.size());

        lineList [count++] = nmat2;
    } // end for it over non_poly_ways
    lineList.attr ("names") = linenames;

    // Store all key-val pairs in one massive DF
    nrow = non_poly_ways.size (); 
    ncol = varnames.size ();
    Rcpp::CharacterVector line_kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na ());
    namecoli = std::distance (varnames.begin (), varnames.find ("name"));
    typecoli = std::distance (varnames.begin (), varnames.find ("type"));
    onewaycoli = std::distance (varnames.begin (), varnames.find ("oneway"));
    for (auto it = non_poly_ways.begin (); it != non_poly_ways.end (); ++it)
    {
        int rowi = std::distance (non_poly_ways.begin (), it);
        auto itw = ways.find (*it);
        line_kv_vec (namecoli * nrow + rowi) = itw->second.name;
        line_kv_vec (typecoli * nrow + rowi) = itw->second.type;

        if (itw->second.oneway)
            line_kv_vec (onewaycoli * nrow + rowi) = "true";
        else
            line_kv_vec (onewaycoli * nrow + rowi) = "false";

        for (auto kv_iter = itw->second.key_val.begin ();
                kv_iter != itw->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto ni = varnames.find (key); // key must exist in varnames!
            int coli = std::distance (varnames.begin (), ni);
            line_kv_vec (coli * nrow + rowi) = (*kv_iter).second;
        }
    }

    Rcpp::CharacterMatrix line_kv_mat (nrow, ncol, line_kv_vec.begin());
    Rcpp::DataFrame line_kv_df = line_kv_mat;
    line_kv_df.attr ("names") = varnames;

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                          STEP#3C: POINTS                           **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    Rcpp::List pointList (nodes.size ());
    std::vector <std::string> nodenames;
    nodenames.reserve (nodes.size());

    colnames.resize (0);
    colnames.push_back ("lon");
    colnames.push_back ("lat");
    varnames.clear ();

    count = 0;

    dimnames.erase (0, dimnames.size());
    Rcpp::NumericMatrix nmat3 (Rcpp::Dimension (0, 0)); 

    lons.clear ();
    lats.clear ();
    lons.reserve (nodes.size ());
    lats.reserve (nodes.size ());
    rownames.clear ();
    rownames.reserve (nodes.size ());

    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        // Collect all unique keys
        std::for_each (ni->second.key_val.begin (),
                ni->second.key_val.end (),
                [&](const std::pair <std::string, std::string>& p)
                {
                    varnames.insert (p.first);
                });

        lons.push_back (ni->second.lon);
        lats.push_back (ni->second.lat);
        rownames.push_back (std::to_string (ni->first));
    }

    float xmin=FLOAT_MAX, xmax=-FLOAT_MAX, ymin=FLOAT_MAX, ymax=-FLOAT_MAX;
    if (nodes.size () == 0)
        throw std::runtime_error ("Query returned no data");
    else
    {
        xmin = std::min (xmin, *std::min_element (lons.begin(), lons.end()));
        xmax = std::max (xmax, *std::max_element (lons.begin(), lons.end()));
        ymin = std::min (ymin, *std::min_element (lats.begin(), lats.end()));
        ymax = std::max (ymax, *std::max_element (lats.begin(), lats.end()));
    }
    if (fabs (xmin) == FLOAT_MAX || fabs (xmax) == FLOAT_MAX ||
            fabs (ymin) == FLOAT_MAX || fabs (ymax) == FLOAT_MAX)
        throw std::runtime_error ("No bounding box able to be determined");

    // Store all key-val pairs in one massive DF
    nrow = nodes.size (); 
    ncol = varnames.size ();
    Rcpp::CharacterVector point_kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na ());
    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        int rowi = std::distance (nodes.begin (), ni);
        for (auto kv_iter = ni->second.key_val.begin ();
                kv_iter != ni->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto it = varnames.find (key); // key must exist in varnames!
            int coli = std::distance (varnames.begin (), it);
            point_kv_vec (coli * nrow + rowi) = (*kv_iter).second;
        }
    }

    nmat3 = Rcpp::NumericMatrix (Rcpp::Dimension (lons.size (), 2));
    std::copy (lons.begin (), lons.end (), nmat3.begin ());
    std::copy (lats.begin (), lats.end (), nmat3.begin () + lons.size ());
    dimnames.push_back (rownames);
    dimnames.push_back (colnames);
    nmat3.attr ("dimnames") = dimnames;
    dimnames.erase (0, dimnames.size());

    Rcpp::CharacterMatrix point_kv_mat (nrow, ncol, point_kv_vec.begin());
    Rcpp::DataFrame point_kv_df = point_kv_mat;
    point_kv_df.attr ("names") = varnames;
    // points are in nmat3

    Rcpp::NumericMatrix bbox = rcpp_get_bbox (xmin, xmax, ymin, ymax);

    //Rcpp::Language crs_call ("new", "CRS"); // sp
    //Rcpp::S4 crs = crs_call.eval ();
    //crs.slot ("projargs") = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0";

    Rcpp::List ret (7);
    ret [0] = bbox;
    ret [1] = nmat3;
    ret [2] = point_kv_df;
    ret [3] = lineList;
    ret [4] = line_kv_df;
    ret [5] = polyList;
    ret [6] = poly_kv_df;

    std::vector <std::string> retnames {"bbox", "points", "points_kv",
        "lines", "lines_kv", "polygons", "polygons_kv"};
    ret.attr ("names") = retnames;
    
    return ret;
}
