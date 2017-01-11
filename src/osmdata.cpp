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
    const UniqueVals unique_vals = xml.unique_vals ();

    int count = 0;
    std::vector <float> lons, lats;
    std::unordered_set <std::string> idset; // see TODO below
    std::vector <std::string> colnames, rownames, polynames;
    std::set <std::string> varnames;
    std::vector <std::string> varnames_vec;
    Rcpp::List dimnames (0);
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    idset.clear ();

    colnames.push_back ("lon");
    colnames.push_back ("lat");

    // non_poly_ways are returned as line objects
    std::set <osmid_t> poly_ways, non_poly_ways;

    Rcpp::List crs = Rcpp::List::create ((int) 4326, p4s);
    crs.attr ("class") = "crs";
    crs.attr ("names") = Rcpp::CharacterVector::create ("epsg", "proj4string");

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

    // Step#1: insert all rels into poly_ways
    for (auto it = rels.begin (); it != rels.end (); ++it)
        for (auto itw = (*it).ways.begin (); itw != (*it).ways.end (); ++itw)
        {
            if (ways.find (itw->first) == ways.end ())
                throw std::runtime_error ("way can not be found");
            poly_ways.insert (itw->first);
        }

    // Step#2: identify and store poly and non_poly ways
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

    Rcpp::NumericVector bbox = rcpp_get_bbox_sf (xml.x_min (), xml.x_max (), 
                                              xml.y_min (), xml.y_max ());

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
            if (nodes.find (*itn) == nodes.end ())
                throw std::runtime_error ("node can not be found");
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
    for (auto it = poly_ways.begin (); it != poly_ways.end (); ++it)
    {
        int rowi = std::distance (poly_ways.begin (), it);
        auto itw = ways.find (*it);

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

    varnames_vec.resize (0);
    varnames_vec.push_back ("lon");
    varnames_vec.push_back ("lat");
    for (const auto& i: unique_vals.k_line)
        varnames_vec.push_back (i);

    idset.clear ();
    dimnames.erase (0, dimnames.size());
    Rcpp::NumericMatrix nmat2 (Rcpp::Dimension (0, 0)); 
    // TODO: Things to delete and replace with resize:
    // nmat2, kv_vec2, kv_mat2, kv_df2
    // nmat3, kv_vec3, kv_mat3, kv_df3

    count = 0;
    // Store all key-val pairs in one massive DF
    nrow = non_poly_ways.size (); 
    ncol = unique_vals.k_line.size ();
    Rcpp::CharacterVector line_kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na ());
    for (auto it = non_poly_ways.begin (); it != non_poly_ways.end (); ++it)
    {
        auto itw = ways.find (*it);
        linenames.push_back (std::to_string (itw->first));
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
            if (nodes.find (*itn) == nodes.end ())
                throw std::runtime_error ("node can not be found");
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

        int rowi = std::distance (non_poly_ways.begin (), it);
        for (auto kv_iter = itw->second.key_val.begin ();
                kv_iter != itw->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto ni = unique_vals.k_line.find (key); // key must exist!
            int coli = std::distance (unique_vals.k_line.begin (), ni);
            line_kv_vec (coli * nrow + rowi) = (*kv_iter).second;
        }
    } // end for it over non_poly_ways
    lineList.attr ("names") = linenames;

    Rcpp::CharacterMatrix line_kv_mat (nrow, ncol, line_kv_vec.begin());
    Rcpp::DataFrame line_kv_df = line_kv_mat;
    line_kv_df.attr ("names") = unique_vals.k_line;

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                          STEP#3C: POINTS                           **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    Rcpp::CharacterMatrix kv_mat_points (Rcpp::Dimension (nodes.size (),
                unique_vals.k_point.size ()));
    std::fill (kv_mat_points.begin (), kv_mat_points.end (), NA_STRING);

    Rcpp::List pointList (nodes.size ());
    std::vector <std::string> ptnames;
    ptnames.reserve (nodes.size ());
    count = 0;
    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        Rcpp::NumericVector ptxy = Rcpp::NumericVector::create (NA_REAL, NA_REAL);
        ptxy.attr ("class") = Rcpp::CharacterVector::create ("XY", "POINT", "sfg");
        ptxy (0) = ni->second.lon;
        ptxy (1) = ni->second.lat;
        pointList (count++) = ptxy;
        ptnames.push_back (std::to_string (ni->first));
        for (auto kv_iter = ni->second.key_val.begin ();
                kv_iter != ni->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto it = unique_vals.k_point.find (key);
            int ni = std::distance (unique_vals.k_point.begin (), it);
            kv_mat_points (count, ni) = (*kv_iter).second;
        }
    }
    kv_mat_points.attr ("dimnames") = Rcpp::List::create (ptnames, unique_vals.k_point);

    pointList.attr ("names") = ptnames;
    ptnames.clear ();
    pointList.attr ("n_empty") = 0;
    pointList.attr ("class") = Rcpp::CharacterVector::create ("sfc_POINT", "sfc");
    pointList.attr ("precision") = 0.0;
    pointList.attr ("bbox") = bbox;
    pointList.attr ("crs") = crs;

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                      STEP#4: COLLATE ALL DATA                      **
     **                                                                    **
     ************************************************************************
     ************************************************************************/


    Rcpp::List ret (6);
    //ret [0] = bbox;
    ret [0] = pointList;
    ret [1] = kv_mat_points;
    ret [2] = lineList;
    ret [3] = line_kv_df;
    ret [4] = polyList;
    ret [5] = poly_kv_df;

    //std::vector <std::string> retnames {"bbox", "points", 
    //    "lines", "lines_kv", "polygons", "polygons_kv"};
    std::vector <std::string> retnames {"points", "points_kv",
        "lines", "lines_kv", "polygons", "polygons_kv"};
    ret.attr ("names") = retnames;
    
    return ret;
}
