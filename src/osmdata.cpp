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

// Note: roxygen attempts to import doxygen-style comments, even without the
// doubule-square-bracket Rcpp::Export

/************************************************************************
 ************************************************************************
 **                                                                    **
 **           PRIMARY FUNCTIONS TO TRACE WAYS AND RELATIONS            **
 **                                                                    **
 ************************************************************************
 ************************************************************************/


/* Traces a single multipolygon relation 
 * 
 * @param itr_rel iterator to XmlData::Relations structure
 * @param &ways pointer to Ways structure
 * @param &nodes pointer to Nodes structure
 * @param &lon_vec pointer to 2D array of longitudes
 * @param &lat_vec pointer to 2D array of latitutdes
 * @param &rowname_vec pointer to 2D array of rownames for each node.
 * @param &id_vec pointer to 2D array of OSM IDs for each way in relation
 */
void trace_multipolygon (Relations::const_iterator itr_rel, const Ways &ways,
        const Nodes &nodes, float_arr2 &lon_vec, float_arr2 &lat_vec,
        string_arr2 &rowname_vec, std::vector <std::string> &ids)
{
    bool closed, ptr_check;
    osmid_t node0, first_node, last_node;
    std::string this_role;
    std::stringstream this_way;
    std::vector <float> lons, lats;
    std::vector <std::string> rownames, wayname_vec;

    osm_str_vec relation_ways;
    for (auto itw = itr_rel->ways.begin (); itw != itr_rel->ways.end (); ++itw)
        relation_ways.push_back (std::make_pair (itw->first, itw->second));
    it_osm_str_vec itr_rw;

    // Then trace through all those ways and store associated data
    while (relation_ways.size () > 0)
    {
        auto rwi = relation_ways.begin ();
        //ids.push_back (rwi->first);
        relation_ways.erase (rwi);
        this_role = rwi->second;
        auto wayi = ways.find (rwi->first);
        if (wayi == ways.end ())
            throw std::runtime_error ("way can not be found");
        this_way.str ("");
        this_way << std::to_string (rwi->first);

        // Get first way of relation, and starting node
        node0 = wayi->second.nodes.front ();
        last_node = trace_way (ways, nodes, node0,
                wayi->first, lons, lats, rownames);
        //ids.push_back (wayi->first);
        closed = false;
        if (last_node == node0)
            closed = true;
        while (!closed)
        {
            first_node = last_node;
            ptr_check = false;
            for (auto itw = relation_ways.begin ();
                    itw != relation_ways.end (); ++itw)
            {
                if (itw->second == this_role)
                {
                    auto wayi = ways.find (itw->first);
                    if (wayi == ways.end ())
                        throw std::runtime_error ("way can not be found");
                    last_node = trace_way (ways, nodes, first_node,
                            wayi->first, lons, lats, rownames);
                    //ids.push_back (wayi->first);
                    this_way << "-" << std::to_string (wayi->first);
                    if (last_node >= 0)
                    {
                        first_node = last_node;
                        itr_rw = itw;
                        ptr_check = true;
                        break;
                    }
                }
            } // end for itw over relation_ways
            if (ptr_check)
                relation_ways.erase (itr_rw);
            else
                throw std::runtime_error ("pointer not assigned");
            if (last_node == node0 || relation_ways.size () == 0)
                closed = true;
        } // end while !closed
        if (last_node == node0)
        {
            lon_vec.push_back (lons);
            lat_vec.push_back (lats);
            rowname_vec.push_back (rownames);
            wayname_vec.push_back (this_way.str ());
        } else
            throw std::runtime_error ("last node != node0");
        lats.clear (); // These can't be reserved here
        lons.clear ();
        rownames.clear ();
        ids.push_back (this_way.str ());
    } // end while relation_ways.size == 0 - finished tracing relation
    wayname_vec.clear ();
}

/* Traces a single multilinestring relation 
 *
 *
 * GDAL does a simple dump of all ways as one multistring. osmdata creates one
 * multistring for each separate relation role, resulting in as many multistrings
 * as there are roles.
 *
 * @param itr_rel iterator to XmlData::Relations structure
 * @param role trace ways only matching this role in the relation
 * @param &ways pointer to Ways structure
 * @param &nodes pointer to Nodes structure
 * @param &lon_vec pointer to 2D array of longitudes
 * @param &lat_vec pointer to 2D array of latitutdes
 * @param &rowname_vec pointer to 2D array of rownames for each node.
 * @param &id_vec pointer to 2D array of OSM IDs for each way in relation
 */
void trace_multilinestring (Relations::const_iterator itr_rel, const std::string role,
        const Ways &ways, const Nodes &nodes, float_arr2 &lon_vec, 
        float_arr2 &lat_vec, string_arr2 &rowname_vec, std::vector <osmid_t> &ids)
{
    osmid_t first_node, last_node;
    std::vector <float> lons, lats;
    std::vector <std::string> rownames;

    osm_str_vec relation_ways;
    relation_ways.reserve (itr_rel->ways.size ());
    for (auto itw = itr_rel->ways.begin (); itw != itr_rel->ways.end (); ++itw)
        if (itw->second == role)
            relation_ways.push_back (std::make_pair (itw->first, itw->second));

    if (relation_ways.size () == 0)
        Rcpp::Rcout << "ERROR: no ways for REL#" << itr_rel->id << 
            " with role = " << role << std::endl;

    // Then trace through all those ways and store associated data
    while (relation_ways.size () > 0)
    {
        auto rwi = relation_ways.begin ();
        ids.push_back (rwi->first);
        relation_ways.erase (rwi);
        std::string this_role = rwi->second;
        auto wayi = ways.find (rwi->first);
        if (wayi == ways.end ())
            throw std::runtime_error ("way can not be found");

        osmid_t first_node = wayi->second.nodes.front ();
        osmid_t last_node = trace_way (ways, nodes, first_node, 
                wayi->first, lons, lats, rownames);

        lon_vec.push_back (lons);
        lat_vec.push_back (lats);
        rowname_vec.push_back (rownames);

        lons.clear ();
        lats.clear ();
        rownames.clear ();
    } // end while relation_ways.size > 0
}

/* Traces a single way and adds (lon,lat,rownames) to corresponding vectors
 *
 * @param &ways pointer to Ways structure
 * @param &nodes pointer to Nodes structure
 * @param first_node Last node of previous way to find in current
 * @param &wayi_id pointer to ID of current way
 * @param &ids pointer to vector of osm IDs for ways within a single
 *        multipolygon relation
 *        &lons pointer to vector of longitudes
 *        &lats pointer to vector of latitutdes
 *        &rownames pointer to vector of rownames for each node.
 *       
 *       n ID of final node in way, or a negative number if first_node does not
 *       within wayi_id
 */
osmid_t trace_way (const Ways &ways, const Nodes &nodes, osmid_t first_node,
        const osmid_t &wayi_id, std::vector <float> &lons, 
        std::vector <float> &lats, std::vector <std::string> &rownames)
{
    osmid_t last_node = -1;
    auto wayi = ways.find (wayi_id);
    std::vector <osmid_t>::const_iterator it_node_begin, it_node_end;

    // Alternative to the following is to pass iterators as .begin() or
    // .rbegin() to a std::for_each, but const Ways and Nodes cannot then
    // (easily) be passed to lambdas. TODO: Find a way
    if (wayi->second.nodes.front () == first_node)
    {
        for (auto ni = wayi->second.nodes.begin ();
                ni != wayi->second.nodes.end (); ++ni)
        {
            if (nodes.find (*ni) == nodes.end ())
                throw std::runtime_error ("node can not be found");
            lons.push_back (nodes.find (*ni)->second.lon);
            lats.push_back (nodes.find (*ni)->second.lat);
            rownames.push_back (std::to_string (*ni));
        }
        last_node = wayi->second.nodes.back ();
    } else if (wayi->second.nodes.back () == first_node)
    {
        for (auto ni = wayi->second.nodes.rbegin ();
                ni != wayi->second.nodes.rend (); ++ni)
        {
            if (nodes.find (*ni) == nodes.end ())
                throw std::runtime_error ("node can not be found");
            lons.push_back (nodes.find (*ni)->second.lon);
            lats.push_back (nodes.find (*ni)->second.lat);
            rownames.push_back (std::to_string (*ni));
        }
        last_node = wayi->second.nodes.front ();
    }

    return last_node;
}

// Extract vector of values from key-value pairs for a given relation
void get_value_vec (Relations::const_iterator itr, 
        const std::set <std::string> keyset, std::vector <std::string> &value_vec)
{
    for (auto v = itr->key_val.begin (); v != itr->key_val.end (); ++v)
    {
        int kv_pos = std::distance (keyset.begin (), keyset.find (v->first));
        value_vec [kv_pos] = v->second;
    }
}

/************************************************************************
 ************************************************************************
 **                                                                    **
 **               FUNCTIONS TO CHECK AND CLEAN C++ ARRAYS              **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

// Sanity check to ensure all 3D geometry arrays have same sizes
void check_geom_arrs (const float_arr3 &lon_arr, const float_arr3 &lat_arr,
        const string_arr3 &rowname_arr)
{
    if (lon_arr.size () != lat_arr.size () ||
            lon_arr.size () != rowname_arr.size ())
        throw std::runtime_error ("lons, lats, and rownames differ in size");
    for (int i=0; i<lon_arr.size (); i++)
    {
        if (lon_arr [i].size () != lat_arr [i].size () ||
                lon_arr [i].size () != rowname_arr [i].size ())
            throw std::runtime_error ("lons, lats, and rownames differ in size");
        for (int j=0; j<lon_arr [i].size (); j++)
            if (lon_arr [i][j].size () != lat_arr [i][j].size () ||
                    lon_arr [i][j].size () != rowname_arr [i][j].size ())
                throw std::runtime_error ("lons, lats, and rownames differ in size");
    }
}

// Clean all 2D geometry arrays 
void clean_geom_vecs (float_arr2 &lon_vec, float_arr2 &lat_vec,
        string_arr2 &rowname_vec)
{
    for (int i=0; i<lon_vec.size (); i++)
    {
        lon_vec [i].clear ();
        lat_vec [i].clear ();
        rowname_vec [i].clear ();
    }
    lon_vec.clear ();
    lat_vec.clear ();
    rowname_vec.clear ();
}

// Clean all 3D geometry arrays 
void clean_geom_arrs (float_arr3 &lon_arr, float_arr3 &lat_arr,
        string_arr3 &rowname_arr)
{
    for (int i=0; i<lon_arr.size (); i++)
    {
        for (int j=0; j<lon_arr [i].size (); j++)
        {
            lon_arr [i] [j].clear ();
            lat_arr [i] [j].clear ();
            rowname_arr [i] [j].clear ();
        }
        lon_arr [i].clear ();
        lat_arr [i].clear ();
        rowname_arr [i].clear ();
    }
    lon_arr.clear ();
    lat_arr.clear ();
    rowname_arr.clear ();
}

// Clean all key-value arrays
void clean_kv_arrs (std::vector <std::vector <std::string> > &value_arr_mp,
        std::vector <std::vector <std::string> > &value_arr_ls)
{
    for (int i=0; i<value_arr_mp.size (); i++)
        value_arr_mp [i].clear ();
    for (int i=0; i<value_arr_ls.size (); i++)
        value_arr_ls [i].clear ();
    value_arr_mp.clear ();
    value_arr_ls.clear ();
}

// Clean all arrays holding OSM IDs
void clear_id_vecs (std::vector <std::vector <osmid_t> > &id_vec_ls, 
    std::vector <std::vector <std::string> > &id_vec_mp)
{
    for (int i=0; i<id_vec_mp.size (); i++)
    {
        id_vec_mp [i].clear ();
        id_vec_ls [i].clear ();
    }
    id_vec_mp.clear ();
    id_vec_ls.clear ();
}

/************************************************************************
 ************************************************************************
 **                                                                    **
 **       FUNCTIONS TO CONVERT C++ OBJECTS TO Rcpp::List OBJECTS       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

// ***UP TO HERE*** write a template for id_vec to accept <osmid_t> and <string>
Rcpp::List convert_poly_linestring_to_Rcpp (float_arr3 lon_arr, float_arr3 lat_arr,
        string_arr3 rowname_arr, std::vector <std::vector <osmid_t> > id_vec, 
        std::vector <osmid_t> rel_id)
{
    Rcpp::List outList (lon_arr.size ()); 
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));
    Rcpp::List dimnames (0);
    std::vector <std::string> colnames = {"lat", "lon"};
    for (int i=0; i<lon_arr.size (); i++) // over all relations
    {
        Rcpp::List outList_i (lon_arr [i].size ()); 
        for (int j=0; j<lon_arr [i].size (); j++) // over all ways
        {
            int n = lon_arr [i][j].size ();
            nmat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));
            std::copy (lon_arr [i][j].begin (), lon_arr [i][j].end (),
                    nmat.begin ());
            std::copy (lat_arr [i][j].begin (), lat_arr [i][j].end (),
                    nmat.begin () + n);
            dimnames.push_back (rowname_arr [i][j]);
            dimnames.push_back (colnames);
            nmat.attr ("dimnames") = dimnames;
            dimnames.erase (0, dimnames.size ());
            outList_i [j] = nmat;
        }
        outList_i.attr ("names") = id_vec [i];
        outList [i] = outList_i;
    }
    outList.attr ("names") = rel_id;
}
    
/* get_osm_relations
 *
 * Return a dual Rcpp::List containing all OSM relations, the firmt element of
 * which holds `multipolygon` relations, while the second holds all others,
 * which are stored as `multilinestring` objects.
 *
 * @param rels Pointer to the vector of Relation objects
 * @param nodes Pointer to the vector of node objects
 * @param ways Pointer to the vector of way objects
 * @param unique_vals Pointer to a UniqueVals object containing std::sets of all
 *        unique IDs and keys for each kind of OSM object (nodes, ways, rels).
 *
 * @return A dual Rcpp::List, the first of which contains the multipolygon
 *         relations; the second the multilinestring relations.
 */
Rcpp::List get_osm_relations (const Relations &rels, 
        const std::map <osmid_t, Node> &nodes,
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
    string_arr2 rowname_vec;
    string_arr3 rowname_arr_mp, rowname_arr_ls;
    std::vector <osmid_t> rel_id_mp, rel_id_ls, ids_ls; 
    std::vector <std::string> ids_mp; 
    std::vector <std::vector <osmid_t> > id_vec_ls; 
    std::vector <std::vector <std::string> > id_vec_mp; 
    std::vector <std::string> roles;
    std::vector <std::vector <std::string> > roles_ls;

    // Start by collecting all unique keys.  TODO: Is it worth doing this
    // separately for multipolygons and multilinestrings?
    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
        std::for_each (itr->key_val.begin (),
                itr->key_val.end (),
                [&](const std::pair <std::string, std::string>& p)
                {
                    keyset.insert (p.first);
                });
    std::vector <std::vector <std::string> > value_arr_mp, value_arr_ls;
    std::vector <std::string> value_vec;
    value_vec.reserve (keyset.size ());

    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
    {
        for (int i=0; i<keyset.size (); i++)
            value_vec.push_back ("");
        if (itr->ispoly) // itr->second can only be "outer" or "inner"
        {
            trace_multipolygon (itr, ways, nodes, lon_vec, lat_vec,
                    rowname_vec, ids_mp);
            // Store all ways in that relation and their associated roles
            rel_id_mp.push_back (itr->id);
            lon_arr_mp.push_back (lon_vec);
            lat_arr_mp.push_back (lat_vec);
            rowname_arr_mp.push_back (rowname_vec);
            id_vec_mp.push_back (ids_mp);
            clean_geom_vecs (lon_vec, lat_vec, rowname_vec);
            ids_mp.clear ();
            get_value_vec (itr, keyset, value_vec);
            value_arr_mp.push_back (value_vec);
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
                rel_id_ls.push_back (itr->id);
                lon_arr_ls.push_back (lon_vec);
                lat_arr_ls.push_back (lat_vec);
                rowname_arr_ls.push_back (rowname_vec);
                id_vec_ls.push_back (ids_ls);
                clean_geom_vecs (lon_vec, lat_vec, rowname_vec);
                ids_ls.clear ();
            }
            roles_ls.push_back (roles);
            roles.clear ();
            get_value_vec (itr, keyset, value_vec);
            value_arr_ls.push_back (value_vec);
        }
        value_vec.clear ();
        value_vec.reserve (keyset.size ());
    }

    check_geom_arrs (lon_arr_mp, lat_arr_mp, rowname_arr_mp);
    check_geom_arrs (lon_arr_ls, lat_arr_ls, rowname_arr_ls);
    // Manually check the ID arrs, which are <osmid_t> for mp and <string> for ls
    for (int i=0; i<lon_arr_ls.size (); i++)
        if (lon_arr_ls [i].size () != id_vec_ls [i].size ())
            throw std::runtime_error ("geoms and way ids differ in size");
    if (lon_arr_ls.size () != id_vec_ls.size () |
            lon_arr_mp.size () != id_vec_mp.size ())
        throw std::runtime_error ("ids and geometries differ in size");

    // Then store the lon-lat and rowname vector<vector> objects as Rcpp::List
    Rcpp::List polygonList (lon_arr_mp.size ()); 
    for (int i=0; i<lon_arr_mp.size (); i++) // over all relations
    {
        Rcpp::List polygonList_i (lon_arr_mp [i].size ()); 
        for (int j=0; j<lon_arr_mp [i].size (); j++) // over all ways
        {
            int n = lon_arr_mp [i][j].size ();
            nmat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));
            std::copy (lon_arr_mp [i][j].begin (), lon_arr_mp [i][j].end (),
                    nmat.begin ());
            std::copy (lat_arr_mp [i][j].begin (), lat_arr_mp [i][j].end (),
                    nmat.begin () + n);
            dimnames.push_back (rowname_arr_mp [i][j]);
            dimnames.push_back (colnames);
            nmat.attr ("dimnames") = dimnames;
            dimnames.erase (0, dimnames.size ());
            polygonList_i [j] = nmat;
        }
        polygonList_i.attr ("names") = id_vec_mp [i];
        polygonList [i] = polygonList_i;
    }
    polygonList.attr ("names") = rel_id_mp;
    
    Rcpp::List linestringList (lon_arr_ls.size ()); 
    for (int i=0; i<lon_arr_ls.size (); i++) // over all relations
    {
        Rcpp::List linestringList_i (lon_arr_ls [i].size ()); 
        for (int j=0; j<lon_arr_ls [i].size (); j++) // over all ways
        {
            int n = lon_arr_ls [i][j].size ();
            nmat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));
            std::copy (lon_arr_ls [i][j].begin (), lon_arr_ls [i][j].end (),
                    nmat.begin ());
            std::copy (lat_arr_ls [i][j].begin (), lat_arr_ls [i][j].end (),
                    nmat.begin () + n);
            dimnames.push_back (rowname_arr_ls [i][j]);
            dimnames.push_back (colnames);
            nmat.attr ("dimnames") = dimnames;
            dimnames.erase (0, dimnames.size ());
            linestringList_i [j] = nmat;
        }
        linestringList_i.attr ("names") = id_vec_ls [i];
        linestringList [i] = linestringList_i;
    }
    linestringList.attr ("names") = rel_id_ls;

    // ****** clean up *****
    clean_geom_arrs (lon_arr_mp, lat_arr_mp, rowname_arr_mp);
    clean_geom_arrs (lon_arr_ls, lat_arr_ls, rowname_arr_ls);
    clean_kv_arrs (value_arr_mp, value_arr_ls);
    rel_id_mp.clear ();
    rel_id_ls.clear ();
    roles_ls.clear ();
    keyset.clear ();

    Rcpp::List ret (2);
    ret [0] = polygonList;
    ret [1] = linestringList;
    return ret;
}


/************************************************************************
 ************************************************************************
 **                                                                    **
 **            THE FINAL RCPP FUNCTION CALLED BY osmdata_sf            **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

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
    std::vector <std::string> colnames, rownames, polynames;
    std::set <std::string> keyset; // must be ordered!
    Rcpp::List dimnames (0);
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    colnames.push_back ("lon");
    colnames.push_back ("lat");

    Rcpp::NumericVector bbox = rcpp_get_bbox_sf (xml.x_min (), xml.x_max (), 
                                              xml.y_min (), xml.y_max ());

    Rcpp::List crs = Rcpp::List::create (NA_INTEGER, 
            Rcpp::CharacterVector::create (NA_STRING));
    crs (0) = 4326;
    crs (1) = p4s;
    //Rcpp::List crs = Rcpp::List::create ((int) 4326, p4s);
    crs.attr ("class") = "crs";
    crs.attr ("names") = Rcpp::CharacterVector::create ("epsg", "proj4string");

    Rcpp::List tempList = get_osm_relations (rels, nodes, ways, unique_vals);
    Rcpp::List multipolygons = tempList [0];
    Rcpp::List multilinestrings = tempList [1];


    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                            2. OSM WAYS                             **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    // identify and store poly and non_poly way IDs
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
     **                        2A: WAYS AS POLYGONS                        **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    Rcpp::List polyList2 (poly_ways.size ());
    polynames.reserve (poly_ways.size ());
    count = 0;
    // Collect all unique keys
    for (auto pi = poly_ways.begin (); pi != poly_ways.end (); ++pi)
        std::for_each (ways.find (*pi)->second.key_val.begin (),
                ways.find (*pi)->second.key_val.end (),
                [&](const std::pair <std::string, std::string>& p)
                {
                    keyset.insert (p.first);
                });
    // key-value pairs are then inserted in the Rcpp::matrix using code given
    // below. TODO: incorporate that code within this for loop
    for (auto pi = poly_ways.begin (); pi != poly_ways.end (); ++pi)
    {
        auto pj = ways.find (*pi);
        polynames.push_back (std::to_string (pj->first));

        // Then iterate over nodes of that way and store all lat-lons
        size_t n = pj->second.nodes.size ();
        lons.clear ();
        lats.clear ();
        rownames.clear ();
        lons.reserve (n);
        lats.reserve (n);
        rownames.reserve (n);
        for (auto nj = pj->second.nodes.begin ();
                nj != pj->second.nodes.end (); ++nj)
        {
            if (nodes.find (*nj) == nodes.end ())
                throw std::runtime_error ("node can not be found");
            lons.push_back (nodes.find (*nj)->second.lon);
            lats.push_back (nodes.find (*nj)->second.lat);
            rownames.push_back (std::to_string (*nj));
        }

        nmat = Rcpp::NumericMatrix (Rcpp::Dimension (lons.size (), 2));
        std::copy (lons.begin (), lons.end (), nmat.begin ());
        std::copy (lats.begin (), lats.end (), nmat.begin () + lons.size ());

        // This only works with push_back, not with direct re-allocation
        dimnames.push_back (rownames);
        dimnames.push_back (colnames);
        nmat.attr ("dimnames") = dimnames;
        dimnames.erase (0, dimnames.size());

        polyList2 [count++] = nmat;
    } // end for it over poly_ways
    polyList2.attr ("names") = polynames;

    // Store all key-val pairs in one massive DF
    Rcpp::Rcout << "varnames, uv.k_poly = [" << keyset.size () << ", " <<
        unique_vals.k_poly.size () << "]" << std::endl;
    int nrow = poly_ways.size (), ncol = keyset.size ();
    Rcpp::CharacterVector poly_kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na ());
    for (auto pi = poly_ways.begin (); pi != poly_ways.end (); ++pi)
    {
        int rowi = std::distance (poly_ways.begin (), pi);
        auto pj = ways.find (*pi);

        for (auto kv_iter = pj->second.key_val.begin ();
                kv_iter != pj->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto ni = keyset.find (key); // key must exist in keyset!
            int coli = std::distance (keyset.begin (), ni);
            poly_kv_vec (coli * nrow + rowi) = (*kv_iter).second;
        }
    }

    Rcpp::CharacterMatrix poly_kv_mat (nrow, ncol, poly_kv_vec.begin());
    Rcpp::DataFrame poly_kv_df = poly_kv_mat;
    poly_kv_df.attr ("names") = keyset;

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

    dimnames.erase (0, dimnames.size());

    // Store all key-val pairs in one massive CharacterMatrix
    nrow = non_poly_ways.size (); 
    ncol = unique_vals.k_way.size ();
    Rcpp::CharacterMatrix kv_mat_lines (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat_lines.begin (), kv_mat_lines.end (), NA_STRING);
    count = 0;
    for (auto wi = non_poly_ways.begin (); wi != non_poly_ways.end (); ++wi)
    {
        auto wj = ways.find (*wi);
        linenames.push_back (std::to_string (wj->first));
        // Then iterate over nodes of that way and store all lat-lons
        size_t n = wj->second.nodes.size ();
        rownames.clear ();
        rownames.reserve (n);
        Rcpp::NumericMatrix lineMat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));
        int tempi = 0;
        for (auto nj = wj->second.nodes.begin ();
                nj != wj->second.nodes.end (); ++nj)
        {
            if (nodes.find (*nj) == nodes.end ())
                throw std::runtime_error ("node can not be found");
            rownames.push_back (std::to_string (*nj));
            lineMat (tempi, 0) = nodes.find (*nj)->second.lon;
            lineMat (tempi++, 1) = nodes.find (*nj)->second.lat;
        }

        // This only works with push_back, not with direct re-allocation
        dimnames.push_back (rownames);
        dimnames.push_back (colnames);
        lineMat.attr ("dimnames") = dimnames;
        lineMat.attr ("class") = Rcpp::CharacterVector::create ("XY", "LINESTRING", "sfg");
        dimnames.erase (0, dimnames.size());

        lineList (count) = lineMat;

        for (auto kv_iter = wj->second.key_val.begin ();
                kv_iter != wj->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto ni = unique_vals.k_way.find (key); // key must exist!
            int coli = std::distance (unique_vals.k_way.begin (), ni);
            kv_mat_lines (count, coli) = (*kv_iter).second;
        }
        count++;
    } // end for wi over non_poly_ways

    lineList.attr ("names") = linenames;
    lineList.attr ("n_empty") = 0;
    lineList.attr ("class") = Rcpp::CharacterVector::create ("sfc_LINESTRING", "sfc");
    lineList.attr ("precision") = 0.0;
    lineList.attr ("bbox") = bbox;
    lineList.attr ("crs") = crs;
    kv_mat_lines.attr ("dimnames") = Rcpp::List::create (linenames, unique_vals.k_way);

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                          STEP#3C: POINTS                           **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    nrow = nodes.size ();
    ncol = unique_vals.k_point.size ();
    Rcpp::CharacterMatrix kv_mat_points (Rcpp::Dimension (nrow, ncol));
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
        pointList (count) = ptxy;
        ptnames.push_back (std::to_string (ni->first));
        for (auto kv_iter = ni->second.key_val.begin ();
                kv_iter != ni->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto it = unique_vals.k_point.find (key);
            int ni = std::distance (unique_vals.k_point.begin (), it);
            kv_mat_points (count, ni) = (*kv_iter).second;
        }
        count++;
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


    Rcpp::List ret (7);
    //ret [0] = bbox;
    ret [0] = pointList;
    ret [1] = kv_mat_points;
    ret [2] = lineList;
    ret [3] = kv_mat_lines;
    ret [4] = multipolygons;
    ret [5] = poly_kv_df;
    ret [6] = multilinestrings;

    //std::vector <std::string> retnames {"bbox", "points", 
    //    "lines", "lines_kv", "polygons", "polygons_kv"};
    std::vector <std::string> retnames {"points", "points_kv",
        "lines", "lines_kv", "multipolygons", "polygons_kv", "multilinestrings"};
    ret.attr ("names") = retnames;
    
    return ret;
}
