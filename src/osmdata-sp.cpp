/***************************************************************************
 *  Project:    osmdata
 *  File:       osmdata-sp.cpp
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
 *                  it in R 'sp' format.
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#include "osmdata.h"

#include <Rcpp.h>

#include <algorithm> // for min_element/max_element

/* get_osm_nodes_sp
 *
 * Store OSM nodes as `sf::POINT` objects
 *
 * @param ptxy Pointer to Rcpp::List to hold the resultant geometries
 * @param kv_mat Pointer to Rcpp::DataFrame to hold key-value pairs
 * @param nodes Pointer to all nodes in data set
 * @param unique_vals pointer to all unique values (OSM IDs and keys) in data set
 * @param bbox Pointer to the bbox needed for `sf` construction
 * @param crs Pointer to the crs needed for `sf` construction
 */
void get_osm_nodes_sp (Rcpp::S4 &sp_points, const Nodes &nodes, 
        const UniqueVals &unique_vals)
{
    Rcpp::NumericMatrix ptxy; 
    Rcpp::CharacterMatrix kv_mat;
    int nrow = nodes.size (), ncol = unique_vals.k_point.size ();

    kv_mat = Rcpp::CharacterMatrix (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);

    ptxy = Rcpp::NumericMatrix (Rcpp::Dimension (nrow, 2));
    std::vector <std::string> ptnames;
    ptnames.reserve (nodes.size ());
    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        int pos = std::distance (nodes.begin (), ni);
        ptxy (pos, 0) = ni->second.lon;
        ptxy (pos, 1) = ni->second.lat;
        ptnames.push_back (std::to_string (ni->first));
        for (auto kv_iter = ni->second.key_val.begin ();
                kv_iter != ni->second.key_val.end (); ++kv_iter)
        {
            const std::string &key = kv_iter->first;
            int ni = std::distance (unique_vals.k_point.begin (),
                    unique_vals.k_point.find (key));
            kv_mat (pos, ni) = kv_iter->second;
        }
    }
    std::vector <std::string> colnames = {"lon", "lat"};
    Rcpp::List dimnames (0);
    dimnames.push_back (ptnames);
    dimnames.push_back (colnames);
    ptxy.attr ("dimnames") = dimnames;
    dimnames.erase (0, dimnames.size ());

    kv_mat.attr ("dimnames") = Rcpp::List::create (ptnames, unique_vals.k_point);

    Rcpp::DataFrame kv_df= kv_mat;
    kv_df.attr ("names") = unique_vals.k_point;

    Rcpp::Language points_call ("new", "SpatialPoints");
    Rcpp::Language sp_points_call ("new", "SpatialPointsDataFrame");
    sp_points = sp_points_call.eval ();
    sp_points.slot ("data") = kv_df;
    sp_points.slot ("coords") = ptxy;
}


/* get_osm_ways_sp
 *
 * Store OSM ways as `sf::LINESTRING` or `sf::POLYGON` objects.
 *
 * @param wayList Pointer to Rcpp::List to hold the resultant geometries
 * @param kv_df Pointer to Rcpp::DataFrame to hold key-value pairs
 * @param way_ids Vector of <osmid_t> IDs of ways to trace
 * @param ways Pointer to all ways in data set
 * @param nodes Pointer to all nodes in data set
 * @param unique_vals pointer to all unique values (OSM IDs and keys) in data set
 * @param geom_type Character string specifying "POLYGON" or "LINESTRING"
 * @param bbox Pointer to the bbox needed for `sf` construction
 * @param crs Pointer to the crs needed for `sf` construction
 */
void get_osm_ways_sp (Rcpp::S4 &sp_ways, 
        const std::set <osmid_t> way_ids, const Ways &ways, const Nodes &nodes,
        const UniqueVals &unique_vals, const std::string &geom_type)
{
    if (!(geom_type == "line" || geom_type == "polygon"))
        throw std::runtime_error ("geom_type must be line or polygon");

    Rcpp::List wayList (way_ids.size ());

    int nrow = way_ids.size (), ncol = unique_vals.k_way.size ();
    std::vector <std::string> waynames;
    waynames.reserve (way_ids.size ());

    Rcpp::Language line_call ("new", "Line");
    Rcpp::Language lines_call ("new", "Lines");
    Rcpp::Environment sp_env = Rcpp::Environment::namespace_env ("sp");
    Rcpp::Function Polygon = sp_env ["Polygon"];
    Rcpp::Language polygons_call ("new", "Polygons");
    Rcpp::S4 polygons, line, lines;

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);
    for (auto wi = way_ids.begin (); wi != way_ids.end (); ++wi)
    {
        waynames.push_back (std::to_string (*wi));
        Rcpp::NumericMatrix nmat;
        trace_way_nmat (ways, nodes, (*wi), nmat);
        Rcpp::List dummy_list (0);
        int pos = std::distance (way_ids.begin (), wi);
        if (geom_type == "line")
        {
            // sp::Line and sp::Lines objects can be constructed directly from
            // the data with the following two lines, but this is *enormously*
            // slower:
            // Rcpp::S4 line = Rcpp::Language ("Line", nmat).eval ();
            // Rcpp::S4 lines = Rcpp::Language ("Lines", line, id).eval ();
            // This way of constructing "new" objects and feeding slots is much
            // faster:
            line = line_call.eval ();
            line.slot ("coords") = nmat;
            dummy_list.push_back (line);
            lines = lines_call.eval ();
            lines.slot ("Lines") = dummy_list;
            lines.slot ("ID") = (*wi);
            wayList [pos] = lines;
        } else 
        {
            Rcpp::S4 poly = Polygon (nmat);
            poly.slot ("hole") = false;
            poly.slot ("ringDir") = (int) 1;
            dummy_list.push_back (poly);
            polygons = polygons_call.eval ();
            polygons.slot ("Polygons") = dummy_list;
            polygons.slot ("ID") = (*wi);
            polygons.slot ("plotOrder") = (int) 1;
            polygons.slot ("labpt") = poly.slot ("labpt");
            polygons.slot ("area") = poly.slot ("area");
            wayList [pos] = polygons;
        }
        dummy_list.erase (0);
        auto wj = ways.find (*wi);
        get_value_mat_way (wj, ways, unique_vals, kv_mat, pos);
    } // end for it over poly_ways
    wayList.attr ("names") = waynames;

    kv_mat.attr ("names") = unique_vals.k_way;
    kv_mat.attr ("dimnames") = Rcpp::List::create (waynames, unique_vals.k_way);
    Rcpp::DataFrame kv_df = kv_mat;
    kv_df.attr ("names") = unique_vals.k_way;

    if (geom_type == "line")
    {
        Rcpp::Language sp_lines_call ("new", "SpatialLinesDataFrame");
        sp_ways = sp_lines_call.eval ();
        sp_ways.slot ("lines") = wayList;
        sp_ways.slot ("data") = kv_df;
    } else
    {
        Rcpp::Language sp_polys_call ("new", "SpatialPolygonsDataFrame");
        sp_ways = sp_polys_call.eval ();
        sp_ways.slot ("polygons") = wayList;
        // Fill plotOrder slot with numeric vector
        std::vector <int> plord;
        for (int i=0; i<nrow; i++) plord.push_back (i + 1);
        sp_ways.slot ("plotOrder") = plord;
        plord.clear ();
        sp_ways.slot ("data") = kv_df;
    }
}


// [[Rcpp::depends(sp)]]

//' rcpp_osmdata_sp
//'
//' Extracts all polygons from an overpass API query
//'
//' @param st Text contents of an overpass API query
//' @return A \code{SpatialLinesDataFrame} contains all polygons and associated data
// [[Rcpp::export]]
Rcpp::List rcpp_osmdata_sp (const std::string& st)
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

    std::set <osmid_t> poly_ways, non_poly_ways;


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
            if (ways.find (itw->first) == ways.end ())
                throw std::runtime_error ("way can not be found");
            poly_ways.insert (itw->first);
        }

    // Step#2
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
    // TODO: Insert this back in sf version?
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
     **                            GET OSM DATA                            **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    // The actual routines to extract the OSM data and store in sp objects
    Rcpp::S4 sp_points, sp_lines, sp_polys;
    get_osm_ways_sp (sp_polys, poly_ways, ways, nodes, unique_vals, "polygon");
    get_osm_ways_sp (sp_lines, poly_ways, ways, nodes, unique_vals, "line");
    get_osm_nodes_sp (sp_points, nodes, unique_vals);

    // Add bbox and crs to each sp object
    Rcpp::NumericMatrix bbox = rcpp_get_bbox (xml.x_min (), xml.x_max (), 
                                              xml.y_min (), xml.y_max ());
    sp_points.slot ("bbox") = bbox;
    sp_lines.slot ("bbox") = bbox;
    sp_polys.slot ("bbox") = bbox;

    Rcpp::Language crs_call ("new", "CRS");
    Rcpp::S4 crs = crs_call.eval ();
    crs.slot ("projargs") = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0";
    sp_points.slot ("proj4string") = crs;
    sp_lines.slot ("proj4string") = crs; 
    sp_polys.slot ("proj4string") = crs;

    Rcpp::List ret (3);
    ret [0] = sp_points;
    ret [1] = sp_lines;
    ret [2] = sp_polys;

    std::vector <std::string> retnames {"points", "lines", "polygons"};
    ret.attr ("names") = retnames;
    
    return ret;
}
