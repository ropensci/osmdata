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
 *  Author:     Mark Padgham 
 *  E-Mail:     mark.padgham@email.com 
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

//' get_osm_nodes_sp
//'
//' Store OSM nodes as `sf::POINT` objects
//'
//' @param ptxy Pointer to Rcpp::List to hold the resultant geometries
//' @param kv_mat Pointer to Rcpp::DataFrame to hold key-value pairs
//' @param nodes Pointer to all nodes in data set
//' @param unique_vals pointer to all unique values (OSM IDs and keys) in data set
//' @param bbox Pointer to the bbox needed for `sf` construction
//' @param crs Pointer to the crs needed for `sf` construction
//' 
//' @noRd 
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


//' get_osm_ways_sp
//'
//' Store OSM ways as `sf::LINESTRING` or `sf::POLYGON` objects.
//'
//' @param wayList Pointer to Rcpp::List to hold the resultant geometries
//' @param kv_df Pointer to Rcpp::DataFrame to hold key-value pairs
//' @param way_ids Vector of <osmid_t> IDs of ways to trace
//' @param ways Pointer to all ways in data set
//' @param nodes Pointer to all nodes in data set
//' @param unique_vals pointer to all unique values (OSM IDs and keys) in data set
//' @param geom_type Character string specifying "POLYGON" or "LINESTRING"
//' @param bbox Pointer to the bbox needed for `sf` construction
//' @param crs Pointer to the crs needed for `sf` construction
//' 
//' @noRd 
void get_osm_ways_sp (Rcpp::S4 &sp_ways, 
        const std::set <osmid_t> way_ids, const Ways &ways, const Nodes &nodes,
        const UniqueVals &unique_vals, const std::string &geom_type)
{
    if (!(geom_type == "line" || geom_type == "polygon"))
        throw std::runtime_error ("geom_type must be line or polygon");

    Rcpp::List wayList (way_ids.size ());

    size_t nrow = way_ids.size (), ncol = unique_vals.k_way.size ();
    std::vector <std::string> waynames;
    waynames.reserve (way_ids.size ());

    Rcpp::Language line_call ("new", "Line");
    Rcpp::Language lines_call ("new", "Lines");
    Rcpp::Environment sp_env = Rcpp::Environment::namespace_env ("sp");
    Rcpp::Function Polygon = sp_env ["Polygon"];
    Rcpp::Language polygons_call ("new", "Polygons");
    Rcpp::S4 polygons, line, lines;

    // index of ill-formed polygons later removed - see issue#85
    std::vector <unsigned int> indx_out;
    std::vector <bool> poly_okay (nrow);

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);
    for (auto wi = way_ids.begin (); wi != way_ids.end (); ++wi)
    {
        waynames.push_back (std::to_string (*wi));
        Rcpp::NumericMatrix nmat;
        trace_way_nmat (ways, nodes, (*wi), nmat);
        Rcpp::List dummy_list (0);
        int pos = std::distance (way_ids.begin (), wi);
        poly_okay [pos] = true;
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
            if (nmat.nrow () == 3 && nmat (0, 0) == nmat (2, 0) &&
                    nmat (0, 1) == nmat (2, 1))
            {
                // polygon has only 3 rows with start == end, so is ill-formed
                indx_out.push_back (pos);
                poly_okay [pos] = false;
                // temp copy with > 3 rows necessary to suppress sp warning
                Rcpp::NumericMatrix nmat2 =
                    Rcpp::NumericMatrix (Rcpp::Dimension (4, 2));
                nmat = nmat2;
            }

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
    if (indx_out.size () > 0)
    {
        std::reverse (indx_out.begin (), indx_out.end ());
        for (auto i: indx_out)
        {
            wayList.erase (i);
            waynames.erase (waynames.begin () + i);
        }
    }
    wayList.attr ("names") = waynames;

    // Reduce kv_mat to indx_in
    if (indx_out.size () > 0)
    {
        size_t n_okay = nrow - indx_out.size ();
        Rcpp::CharacterMatrix kv_mat2 (Rcpp::Dimension (n_okay, ncol));
        std::fill (kv_mat2.begin (), kv_mat2.end (), NA_STRING);
        int pos = 0;
        for (size_t i = 0; i<nrow; i++)
        {
            if (poly_okay [i])
                kv_mat2 (pos++, Rcpp::_) = kv_mat (i, Rcpp::_);
        }
        kv_mat = kv_mat2;
    }

    Rcpp::DataFrame kv_df;
    if (way_ids.size () > 0)
    {
        kv_mat.attr ("names") = unique_vals.k_way;
        kv_mat.attr ("dimnames") = Rcpp::List::create (waynames, unique_vals.k_way);
        kv_df = kv_mat;
        // TODO: Can names be assigned to R_NilValue?
        kv_df.attr ("names") = unique_vals.k_way;
    } else
        kv_df = R_NilValue;

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
        for (unsigned int i=0; i<nrow; i++) plord.push_back (i + 1);
        sp_ways.slot ("plotOrder") = plord;
        plord.clear ();
        sp_ways.slot ("data") = kv_df;
    }
}


//' get_osm_relations_sp
//'
//' Return a dual Rcpp::List containing all OSM relations, the firmt element of
//' which holds `multipolygon` relations, while the second holds all others,
//' which are stored as `multilinestring` objects.
//'
//' @param rels Pointer to the vector of Relation objects
//' @param nodes Pointer to the vector of node objects
//' @param ways Pointer to the vector of way objects
//' @param unique_vals Pointer to a UniqueVals object containing std::sets of all
//'        unique IDs and keys for each kind of OSM object (nodes, ways, rels).
//'
//' @return A dual Rcpp::List, the first of which contains the multipolygon
//'         relations; the second the multilinestring relations.
//' 
//' @noRd 
void get_osm_relations_sp (Rcpp::S4 &multilines, Rcpp::S4 &multipolygons, 
        const Relations &rels, const std::map <osmid_t, Node> &nodes,
        const std::map <osmid_t, OneWay> &ways, const UniqueVals &unique_vals)
{
    /* Trace all multipolygon relations. These are the only OSM types where
     * sizes are not known before, so lat-lons and node names are stored in
     * dynamic vectors. These are 3D monsters: #1 for relation, #2 for polygon
     * in relation, and #3 for data. There are also associated 2D vector<vector>
     * objects for IDs and multilinestring roles. */
    std::set <std::string> keyset; // must be ordered!
    std::vector <std::string> colnames = {"lat", "lon"}, rownames;
    Rcpp::List dimnames (0);
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    float_arr2 lat_vec, lon_vec;
    float_arr3 lat_arr_mp, lon_arr_mp, lon_arr_ls, lat_arr_ls;
    string_arr2 rowname_vec, id_vec_mp, roles_ls; 
    string_arr3 rowname_arr_mp, rowname_arr_ls;
    std::vector <osmid_t> ids_ls; 
    std::vector <std::string> ids_mp, rel_id_mp, rel_id_ls; 
    osmt_arr2 id_vec_ls;
    std::vector <std::string> roles;

    int nmp = 0, nls = 0; // number of multipolygon and multilinestringrelations
    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
    {
        if (itr->ispoly) 
            nmp++;
        else
        {
            // TODO: Store these as std::vector <std::set <>> to avoid
            // repetition below
            std::set <std::string> roles_set;
            for (auto itw = itr->ways.begin (); itw != itr->ways.end (); ++itw)
                roles_set.insert (itw->second);
            nls += roles_set.size ();
        }
    }

    int ncol = unique_vals.k_rel.size ();
    rel_id_mp.reserve (nmp);
    rel_id_ls.reserve (nls);

    Rcpp::CharacterMatrix kv_mat_mp (Rcpp::Dimension (nmp, ncol)),
        kv_mat_ls (Rcpp::Dimension (nls, ncol));
    int count_mp = 0, count_ls = 0;

    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
    {
        if (itr->ispoly) // itr->second can only be "outer" or "inner"
        {
            trace_multipolygon (itr, ways, nodes, lon_vec, lat_vec,
                    rowname_vec, ids_mp);
            // Store all ways in that relation and their associated roles
            rel_id_mp.push_back (std::to_string (itr->id));
            lon_arr_mp.push_back (lon_vec);
            lat_arr_mp.push_back (lat_vec);
            rowname_arr_mp.push_back (rowname_vec);
            id_vec_mp.push_back (ids_mp);
            clean_vecs <float, float, std::string> (lon_vec, lat_vec, rowname_vec);
            ids_mp.clear ();
            if (nmp > 0)
                get_value_mat_rel (itr, rels, unique_vals, kv_mat_mp, count_mp++);
        } else // store as multilinestring
        {
            // multistrings are grouped here by roles, unlike GDAL which just
            // dumps all of them.
            std::set <std::string> roles_set;
            for (auto itw = itr->ways.begin (); itw != itr->ways.end (); ++itw)
                roles_set.insert (itw->second);
            roles.reserve (roles_set.size ());
            for (auto it = roles_set.begin (); it != roles_set.end (); ++it)
                roles.push_back (*it);
            roles_set.clear ();
            for (std::string role: roles)
            {
                trace_multilinestring (itr, role, ways, nodes, 
                        lon_vec, lat_vec, rowname_vec, ids_ls);
                std::stringstream ss;
                ss.str ("");
                if (role == "")
                    ss << std::to_string (itr->id) << "-(no role)";
                else
                    ss << std::to_string (itr->id) << "-" << role;
                rel_id_ls.push_back (ss.str ());
                lon_arr_ls.push_back (lon_vec);
                lat_arr_ls.push_back (lat_vec);
                rowname_arr_ls.push_back (rowname_vec);
                id_vec_ls.push_back (ids_ls);
                clean_vecs <float, float, std::string> (lon_vec, lat_vec, rowname_vec);
                ids_ls.clear ();
                if (nls > 0)
                    get_value_mat_rel (itr, rels, unique_vals, kv_mat_ls, count_ls++);
            }
            roles_ls.push_back (roles);
            roles.clear ();
        }
    }

    convert_multipoly_to_sp (multipolygons, rels, lon_arr_mp, lat_arr_mp, 
        rowname_arr_mp, id_vec_mp, unique_vals);
    convert_multiline_to_sp (multilines, rels, lon_arr_ls, lat_arr_ls, 
        rowname_arr_ls, id_vec_ls, unique_vals);

    // ****** clean up *****
    clean_arrs <float, float, std::string> (lon_arr_mp, lat_arr_mp, rowname_arr_mp);
    clean_arrs <float, float, std::string> (lon_arr_ls, lat_arr_ls, rowname_arr_ls);
    clean_vecs <std::string, osmid_t> (id_vec_mp, id_vec_ls);
    rel_id_mp.clear ();
    rel_id_ls.clear ();
    roles_ls.clear ();
    keyset.clear ();
}


// [[Rcpp::depends(sp)]]

//' rcpp_osmdata_sp
//'
//' Extracts all polygons from an overpass API query
//'
//' @param st Text contents of an overpass API query
//' @return A \code{SpatialLinesDataFrame} contains all polygons and associated data
//' 
//' @noRd 
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


    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                           PRE-PROCESSING                           **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    // Step#2
    std::set <osmid_t> poly_ways, non_poly_ways;
    for (auto itw = ways.begin (); itw != ways.end (); ++itw)
    {
        if ((*itw).second.nodes.front () == (*itw).second.nodes.back ())
        {
            if (poly_ways.find ((*itw).first) == poly_ways.end ())
                poly_ways.insert ((*itw).first);
        } else if (non_poly_ways.find ((*itw).first) == non_poly_ways.end ())
            non_poly_ways.insert ((*itw).first);
    }

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                            GET OSM DATA                            **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    // The actual routines to extract the OSM data and store in sp objects
    Rcpp::S4 sp_points, sp_lines, sp_polygons, sp_multilines, sp_multipolygons;
    get_osm_ways_sp (sp_polygons, poly_ways, ways, nodes, unique_vals, "polygon");
    get_osm_ways_sp (sp_lines, non_poly_ways, ways, nodes, unique_vals, "line");
    get_osm_nodes_sp (sp_points, nodes, unique_vals);
    get_osm_relations_sp (sp_multilines, sp_multipolygons, 
            rels, nodes, ways, unique_vals);

    // Add bbox and crs to each sp object
    Rcpp::NumericMatrix bbox = rcpp_get_bbox (xml.x_min (), xml.x_max (), 
                                              xml.y_min (), xml.y_max ());
    sp_points.slot ("bbox") = bbox;
    sp_lines.slot ("bbox") = bbox;
    sp_polygons.slot ("bbox") = bbox;
    sp_multilines.slot ("bbox") = bbox;
    sp_multipolygons.slot ("bbox") = bbox;

    Rcpp::Language crs_call ("new", "CRS");
    Rcpp::S4 crs = crs_call.eval ();
    crs.slot ("projargs") = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0";
    sp_points.slot ("proj4string") = crs;
    sp_lines.slot ("proj4string") = crs; 
    sp_polygons.slot ("proj4string") = crs;
    sp_multilines.slot ("proj4string") = crs;
    sp_multipolygons.slot ("proj4string") = crs;

    Rcpp::List ret (6);
    ret [0] = bbox;
    ret [1] = sp_points;
    ret [2] = sp_lines;
    ret [3] = sp_polygons;
    ret [4] = sp_multilines;
    ret [5] = sp_multipolygons;

    std::vector <std::string> retnames {"bbox", "points", "lines", "polygons",
        "multilines", "multipolygons"};
    ret.attr ("names") = retnames;
    
    return ret;
}
