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
#include "trace_osm.h"
#include "cleanup.h"
#include "get-bbox.h"

#include <Rcpp.h>

#include <algorithm> // for min_element/max_element

// Note: roxygen attempts to import doxygen-style comments, even without the
// doubule-square-bracket Rcpp::Export

/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       STRUCTURE OF THIS FILE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************
 *
 * 1. Primary functions to trace ways and relations
 *      1a. trace_multipolygon ()
 *      1b. trace_multilinestring ()
 *      1c. trace_way ()
 *      1d. trace_way_nmat ()
 *      1e. get_value_mat_way ()
 *      1f. get_value_vec ()
 * 2. Functions to check and clean C++ arrays
 *      2a. reserve_arrs ()
 *      2b. check_geom_arrs ()
 *      2c. check_id_arr ()
 *      2d. clean_vec ()
 *      2e. clear_arr ()
 *      2f. clean_vecs ()
 *      2g. clean_arrs ()
 * 3. Functions to convert C++ objects to Rcpp::List objects
 *      3a. restructure_kv_mat ()
 *      3b. convert_poly_linestring_to_Rcpp ()
 *      3c. get_osm_relations ()
 *      3d. get_osm_ways ()
 *      3e. get_osm_nodes ()
 * 4. The final Rcpp function called by osmdata_sf
 *      4a. rcpp_osmdata ()
 *
 * ----------------------------------------------------------------------
 *
 *  The calling hierarchy extends generally from bottom to top as follows:
 *  rcpp_osmdata () {
 *      -> get_osm_relations ()
 *      {
 *          -> trace_multipolygon ()
 *              -> trace_way ()
 *              -> restructure_kv_mat
 *          -> trace_multilinestring ()
 *              -> trace_way ()
 *              -> restructure_kv_mat
 *          -> get_value_vec ()
 *          -> convert_poly_linestring_to_Rcpp ()
 *          -> [... most check and clean functions ...]
 *      }
 *      -> get_osm_ways ()
 *      {
 *          -> trace_way_nmat ()
 *          -> get_value_mat_way ()
 *          -> restructure_kv_mat
 *      }
 *      -> get_osm_nodes ()
 *          -> restructure_kv_mat
 *  }
 */

/************************************************************************
 ************************************************************************
 **                                                                    **
 **          1. PRIMARY FUNCTIONS TO TRACE WAYS AND RELATIONS          **
 **                                                                    **
 ************************************************************************
 ************************************************************************/


/* Traces a single way and adds (lon,lat,rownames) to an Rcpp::NumericMatrix
 *
 * @param &ways pointer to Ways structure
 * @param &nodes pointer to Nodes structure
 * @param first_node Last node of previous way to find in current
 * @param &wayi_id pointer to ID of current way
 * @lons pointer to vector of longitudes
 * @lats pointer to vector of latitutdes
 * @rownames pointer to vector of rownames for each node.
 * @nmat Rcpp::NumericMatrix to store lons, lats, and rownames
 */
void trace_way_nmat (const Ways &ways, const Nodes &nodes, 
        const osmid_t &wayi_id, Rcpp::NumericMatrix &nmat)
{
    auto wayi = ways.find (wayi_id);
    std::vector <std::string> rownames;
    rownames.clear ();
    int n = wayi->second.nodes.size ();
    rownames.reserve (n);
    nmat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));

    int tempi = 0;
    for (auto ni = wayi->second.nodes.begin ();
            ni != wayi->second.nodes.end (); ++ni)
    {
        rownames.push_back (std::to_string (*ni));
        nmat (tempi, 0) = nodes.find (*ni)->second.lon;
        nmat (tempi++, 1) = nodes.find (*ni)->second.lat;
    }

    std::vector <std::string> colnames = {"lon", "lat"};
    Rcpp::List dimnames (0);
    dimnames.push_back (rownames);
    dimnames.push_back (colnames);
    nmat.attr ("dimnames") = dimnames;
    dimnames.erase (0, dimnames.size ());
}

/* get_value_mat_way
 *
 * Extract key-value pairs for a given way and fill Rcpp::CharacterMatrix
 *
 * @param wayi Constant iterator to one OSM way
 * @param Ways Pointer to the std::vector of all ways
 * @param unique_vals Pointer to the UniqueVals structure
 * @param value_arr Pointer to the Rcpp::CharacterMatrix of values to be filled
 *        by tracing the key-val pairs of the way 'wayi'
 * @param rowi Integer value for the key-val pairs for wayi
 */
// TODO: Is it faster to use a std::vector <std::string> instead of
// Rcpp::CharacterMatrix and then simply
// Rcpp::CharacterMatrix mat (nrow, ncol, value_vec.begin ()); ?
void get_value_mat_way (Ways::const_iterator wayi, const Ways &ways,
        const UniqueVals &unique_vals, Rcpp::CharacterMatrix &value_arr, int rowi)
{
    for (auto kv_iter = wayi->second.key_val.begin ();
            kv_iter != wayi->second.key_val.end (); ++kv_iter)
    {
        const std::string &key = kv_iter->first;
        int coli = std::distance (unique_vals.k_way.begin (),
                unique_vals.k_way.find (key));
        value_arr (rowi, coli) = kv_iter->second;
    }
}

/* get_value_mat_rel
 *
 * Extract key-value pairs for a given relation and fill Rcpp::CharacterMatrix
 *
 * @param reli Constant iterator to one OSM relation
 * @param rels Pointer to the std::vector of all relations
 * @param unique_vals Pointer to the UniqueVals structure
 * @param value_arr Pointer to the Rcpp::CharacterMatrix of values to be filled
 *        by tracing the key-val pairs of the relation 'reli'
 * @param rowi Integer value for the key-val pairs for reli
 */
void get_value_mat_rel (Relations::const_iterator reli, const Relations &rels,
        const UniqueVals &unique_vals, Rcpp::CharacterMatrix &value_arr, int rowi)
{
    for (auto kv_iter = reli->key_val.begin (); kv_iter != reli->key_val.end ();
            ++kv_iter)
    {
        const std::string &key = kv_iter->first;
        int coli = std::distance (unique_vals.k_rel.begin (),
                unique_vals.k_rel.find (key));
        value_arr (rowi, coli) = kv_iter->second;
    }
}

/************************************************************************
 ************************************************************************
 **                                                                    **
 **       FUNCTIONS TO CONVERT C++ OBJECTS TO Rcpp::List OBJECTS       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

/* convert_poly_linestring_to_Rcpp
 *
 * Converts the data contained in all the arguments into an Rcpp::List object
 * to be used as the geometry column of a Simple Features Colletion
 *
 * @param lon_arr 3D array of longitudinal coordinates
 * @param lat_arr 3D array of latgitudinal coordinates
 * @param rowname_arr 3D array of <osmid_t> IDs for nodes of all (lon,lat)
 * @param id_vec 2D array of either <std::string> or <osmid_t> IDs for all ways
 *        used in the geometry.
 * @param rel_id Vector of <osmid_t> IDs for each relation.
 *
 * @return An Rcpp::List object of [relation][way][node/geom] data.
 */
// TODO: Replace return value with pointer to List as argument?
template <typename T, typename A> // std::vector of osmid_t or std::string
Rcpp::List convert_poly_linestring_to_Rcpp (const float_arr3 lon_arr, 
        const float_arr3 lat_arr, const string_arr3 rowname_arr, 
        const std::vector <std::vector <T,A> > &id_vec, 
        const std::vector <std::string> &rel_id, const std::string type)
{
    if (!(type == "MULTILINESTRING" || type == "MULTIPOLYGON"))
        throw std::runtime_error ("type must be multilinestring/polygon");
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
        if (type == "MULTIPOLYGON")
        {
            Rcpp::List tempList (1);
            tempList (0) = outList_i;
            tempList.attr ("class") = Rcpp::CharacterVector::create ("XY", type, "sfg");
            outList [i] = tempList;
        } else
        {
            outList_i.attr ("class") = Rcpp::CharacterVector::create ("XY", type, "sfg");
            outList [i] = outList_i;
        }
    }
    outList.attr ("names") = rel_id;

    return outList;
}

/* restructure_kv_mat
 *
 * Restructures a key-value matrix to reflect typical GDAL output by
 * inserting a first column containing "osm_id" and moving the "name" column to
 * second position.
 *
 * @param kv Pointer to the key-value matrix to be restructured
 * @param ls true only for multilinestrings, which have compound rownames which
 *        include roles
 */
Rcpp::CharacterMatrix restructure_kv_mat (Rcpp::CharacterMatrix &kv, bool ls=false)
{
    // The following has to be done in 2 lines:
    std::vector <std::vector <std::string> > dims = kv.attr ("dimnames");
    std::vector <std::string> ids = dims [0], varnames = dims [1], varnames_new;
    Rcpp::CharacterMatrix kv_out;

    int ni = std::distance (varnames.begin (),
            std::find (varnames.begin (), varnames.end (), "name"));
    int add_lines = 1;
    if (ls)
        add_lines++;

    if (ni < varnames.size ())
    {
        Rcpp::CharacterVector name_vals = kv.column (ni);
        Rcpp::CharacterVector roles; // only for ls, but has to be defined here
        // convert ids to CharacterVector - direct allocation doesn't work
        Rcpp::CharacterVector ids_rcpp (ids.size ());
        if (!ls)
            for (int i=0; i<ids.size (); i++)
                ids_rcpp (i) = ids [i];
        else
        { // extract way roles for multilinestring kev-val matrices
            roles = Rcpp::CharacterVector (ids.size ());
            for (int i=0; i<ids.size (); i++)
            {
                int ipos = ids [i].find ("-", 0);
                ids_rcpp (i) = ids [i].substr (0, ipos).c_str ();
                roles (i) = ids [i].substr (ipos + 1, ids[i].length () - ipos);
            }
        }

        varnames_new.reserve (kv.ncol () + add_lines);
        varnames_new.push_back ("osm_id");
        varnames_new.push_back ("name");
        kv_out = Rcpp::CharacterMatrix (Rcpp::Dimension (kv.nrow (),
                    kv.ncol () + add_lines));
        kv_out.column (0) = ids_rcpp;
        kv_out.column (1) = name_vals;
        if (ls)
        {
            varnames_new.push_back ("role");
            kv_out.column (2) = roles;
        }
        int count = 1 + add_lines;
        for (int i=0; i<kv.ncol (); i++)
            if (i != ni)
            {
                varnames_new.push_back (varnames [i]);
                kv_out.column (count++) = kv.column (i);
            }
        kv_out.attr ("dimnames") = Rcpp::List::create (ids, varnames_new);
    } else
        kv_out = kv;

    return kv_out;
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
        const std::map <osmid_t, OneWay> &ways, const UniqueVals &unique_vals,
        const Rcpp::NumericVector &bbox, const Rcpp::List &crs)
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
                get_value_mat_rel (itr, rels, unique_vals, kv_mat_ls, count_ls++);
            }
            roles_ls.push_back (roles);
            roles.clear ();
        }
    }

    check_geom_arrs (lon_arr_mp, lat_arr_mp, rowname_arr_mp);
    check_geom_arrs (lon_arr_ls, lat_arr_ls, rowname_arr_ls);
    check_id_arr <osmid_t> (lon_arr_ls, id_vec_ls);
    check_id_arr <std::string> (lon_arr_mp, id_vec_mp);

    Rcpp::List polygonList = convert_poly_linestring_to_Rcpp <std::string>
        (lon_arr_mp, lat_arr_mp, rowname_arr_mp, id_vec_mp, rel_id_mp,
         "MULTIPOLYGON");
    // Each multipolygon has to be converted to a double Rcpp::List (Rcpp::List
    /*
    Rcpp::List polygonList (polygonList0.size ());
    for (int i=0; i<polygonList0.size (); i++)
    {
        Rcpp::List tempList0 = Rcpp::List (1), tempList1 = Rcpp::List (1);
        tempList0 (0) = polygonList0 (i);
        tempList1 (0) = tempList0 (0);
        polygonList (i) = tempList1;
    }
    */
    polygonList.attr ("n_empty") = 0;
    polygonList.attr ("class") = 
        Rcpp::CharacterVector::create ("sfc_MULTIPOLYGON", "sfc");
    polygonList.attr ("precision") = 0.0;
    polygonList.attr ("bbox") = bbox;
    polygonList.attr ("crs") = crs;

    Rcpp::List linestringList = convert_poly_linestring_to_Rcpp <osmid_t>
        (lon_arr_ls, lat_arr_ls, rowname_arr_ls, id_vec_ls, rel_id_ls,
         "MULTILINESTRING");
    // TODO: linenames just as in ways?
    // linestringList.attr ("names") = ?
    linestringList.attr ("n_empty") = 0;
    linestringList.attr ("class") = 
        Rcpp::CharacterVector::create ("sfc_MULTILINESTRING", "sfc");
    linestringList.attr ("precision") = 0.0;
    linestringList.attr ("bbox") = bbox;
    linestringList.attr ("crs") = crs;

    Rcpp::DataFrame kv_df_ls;
    if (rel_id_ls.size () > 0) // only if there are linestrings
    {
        kv_mat_ls.attr ("names") = unique_vals.k_rel;
        kv_mat_ls.attr ("dimnames") = Rcpp::List::create (rel_id_ls, unique_vals.k_rel);
        kv_df_ls = restructure_kv_mat (kv_mat_ls, true);
    } else
        kv_df_ls = R_NilValue;

    Rcpp::DataFrame kv_df_mp;
    if (rel_id_mp.size () > 0)
    {
        kv_mat_mp.attr ("names") = unique_vals.k_rel;
        kv_mat_mp.attr ("dimnames") = Rcpp::List::create (rel_id_mp, unique_vals.k_rel);
        kv_df_mp = restructure_kv_mat (kv_mat_mp, false);
    } else
        kv_df_mp = R_NilValue;

    // ****** clean up *****
    clean_arrs <float, float, std::string> (lon_arr_mp, lat_arr_mp, rowname_arr_mp);
    clean_arrs <float, float, std::string> (lon_arr_ls, lat_arr_ls, rowname_arr_ls);
    clean_vecs <std::string, osmid_t> (id_vec_mp, id_vec_ls);
    rel_id_mp.clear ();
    rel_id_ls.clear ();
    roles_ls.clear ();
    keyset.clear ();

    Rcpp::List ret (4);
    ret [0] = polygonList;
    ret [1] = kv_df_mp;
    ret [2] = linestringList;
    ret [3] = kv_df_ls;
    return ret;
}

/* get_osm_ways
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
void get_osm_ways (Rcpp::List &wayList, Rcpp::DataFrame &kv_df,
        const std::set <osmid_t> way_ids, const Ways &ways, const Nodes &nodes,
        const UniqueVals &unique_vals, const std::string &geom_type,
        const Rcpp::NumericVector &bbox, const Rcpp::List &crs)
{
    if (!(geom_type == "POLYGON" || geom_type == "LINESTRING"))
        throw std::runtime_error ("geom_type must be POLYGON or LINESTRING");
    if (wayList.size () != way_ids.size ())
        throw std::runtime_error ("ways and IDs must have same lengths");

    int nrow = way_ids.size (), ncol = unique_vals.k_way.size ();
    std::vector <std::string> waynames;
    waynames.reserve (way_ids.size ());

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);
    int count = 0;
    for (auto wi = way_ids.begin (); wi != way_ids.end (); ++wi)
    {
        waynames.push_back (std::to_string (*wi));
        Rcpp::NumericMatrix nmat;
        trace_way_nmat (ways, nodes, (*wi), nmat);
        if (geom_type == "LINESTRING")
        {
            nmat.attr ("class") = 
                Rcpp::CharacterVector::create ("XY", geom_type, "sfg");
            wayList [count] = nmat;
        } else // polygons are lists
        {
            Rcpp::List polyList_temp = Rcpp::List (1);
            polyList_temp (0) = nmat;
            polyList_temp.attr ("class") = 
                Rcpp::CharacterVector::create ("XY", geom_type, "sfg");
            wayList [count] = polyList_temp;
        }
        auto wj = ways.find (*wi);
        get_value_mat_way (wj, ways, unique_vals, kv_mat, count++);
    } // end for it over poly_ways

    wayList.attr ("names") = waynames;
    wayList.attr ("n_empty") = 0;
    std::stringstream ss;
    ss.str ("");
    ss << "sfc_" << geom_type;
    std::string sfc_type = ss.str ();
    wayList.attr ("class") = Rcpp::CharacterVector::create (sfc_type, "sfc");
    //wayList.attr ("class") = Rcpp::CharacterVector::create ("sfc_POLYGON", "sfc");
    wayList.attr ("precision") = 0.0;
    wayList.attr ("bbox") = bbox;
    wayList.attr ("crs") = crs;

    kv_mat.attr ("names") = unique_vals.k_way;
    kv_mat.attr ("dimnames") = Rcpp::List::create (waynames, unique_vals.k_way);
    kv_df = restructure_kv_mat (kv_mat, false);
}

/* get_osm_nodes
 *
 * Store OSM nodes as `sf::POINT` objects
 *
 * @param ptxy Pointer to Rcpp::List to hold the resultant geometries
 * @param kv_df Pointer to Rcpp::DataFrame to hold key-value pairs
 * @param nodes Pointer to all nodes in data set
 * @param unique_vals pointer to all unique values (OSM IDs and keys) in data set
 * @param bbox Pointer to the bbox needed for `sf` construction
 * @param crs Pointer to the crs needed for `sf` construction
 */
void get_osm_nodes (Rcpp::List &ptList, Rcpp::DataFrame &kv_df,
        const Nodes &nodes, const UniqueVals &unique_vals, 
        const Rcpp::NumericVector &bbox, const Rcpp::List &crs)
{
    int nrow = nodes.size (), ncol = unique_vals.k_point.size ();

    if (ptList.size () != nrow)
        throw std::runtime_error ("points must have same size as nodes");

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);

    std::vector <std::string> ptnames;
    ptnames.reserve (nodes.size ());
    int count = 0;
    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        Rcpp::NumericVector ptxy = Rcpp::NumericVector::create (NA_REAL, NA_REAL);
        ptxy.attr ("class") = Rcpp::CharacterVector::create ("XY", "POINT", "sfg");
        ptxy (0) = ni->second.lon;
        ptxy (1) = ni->second.lat;
        ptList (count) = ptxy;
        ptnames.push_back (std::to_string (ni->first));
        for (auto kv_iter = ni->second.key_val.begin ();
                kv_iter != ni->second.key_val.end (); ++kv_iter)
        {
            const std::string &key = kv_iter->first;
            int ni = std::distance (unique_vals.k_point.begin (),
                    unique_vals.k_point.find (key));
            kv_mat (count, ni) = kv_iter->second;
        }
        count++;
    }
    kv_mat.attr ("dimnames") = Rcpp::List::create (ptnames, unique_vals.k_point);
    kv_df = restructure_kv_mat (kv_mat, false);
    //kv_df = kv_mat;

    ptList.attr ("names") = ptnames;
    ptnames.clear ();
    ptList.attr ("n_empty") = 0;
    ptList.attr ("class") = Rcpp::CharacterVector::create ("sfc_POINT", "sfc");
    ptList.attr ("precision") = 0.0;
    ptList.attr ("bbox") = bbox;
    ptList.attr ("crs") = crs;
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

    std::vector <float> lons, lats;
    std::set <std::string> keyset; // must be ordered!
    Rcpp::List dimnames (0);
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    /* --------------------------------------------------------------
     * 1. Set up bbox and crs
     * --------------------------------------------------------------*/

    std::vector <std::string> colnames, rownames;
    colnames.push_back ("lon");
    colnames.push_back ("lat");

    Rcpp::NumericVector bbox = rcpp_get_bbox_sf (xml.x_min (), xml.x_max (), 
                                              xml.y_min (), xml.y_max ());

    Rcpp::List crs = Rcpp::List::create (NA_INTEGER, 
            Rcpp::CharacterVector::create (NA_STRING));
    crs (0) = 4326;
    crs (1) = p4s;
    //Rcpp::List crs = Rcpp::List::create ((int) 4326, p4s);
    crs.attr ("names") = Rcpp::CharacterVector::create ("epsg", "proj4string");
    crs.attr ("class") = "crs";

    /* --------------------------------------------------------------
     * 2. Extract OSM Relations
     * --------------------------------------------------------------*/

    Rcpp::List tempList = get_osm_relations (rels, nodes, ways, unique_vals,
            bbox, crs);
    Rcpp::List multipolygons = tempList [0];
    // the followin line errors because of ambiguous conversion
    //Rcpp::DataFrame kv_df_mp = tempList [1]; 
    Rcpp::List kv_df_mp = tempList [1];
    kv_df_mp.attr ("class") = "data.frame";
    Rcpp::List multilinestrings = tempList [2];
    Rcpp::List kv_df_ls = tempList [3];
    kv_df_ls.attr ("class") = "data.frame";

    /* --------------------------------------------------------------
     * 3. Extract OSM ways
     * --------------------------------------------------------------*/

    // first divide into polygonal and non-polygonal
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

    Rcpp::List polyList (poly_ways.size ());
    Rcpp::DataFrame kv_df_polys;
    get_osm_ways (polyList, kv_df_polys, poly_ways, ways, nodes, unique_vals,
            "POLYGON", bbox, crs);

    Rcpp::List lineList (non_poly_ways.size ());
    Rcpp::DataFrame kv_df_lines;
    get_osm_ways (lineList, kv_df_lines, non_poly_ways, ways, nodes, unique_vals,
            "LINESTRING", bbox, crs);

    /* --------------------------------------------------------------
     * 3. Extract OSM nodes
     * --------------------------------------------------------------*/

    Rcpp::List pointList (nodes.size ());
    Rcpp::DataFrame kv_df_points;
    get_osm_nodes (pointList, kv_df_points, nodes, unique_vals, bbox, crs);


    /* --------------------------------------------------------------
     * 5. Collate all data
     * --------------------------------------------------------------*/

    Rcpp::List ret (10);
    //ret [0] = bbox;
    ret [0] = pointList;
    ret [1] = kv_df_points;
    ret [2] = lineList;
    ret [3] = kv_df_lines;
    ret [4] = polyList;
    ret [5] = kv_df_polys;
    ret [6] = multipolygons;
    ret [7] = kv_df_mp;
    ret [8] = multilinestrings;
    ret [9] = kv_df_ls;

    std::vector <std::string> retnames {"points", "points_kv",
        "linestrings", "linestrings_kv", "polygons", "polygons_kv",
        "multipolygons", "multipolygons_kv", 
        "multilinestrings", "multilinestrings_kv"};
    ret.attr ("names") = retnames;
    
    return ret;
}
