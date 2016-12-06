/***************************************************************************
 *  Project:    osmdatar
 *  File:       get-osmdata.cpp
 *  Language:   C++
 *
 *  osmdatar is free software: you can redistribute it and/or modify it under
 *  the terms of the GNU General Public License as published by the Free
 *  Software Foundation, either version 3 of the License, or (at your option)
 *  any later version.
 *
 *  osmdatar is distributed in the hope that it will be useful, but WITHOUT ANY
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
 *  Description:    Class definition of XmlData
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#include "get-osmdata.h"
#include "get-bbox.h"

#include <Rcpp.h>

#include <algorithm> // for min_element/max_element

// [[Rcpp::depends(sp)]]

//' rcpp_get_osmdata
//'
//' Extracts all polygons from an overpass API query
//'
//' @param st Text contents of an overpass API query
//' @return A \code{SpatialLinesDataFrame} contains all polygons and associated data
// [[Rcpp::export]]
Rcpp::List rcpp_get_osmdata (const std::string& st)
{
#ifdef DUMP_INPUT
    {
        std::ofstream dump ("./get-polygons.xml");
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
    float xmin = FLOAT_MAX, xmax = -FLOAT_MAX,
          ymin = FLOAT_MAX, ymax = -FLOAT_MAX;
    // TODO: Calculate these from nodes only
    std::vector <float> lons, lats;
    std::unordered_set <std::string> idset; // see TODO below
    std::vector <std::string> colnames, rownames, polynames;
    std::set <std::string> varnames;
    Rcpp::List dimnames (0), dummy_list (0);
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
     **                       STEP#3A: POLYGONAL WAYS                      **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    Rcpp::Environment sp_env = Rcpp::Environment::namespace_env ("sp");
    Rcpp::Function Polygon = sp_env ["Polygon"];
    Rcpp::Language polygons_call ("new", "Polygons");
    Rcpp::S4 polygons;

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

        if (n > 0)
        {
            xmin = std::min (xmin, *std::min_element (lons.begin(), lons.end()));
            xmax = std::max (xmax, *std::max_element (lons.begin(), lons.end()));
            ymin = std::min (ymin, *std::min_element (lats.begin(), lats.end()));
            ymax = std::max (ymax, *std::max_element (lats.begin(), lats.end()));
        }

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
        polygons.slot ("ID") = id;
        polyList [count++] = polygons;

        dummy_list.erase (0);
    } // end for it over poly_ways
    polyList.attr ("names") = polynames;

    // Store all key-val pairs in one massive DF
    int nrow = poly_ways.size (), ncol = varnames.size ();
    Rcpp::CharacterVector kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na ());
    int namecoli = std::distance (varnames.begin (), varnames.find ("name"));
    int typecoli = std::distance (varnames.begin (), varnames.find ("type"));
    int onewaycoli = std::distance (varnames.begin (), varnames.find ("oneway"));
    for (auto it = poly_ways.begin (); it != poly_ways.end (); ++it)
    {
        int rowi = std::distance (poly_ways.begin (), it);
        auto itw = ways.find (*it);
        kv_vec (namecoli * nrow + rowi) = itw->second.name;
        kv_vec (typecoli * nrow + rowi) = itw->second.type;

        if (itw->second.oneway)
            kv_vec (onewaycoli * nrow + rowi) = "true";
        else
            kv_vec (onewaycoli * nrow + rowi) = "false";

        for (auto kv_iter = itw->second.key_val.begin ();
                kv_iter != itw->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto ni = varnames.find (key); // key must exist in varnames!
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

    Rcpp::List ret (3);
    ret [0] = sp_polys;

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                     STEP#3B: NON-POLYGONAL WAYS                    **
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

    Rcpp::Language line_call ("new", "Line");
    Rcpp::Language lines_call ("new", "Lines");
    Rcpp::S4 line;
    Rcpp::S4 lines;

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

        if (n > 0)
        {
            xmin = std::min (xmin, *std::min_element (lons.begin(), lons.end()));
            xmax = std::max (xmax, *std::max_element (lons.begin(), lons.end()));
            ymin = std::min (ymin, *std::min_element (lats.begin(), lats.end()));
            ymax = std::max (ymax, *std::max_element (lats.begin(), lats.end()));
        }

        nmat2 = Rcpp::NumericMatrix (Rcpp::Dimension (lons.size (), 2));
        std::copy (lons.begin (), lons.end (), nmat2.begin ());
        std::copy (lats.begin (), lats.end (), nmat2.begin () + lons.size ());

        // This only works with push_back, not with direct re-allocation
        dimnames.push_back (rownames);
        dimnames.push_back (colnames);
        nmat2.attr ("dimnames") = dimnames;
        dimnames.erase (0, dimnames.size());

        // sp::Line and sp::Lines objects can be constructed directly from the
        // data with the following two lines, but this is *enormously* slower:
        //Rcpp::S4 line = Rcpp::Language ("Line", nmat).eval ();
        //Rcpp::S4 lines = Rcpp::Language ("Lines", line, id).eval ();
        // This way of constructing "new" objects and feeding slots is much
        // faster:
        line = line_call.eval ();
        line.slot ("coords") = nmat2;
        dummy_list.push_back (line);
        lines = lines_call.eval ();
        lines.slot ("Lines") = dummy_list;
        lines.slot ("ID") = id;
        lineList [count++] = lines;

        dummy_list.erase (0);
    } // end for it over non_poly_ways
    lineList.attr ("names") = linenames;

    // Store all key-val pairs in one massive DF
    nrow = non_poly_ways.size (); 
    ncol = varnames.size ();
    Rcpp::CharacterVector kv_vec2 (nrow * ncol, Rcpp::CharacterVector::get_na ());
    namecoli = std::distance (varnames.begin (), varnames.find ("name"));
    typecoli = std::distance (varnames.begin (), varnames.find ("type"));
    onewaycoli = std::distance (varnames.begin (), varnames.find ("oneway"));
    for (auto it = non_poly_ways.begin (); it != non_poly_ways.end (); ++it)
    {
        int rowi = std::distance (non_poly_ways.begin (), it);
        auto itw = ways.find (*it);
        kv_vec2 (namecoli * nrow + rowi) = itw->second.name;
        kv_vec2 (typecoli * nrow + rowi) = itw->second.type;
        //rowi = std::distance (non_poly_ways.begin (), it);
        //kv_vec2 (namecoli * nrow + rowi) = it->second.name;

        if (itw->second.oneway)
            kv_vec2 (onewaycoli * nrow + rowi) = "true";
        else
            kv_vec2 (onewaycoli * nrow + rowi) = "false";

        for (auto kv_iter = itw->second.key_val.begin ();
                kv_iter != itw->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto ni = varnames.find (key); // key must exist in varnames!
            int coli = std::distance (varnames.begin (), ni);
            kv_vec2 (coli * nrow + rowi) = (*kv_iter).second;
        }
    }

    Rcpp::Language sp_lines_call ("new", "SpatialLinesDataFrame");
    Rcpp::S4 sp_lines;
    sp_lines = sp_lines_call.eval ();
    sp_lines.slot ("lines") = lineList;

    sp_lines.slot ("bbox") = rcpp_get_bbox (xmin, xmax, ymin, ymax);
    sp_lines.slot ("proj4string") = crs; // already defined for polys

    Rcpp::CharacterMatrix kv_mat2 (nrow, ncol, kv_vec2.begin());
    Rcpp::DataFrame kv_df2 = kv_mat2;
    kv_df2.attr ("names") = varnames;
    sp_lines.slot ("data") = kv_df2;

    ret [1] = sp_lines;
    
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

    if (nodes.size () > 0)
    {
        xmin = std::min (xmin, *std::min_element (lons.begin(), lons.end()));
        xmax = std::max (xmax, *std::max_element (lons.begin(), lons.end()));
        ymin = std::min (ymin, *std::min_element (lats.begin(), lats.end()));
        ymax = std::max (ymax, *std::max_element (lats.begin(), lats.end()));
    }


    // Store all key-val pairs in one massive DF
    nrow = nodes.size (); 
    ncol = varnames.size ();
    Rcpp::CharacterVector kv_vec3 (nrow * ncol, Rcpp::CharacterVector::get_na ());
    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        int rowi = std::distance (nodes.begin (), ni);
        for (auto kv_iter = ni->second.key_val.begin ();
                kv_iter != ni->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto it = varnames.find (key); // key must exist in varnames!
            int coli = std::distance (varnames.begin (), it);
            kv_vec3 (coli * nrow + rowi) = (*kv_iter).second;
        }
    }

    nmat3 = Rcpp::NumericMatrix (Rcpp::Dimension (lons.size (), 2));
    std::copy (lons.begin (), lons.end (), nmat3.begin ());
    std::copy (lats.begin (), lats.end (), nmat3.begin () + lons.size ());
    dimnames.push_back (rownames);
    dimnames.push_back (colnames);
    nmat3.attr ("dimnames") = dimnames;
    dimnames.erase (0, dimnames.size());

    Rcpp::CharacterMatrix kv_mat3 (nrow, ncol, kv_vec.begin());
    Rcpp::DataFrame kv_df3 = kv_mat3;
    kv_df3.attr ("names") = varnames;

    Rcpp::Language points_call ("new", "SpatialPoints");
    Rcpp::Language sp_points_call ("new", "SpatialPointsDataFrame");
    Rcpp::S4 sp_points;
    sp_points = sp_points_call.eval ();
    sp_points.slot ("data") = kv_df3;
    sp_points.slot ("coords") = nmat3;
    sp_points.slot ("bbox") = rcpp_get_bbox (xmin, xmax, ymin, ymax);
    sp_points.slot ("proj4string") = crs;

    ret [2] = sp_points;

    std::vector <std::string> retnames {"polygons", "lnes", "points"};
    ret.attr ("names") = retnames;
    
    return ret;
}
