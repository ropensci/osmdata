/***************************************************************************
 *  Project:    osmdata
 *  File:       osmdata-sf.cpp
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
 *  osm-router.  If not, see <https://www.gnu.org/licenses/>.
 *
 *  Author:     Mark Padgham
 *  E-Mail:     mark.padgham@email.com
 *
 *  Description:    Extract OSM data from an object of class XmlData and return
 *                  it in Rcpp::List format.
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdata)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#include "osmdata.h"

#include <Rcpp.h>

// Note: This code uses explicit index counters within most loops which use Rcpp
// objects, because these otherwise require a
// static_cast <size_t> (std::distance (...)). This operation copies each
// instance and can slow the loops down by several orders of magnitude!

/************************************************************************
 ************************************************************************
 **                                                                    **
 **          1. PRIMARY FUNCTIONS TO TRACE WAYS AND RELATIONS          **
 **                                                                    **
 ************************************************************************
 ************************************************************************/


//' get_osm_relations
//'
//' Return a dual Rcpp::List containing all OSM relations, the first element of
//' which holds `multipolygon` relations, while the second holds all others,
//' which are stored as `multilinestring` objects.
//'
//' @param rels Pointer to the vector of Relation objects
//' @param nodes Pointer to the vector of node objects
//' @param ways Pointer to the vector of way objects
//' @param unique_vals Pointer to a UniqueVals object containing std::sets of all
//'       unique IDs and keys for each kind of OSM object (nodes, ways, rels).
//'
//' @return A dual Rcpp::List, the first of which contains the multipolygon
//'         relations; the second the multilinestring relations. TODO: update
//'
//' @noRd
Rcpp::List osm_sf::get_osm_relations (const Relations &rels,
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

    double_arr2 lat_vec, lon_vec;
    double_arr3 lat_arr_mp, lon_arr_mp, lon_arr_ls, lat_arr_ls;
    string_arr2 rowname_vec, id_vec_mp, roles_ls;
    string_arr3 rowname_arr_mp, rowname_arr_ls;
    std::vector <osmid_t> ids_ls;
    std::vector <std::string> ids_mp, rel_id_mp, rel_id_ls;
    osmt_arr2 id_vec_ls;
    std::vector <std::string> roles;

    unsigned int nmp = 0, nls = 0; // number of multipolygon and multilinestringrelations
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
    std::vector <bool> mp_okay (nmp);
    std::fill (mp_okay.begin (), mp_okay.end (), true);

    size_t ncol = unique_vals.k_rel.size ();
    rel_id_mp.reserve (nmp);
    rel_id_ls.reserve (nls);

    Rcpp::CharacterMatrix kv_mat_mp (Rcpp::Dimension (nmp, ncol)),
        kv_mat_ls (Rcpp::Dimension (nls, ncol));
    std::fill (kv_mat_mp.begin (), kv_mat_mp.end (), NA_STRING);
    std::fill (kv_mat_ls.begin (), kv_mat_ls.end (), NA_STRING);
    Rcpp::CharacterMatrix meta_mat_mp (Rcpp::Dimension (nmp, 5L)),
        meta_mat_ls (Rcpp::Dimension (nls, 5L));
    std::fill (meta_mat_mp.begin (), meta_mat_mp.end (), NA_STRING);
    std::fill (meta_mat_ls.begin (), meta_mat_ls.end (), NA_STRING);

    unsigned int count_mp = 0, count_ls = 0;

    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
    {
        Rcpp::checkUserInterrupt ();
        if (itr->ispoly) // itr->second can only be "outer" or "inner"
        {
            trace_multipolygon (itr, ways, nodes, lon_vec, lat_vec,
                    rowname_vec, ids_mp);
            rel_id_mp.push_back (std::to_string (itr->id));
            lon_arr_mp.push_back (lon_vec);
            lat_arr_mp.push_back (lat_vec);
            rowname_arr_mp.push_back (rowname_vec);
            id_vec_mp.push_back (ids_mp);

            if (rowname_vec.size () == 0)
                mp_okay [count_mp] = false;

            lon_vec.clear ();
            lon_vec.shrink_to_fit ();
            lat_vec.clear ();
            lat_vec.shrink_to_fit ();
            rowname_vec.clear ();
            rowname_vec.shrink_to_fit ();
            ids_mp.clear ();
            ids_mp.shrink_to_fit ();

            meta_mat_mp (count_mp, 0L) = itr->_version;
            meta_mat_mp (count_mp, 1L) = itr->_timestamp;
            meta_mat_mp (count_mp, 2L) = itr->_changeset;
            meta_mat_mp (count_mp, 3L) = itr->_uid;
            meta_mat_mp (count_mp, 4L) = itr->_user;

            osm_convert::get_value_mat_rel (itr, unique_vals, kv_mat_mp, count_mp++);
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

                lon_vec.clear ();
                lon_vec.shrink_to_fit ();
                lat_vec.clear ();
                lat_vec.shrink_to_fit ();
                rowname_vec.clear ();
                rowname_vec.shrink_to_fit ();
                ids_ls.clear ();
                ids_ls.shrink_to_fit ();

                meta_mat_ls (count_ls, 0L) = itr->_version;
                meta_mat_ls (count_ls, 1L) = itr->_timestamp;
                meta_mat_ls (count_ls, 2L) = itr->_changeset;
                meta_mat_ls (count_ls, 3L) = itr->_uid;
                meta_mat_ls (count_ls, 4L) = itr->_user;

                osm_convert::get_value_mat_rel (itr, unique_vals, kv_mat_ls, count_ls++);
            }
            roles_ls.push_back (roles);
            roles.clear ();
        }
    }

    // Erase any multipolygon ways that are not okay. An example of these is
    // opq("salzburg") |> add_osm_feature (key = "highway"), for which
    // $osm_multipolygons [[42]] with way#4108738 is not okay.
    std::vector <std::string> not_okay_id;
    for (size_t i = 0; i < mp_okay.size (); i++)
        if (!mp_okay [i])
            not_okay_id.push_back (rel_id_mp [i]);

    for (std::string i: not_okay_id)
    {
        std::vector <std::string>::iterator it =
            std::find (rel_id_mp.begin (), rel_id_mp.end (), i);
        //size_t j = static_cast <size_t> (std::distance (rel_id_mp.begin (), it));
        long int j = std::distance (rel_id_mp.begin (), it);
        lon_arr_mp.erase (lon_arr_mp.begin () + j);
        lat_arr_mp.erase (lat_arr_mp.begin () + j);
        rowname_arr_mp.erase (rowname_arr_mp.begin () + j);
        id_vec_mp.erase (id_vec_mp.begin () + j);
        rel_id_mp.erase (rel_id_mp.begin () + j);

        // Retain static_cast here because there will generally be very few
        // instances of this loop
        size_t st_nrow = static_cast <size_t> (kv_mat_mp.nrow ());
        Rcpp::CharacterMatrix kv_mat_mp2 (Rcpp::Dimension (st_nrow - 1, ncol));
        Rcpp::CharacterMatrix meta_mp2 (Rcpp::Dimension (st_nrow - 1, 5L));
        // k is int for type-compatible Rcpp indexing
        for (int k = 0; k < kv_mat_mp.nrow (); k++)
        {
            if (k < j)
            {
                kv_mat_mp2 (k, Rcpp::_) = kv_mat_mp (k, Rcpp::_);
                meta_mp2 (k, Rcpp::_) = meta_mat_mp (k, Rcpp::_);
            } else if (k > j)
            {
                kv_mat_mp2 (k - 1, Rcpp::_) = kv_mat_mp (k, Rcpp::_);
                meta_mp2 (k - 1, Rcpp::_) = meta_mat_mp (k, Rcpp::_);
            }
        }
        kv_mat_mp = kv_mat_mp2;
        meta_mat_mp = meta_mp2;
    }

    Rcpp::List polygonList = osm_convert::convert_poly_linestring_to_sf <std::string>
        (lon_arr_mp, lat_arr_mp, rowname_arr_mp, id_vec_mp, rel_id_mp,
         "MULTIPOLYGON");
    polygonList.attr ("n_empty") = 0;
    polygonList.attr ("class") =
        Rcpp::CharacterVector::create ("sfc_MULTIPOLYGON", "sfc");
    polygonList.attr ("precision") = 0.0;
    polygonList.attr ("bbox") = bbox;
    polygonList.attr ("crs") = crs;

    Rcpp::List linestringList = osm_convert::convert_poly_linestring_to_sf <osmid_t>
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
    Rcpp::DataFrame meta_df_ls;
    if (rel_id_ls.size () > 0) // only if there are linestrings
    {
        kv_mat_ls.attr ("dimnames") = Rcpp::List::create (rel_id_ls, unique_vals.k_rel);
        kv_df_ls = osm_convert::restructure_kv_mat (kv_mat_ls, true);
        meta_mat_ls.attr ("dimnames") = Rcpp::List::create (rel_id_ls, metanames);
        meta_df_ls = meta_mat_ls;
    } else
    {
        kv_df_ls = R_NilValue;
        meta_df_ls = R_NilValue;
    }

    Rcpp::DataFrame kv_df_mp;
    Rcpp::DataFrame meta_df_mp;
    if (rel_id_mp.size () > 0)
    {
        kv_mat_mp.attr ("dimnames") = Rcpp::List::create (rel_id_mp, unique_vals.k_rel);
        kv_df_mp = osm_convert::restructure_kv_mat (kv_mat_mp, false);
        meta_mat_mp.attr ("dimnames") = Rcpp::List::create (rel_id_mp, metanames);
        meta_df_mp = meta_mat_mp;
    } else
    {
        kv_df_mp = R_NilValue;
        meta_df_mp = R_NilValue;
    }

    // ****** clean up *****
    lon_arr_mp.clear ();
    lon_arr_mp.shrink_to_fit ();
    lon_arr_ls.clear ();
    lon_arr_ls.shrink_to_fit ();
    lat_arr_mp.clear ();
    lat_arr_mp.shrink_to_fit ();
    lat_arr_ls.clear ();
    lat_arr_ls.shrink_to_fit ();
    rowname_arr_mp.clear ();
    rowname_arr_mp.shrink_to_fit ();
    rowname_arr_ls.clear ();
    rowname_arr_ls.shrink_to_fit ();

    rel_id_mp.clear ();
    rel_id_mp.shrink_to_fit ();
    rel_id_ls.clear ();
    rel_id_ls.shrink_to_fit ();
    roles_ls.clear ();
    roles_ls.shrink_to_fit ();

    Rcpp::List ret (6);
    ret [0] = polygonList;
    ret [1] = kv_df_mp;
    ret [2] = meta_df_mp;
    ret [3] = linestringList;
    ret [4] = kv_df_ls;
    ret [5] = meta_df_ls;
    return ret;
}

//' get_osm_ways
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
void osm_sf::get_osm_ways (Rcpp::List &wayList, Rcpp::DataFrame &kv_df, Rcpp::DataFrame &meta_df,
        const std::set <osmid_t> &way_ids, const Ways &ways, const Nodes &nodes,
        const UniqueVals &unique_vals, const std::string &geom_type,
        const Rcpp::NumericVector &bbox, const Rcpp::List &crs)
{
    if (!(geom_type == "POLYGON" || geom_type == "LINESTRING"))
        throw std::runtime_error ("geom_type must be POLYGON or LINESTRING");
    // NOTE that Rcpp `.size()` returns a **signed** int
    if (static_cast <unsigned int> (wayList.size ()) != way_ids.size ())
        throw std::runtime_error ("ways and IDs must have same lengths");

    size_t nrow = way_ids.size (), ncol = unique_vals.k_way.size ();
    std::vector <std::string> waynames;
    waynames.reserve (way_ids.size ());

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);
    Rcpp::CharacterMatrix meta (Rcpp::Dimension (nrow, 5L));
    std::fill (meta.begin (), meta.end (), NA_STRING);

    unsigned int count = 0;
    for (auto wi = way_ids.begin (); wi != way_ids.end (); ++wi)
    {
        //unsigned int count = static_cast <unsigned int> (
        //        std::distance (way_ids.begin (), wi));
        Rcpp::checkUserInterrupt ();
        waynames.push_back (std::to_string (*wi));
        Rcpp::NumericMatrix nmat;
        osm_convert::trace_way_nmat (ways, nodes, (*wi), nmat);
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
        osm_convert::get_value_mat_way (wj, unique_vals, kv_mat, count);

        meta (count, 0L) = wj->second._version;
        meta (count, 1L) = wj->second._timestamp;
        meta (count, 2L) = wj->second._changeset;
        meta (count, 3L) = wj->second._uid;
        meta (count, 4L) = wj->second._user;

        count++;
    }

    wayList.attr ("names") = waynames;
    wayList.attr ("n_empty") = 0;
    std::stringstream ss;
    ss.str ("");
    ss << "sfc_" << geom_type;
    std::string sfc_type = ss.str ();
    wayList.attr ("class") = Rcpp::CharacterVector::create (sfc_type, "sfc");
    wayList.attr ("precision") = 0.0;
    wayList.attr ("bbox") = bbox;
    wayList.attr ("crs") = crs;

    kv_df = R_NilValue;
    if (way_ids.size () > 0)
    {
        kv_mat.attr ("dimnames") = Rcpp::List::create (waynames, unique_vals.k_way);
        if (kv_mat.nrow () > 0 && kv_mat.ncol () > 0)
            kv_df = osm_convert::restructure_kv_mat (kv_mat, false);

        meta.attr ("dimnames") = Rcpp::List::create (waynames, metanames);
        meta_df = meta;
    }

}

//' get_osm_nodes
//'
//' Store OSM nodes as `sf::POINT` objects
//'
//' @param ptxy Pointer to Rcpp::List to hold the resultant geometries
//' @param kv_df Pointer to Rcpp::DataFrame to hold key-value pairs
//' @param nodes Pointer to all nodes in data set
//' @param unique_vals pointer to all unique values (OSM IDs and keys) in data set
//' @param bbox Pointer to the bbox needed for `sf` construction
//' @param crs Pointer to the crs needed for `sf` construction
//'
//' @noRd
void osm_sf::get_osm_nodes (Rcpp::List &ptList, Rcpp::DataFrame &kv_df, Rcpp::DataFrame &meta_df,
        const Nodes &nodes, const UniqueVals &unique_vals,
        const Rcpp::NumericVector &bbox, const Rcpp::List &crs)
{
    size_t nrow = nodes.size (), ncol = unique_vals.k_point.size ();

    if (static_cast <size_t> (ptList.size ()) != nrow)
        throw std::runtime_error ("points must have same size as nodes");

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);
    Rcpp::CharacterMatrix meta (Rcpp::Dimension (nrow, 5L));
    std::fill (meta.begin (), meta.end (), NA_STRING);

    std::vector <std::string> ptnames;
    ptnames.reserve (nodes.size ());

    unsigned int count = 0;
    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        // std::distance requires a static_cast which copies each instance and
        // slows this down by lots of orders of magnitude
        //unsigned int count = static_cast <unsigned int> (
        //        std::distance (nodes.begin (), ni));
        if (count % 1000 == 0)
            Rcpp::checkUserInterrupt ();

        // These are pointers and so need to be explicitly recreated each time,
        // otherwise they all just point to the initial value.
        Rcpp::NumericVector ptxy = Rcpp::NumericVector::create (NA_REAL, NA_REAL);
        ptxy.attr ("class") = Rcpp::CharacterVector::create ("XY", "POINT", "sfg");
        ptxy (0) = ni->second.lon;
        ptxy (1) = ni->second.lat;
        ptList (count) = ptxy;
        ptnames.push_back (std::to_string (ni->first));

        meta (count, 0L) = ni->second._version;
        meta (count, 1L) = ni->second._timestamp;
        meta (count, 2L) = ni->second._changeset;
        meta (count, 3L) = ni->second._uid;
        meta (count, 4L) = ni->second._user;

        for (auto kv_iter = ni->second.key_val.begin ();
                kv_iter != ni->second.key_val.end (); ++kv_iter)
        {
            const std::string &key = kv_iter->first;
            unsigned int ndi = unique_vals.k_point_index.at (key);
            kv_mat (count, ndi) = kv_iter->second;
        }
        count++;
    }
    if (unique_vals.k_point.size () > 0)
    {
        kv_mat.attr ("dimnames") = Rcpp::List::create (ptnames, unique_vals.k_point);
        kv_df = osm_convert::restructure_kv_mat (kv_mat, false);

        meta.attr ("dimnames") = Rcpp::List::create (ptnames, metanames);
        meta_df = meta;
    } else
        kv_df = R_NilValue;

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

//' rcpp_osmdata_sf
//'
//' Return OSM data in Simple Features format
//'
//' @param st Text contents of an overpass API query
//' @return Rcpp::List objects of OSM data
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_osmdata_sf (const std::string& st)
{
#ifdef DUMP_INPUT
    {
        std::ofstream dump ("./osmdata-sf.xml");
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
    const UniqueVals& unique_vals = xml.unique_vals ();

    std::vector <double> lons, lats;
    std::set <std::string> keyset; // must be ordered!
    Rcpp::List dimnames (0);
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    /* --------------------------------------------------------------
     * 1. Set up bbox and crs
     * --------------------------------------------------------------*/

    std::vector <std::string> colnames, rownames;
    colnames.push_back ("lon");
    colnames.push_back ("lat");

    Rcpp::NumericVector bbox = rcpp_get_bbox_sf (xml.x_min (), xml.y_min (),
                                              xml.x_max (), xml.y_max ());
    Rcpp::List crs = Rcpp::List::create (NA_STRING,
            Rcpp::CharacterVector::create (NA_STRING));
    crs (0) = "EPSG:4326";
    crs (1) = wkt;
    //Rcpp::List crs = Rcpp::List::create ((int) 4326, p4s);
    crs.attr ("names") = Rcpp::CharacterVector::create ("input", "wkt");
    crs.attr ("class") = "crs";

    /* --------------------------------------------------------------
     * 2. Extract OSM Relations
     * --------------------------------------------------------------*/

    Rcpp::List tempList = osm_sf::get_osm_relations (rels, nodes, ways, unique_vals,
            bbox, crs);
    Rcpp::List multipolygons = tempList [0];
    // the followin line errors because of ambiguous conversion
    //Rcpp::DataFrame kv_df_mp = tempList [1];
    Rcpp::List kv_df_mp = tempList [1];
    kv_df_mp.attr ("class") = "data.frame";
    Rcpp::List meta_df_mp = tempList [2];
    meta_df_mp.attr ("class") = "data.frame";
    Rcpp::List multilinestrings = tempList [3];
    Rcpp::List kv_df_ls = tempList [4];
    kv_df_ls.attr ("class") = "data.frame";
    Rcpp::List meta_df_ls = tempList [5];
    meta_df_ls.attr ("class") = "data.frame";

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
    Rcpp::DataFrame meta_df_polys;
    osm_sf::get_osm_ways (polyList, kv_df_polys, meta_df_polys,
            poly_ways, ways, nodes, unique_vals, "POLYGON", bbox, crs);

    Rcpp::List lineList (non_poly_ways.size ());
    Rcpp::DataFrame kv_df_lines;
    Rcpp::DataFrame meta_df_lines;
    osm_sf::get_osm_ways (lineList, kv_df_lines, meta_df_lines,
            non_poly_ways, ways, nodes, unique_vals, "LINESTRING", bbox, crs);

    /* --------------------------------------------------------------
     * 3. Extract OSM nodes
     * --------------------------------------------------------------*/

    Rcpp::List pointList (nodes.size ());
    // NOTE: kv_df_points is actually an Rcpp::CharacterMatrix, and the
    // following line *should* construct the wrapped data.frame version with
    // strings not factors, yet this does not work.
    //Rcpp::DataFrame kv_df_points = Rcpp::DataFrame::create (Rcpp::_["stringsAsFactors"] = false);
    Rcpp::DataFrame kv_df_points;
    Rcpp::DataFrame meta_df_points;
    osm_sf::get_osm_nodes (pointList, kv_df_points, meta_df_points,
            nodes, unique_vals, bbox, crs);


    /* --------------------------------------------------------------
     * 5. Collate all data
     * --------------------------------------------------------------*/

    Rcpp::List ret (16);
    ret [0] = bbox;
    ret [1] = pointList;
    ret [2] = kv_df_points;
    ret [3] = meta_df_points;
    ret [4] = lineList;
    ret [5] = kv_df_lines;
    ret [6] = meta_df_lines;
    ret [7] = polyList;
    ret [8] = kv_df_polys;
    ret [9] = meta_df_polys;
    ret [10] = multipolygons;
    ret [11] = kv_df_mp;
    ret [12] = meta_df_mp;
    ret [13] = multilinestrings;
    ret [14] = kv_df_ls;
    ret [15] = meta_df_ls;

    std::vector <std::string> retnames {"bbox", "points", "points_kv", "points_meta",
        "lines", "lines_kv", "lines_meta", "polygons", "polygons_kv", "polygons_meta",
        "multipolygons", "multipolygons_kv", "multipolygons_meta",
        "multilines", "multilines_kv", "multilines_meta"};
    ret.attr ("names") = retnames;

    return ret;
}
