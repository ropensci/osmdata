/***************************************************************************
 *  Project:    osmdata
 *  File:       osmdata-data_frame.cpp
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
 *  osmdata.  If not, see <https://www.gnu.org/licenses/>.
 *
 *  Author:     Mark Padgham
 *  E-Mail:     mark.padgham@email.com
 *
 *  Description:    Modified version of 'osmdata-sf' to extract OSM data from an
 *                  object of class XmlData and return it in Rcpp::List format,
 *                  but in this case ignoring the actual geometric data. The
 *                  returned object contains key-value data only, for return
 *                  from the R function 'osmdata_data_frame'.
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdata)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#include "osmdata.h"

#include <Rcpp.h>
#include <list>
#include <string>

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
//' Return a dual Rcpp::DataFrame containing all OSM relations.
//'
//' @param rels Pointer to the vector of Relation objects
//' @param unique_vals Pointer to a UniqueVals object containing std::sets of all
//'       unique IDs and keys for each kind of OSM object (nodes, ways, rels).
//'
//' @return A dual Rcpp::DataFrame with the tags and metadata of the relations.
//'
//' @noRd
Rcpp::List osm_df::get_osm_relations (const Relations &rels,
        const UniqueVals &unique_vals)
{

    const unsigned int nmp = static_cast <unsigned int> (rels.size ());
    Rcpp::List res = Rcpp::List::create (R_NilValue, R_NilValue, R_NilValue);
    if (nmp == 0L) {
        return res;
    }

    size_t ncol = unique_vals.k_rel.size ();
    std::vector <std::string> rel_ids;
    rel_ids.reserve (nmp);

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nmp, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);
    Rcpp::CharacterMatrix meta (Rcpp::Dimension (nmp, 5L));
    std::fill (meta.begin (), meta.end (), NA_STRING);
    Rcpp::NumericMatrix center (Rcpp::Dimension (nmp, 2L));
    std::fill (center.begin (), center.end (), NA_REAL);

    unsigned int count = 0;

    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
    {
        if (count % 1000 == 0)
            Rcpp::checkUserInterrupt ();

        rel_ids.push_back (std::to_string (itr->id));

        meta (count, 0L) = itr->_version;
        meta (count, 1L) = itr->_timestamp;
        meta (count, 2L) = itr->_changeset;
        meta (count, 3L) = itr->_uid;
        meta (count, 4L) = itr->_user;

        center (count, 0L) = itr->_lat;
        center (count, 1L) = itr->_lon;

        osm_convert::get_value_mat_rel (itr, unique_vals, kv_mat, count++);
    }

    Rcpp::DataFrame kv_df;

    kv_mat.attr ("dimnames") = Rcpp::List::create (rel_ids, unique_vals.k_rel);
    kv_df = osm_convert::restructure_kv_mat (kv_mat, false);

    meta.attr ("dimnames") = Rcpp::List::create (rel_ids, metanames);
    center.attr ("dimnames") = Rcpp::List::create (rel_ids, centernames);

    res (0) = kv_df;
    res (1) = meta;
    res (2) = center;

    rel_ids.clear ();

    return res;
}

//' get_osm_ways
//'
//' Store key-val pairs for OSM ways as a list/data.frame
//'
//' @param kv_df Pointer to Rcpp::DataFrame to hold key-value pairs
//' @param way_ids Vector of <osmid_t> IDs of ways to trace
//' @param ways Pointer to all ways in data set
//' @param unique_vals pointer to all unique values (OSM IDs and keys) in data set
//'
//' @noRd
Rcpp::List osm_df::get_osm_ways (
        const std::set <osmid_t> &way_ids, const Ways &ways,
        const UniqueVals &unique_vals)
{

    size_t nrow = way_ids.size (), ncol = unique_vals.k_way.size ();
    Rcpp::List res = Rcpp::List::create (R_NilValue, R_NilValue, R_NilValue);
    if (nrow == 0L)
    {
        return res;
    }

    std::vector <std::string> waynames;
    waynames.reserve (nrow);

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);
    Rcpp::CharacterMatrix meta (Rcpp::Dimension (nrow, 5L));
    std::fill (meta.begin (), meta.end (), NA_STRING);
    Rcpp::NumericMatrix center (Rcpp::Dimension (nrow, 2L));
    std::fill (center.begin (), center.end (), NA_REAL);

    unsigned int count = 0;
    for (auto wi = way_ids.begin (); wi != way_ids.end (); ++wi)
    {
        if (count % 1000 == 0)
            Rcpp::checkUserInterrupt ();

        waynames.push_back (std::to_string (*wi));

        auto wj = ways.find (*wi);

        meta (count, 0L) = wj->second._version;
        meta (count, 1L) = wj->second._timestamp;
        meta (count, 2L) = wj->second._changeset;
        meta (count, 3L) = wj->second._uid;
        meta (count, 4L) = wj->second._user;

        center (count, 0L) = wj->second._lat;
        center (count, 1L) = wj->second._lon;

        osm_convert::get_value_mat_way (wj, unique_vals, kv_mat, count);
        count++;
    }

    Rcpp::DataFrame kv_df = R_NilValue;

    kv_mat.attr ("dimnames") = Rcpp::List::create (waynames, unique_vals.k_way);
    if (kv_mat.nrow () > 0 && kv_mat.ncol () > 0)
        kv_df = osm_convert::restructure_kv_mat (kv_mat, false);

    meta.attr ("dimnames") = Rcpp::List::create (waynames, metanames);
    center.attr ("dimnames") = Rcpp::List::create (waynames, centernames);

    res (0) = kv_df;
    res (1) = meta;
    res (2) = center;

    waynames.clear ();

    return res;
}

//' get_osm_nodes
//'
//' Store OSM nodes as `sf::POINT` objects
//'
//' @param kv_df Pointer to Rcpp::DataFrame to hold key-value pairs
//' @param nodes Pointer to all nodes in data set
//' @param unique_vals pointer to all unique values (OSM IDs and keys) in data set
//'
//' @noRd
Rcpp::List osm_df::get_osm_nodes (const Nodes &nodes,
        const UniqueVals &unique_vals)
{
    size_t nrow = nodes.size (), ncol = unique_vals.k_point.size ();

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);
    Rcpp::CharacterMatrix meta (Rcpp::Dimension (nrow, 5L));
    std::fill (meta.begin (), meta.end (), NA_STRING);
    Rcpp::NumericMatrix center (Rcpp::Dimension (nrow, 2L));
    std::fill (center.begin (), center.end (), NA_REAL);

    const size_t n = nodes.size ();
    std::vector <std::string> ptnames;
    ptnames.reserve (n);

    unsigned int count = 0;
    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        if (count % 1000 == 0)
            Rcpp::checkUserInterrupt ();

        ptnames.push_back (std::to_string (ni->first));

        meta (count, 0L) = ni->second._version;
        meta (count, 1L) = ni->second._timestamp;
        meta (count, 2L) = ni->second._changeset;
        meta (count, 3L) = ni->second._uid;
        meta (count, 4L) = ni->second._user;

        center(count, 0L) = ni->second.lat;
        center(count, 1L) = ni->second.lon;

        for (auto kv_iter = ni->second.key_val.begin ();
                kv_iter != ni->second.key_val.end (); ++kv_iter)
        {
            const std::string &key = kv_iter->first;
            unsigned int ndi = unique_vals.k_point_index.at (key);
            kv_mat (count, ndi) = kv_iter->second;
        }
        count++;
    }

    Rcpp::DataFrame kv_df = R_NilValue;
    Rcpp::List res = Rcpp::List::create (R_NilValue, R_NilValue, R_NilValue);

    if (unique_vals.k_point.size () > 0)
    {
        kv_mat.attr ("dimnames") = Rcpp::List::create (ptnames, unique_vals.k_point);
        kv_df = osm_convert::restructure_kv_mat (kv_mat, false);

        meta.attr ("dimnames") = Rcpp::List::create (ptnames, metanames);
        center.attr ("dimnames") = Rcpp::List::create (ptnames, centernames);

        res (0) = kv_df;
        res (1) = meta;
        res (2) = center;
    }

    ptnames.clear ();

    return res;
}


/************************************************************************
 ************************************************************************
 **                                                                    **
 **            THE FINAL RCPP FUNCTION CALLED BY osmdata_df            **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

//' rcpp_osmdata_df
//'
//' Return OSM data key-value pairs in series of data.frame objects, without any
//' spatial/geometrtic information.
//'
//' @param st Text contents of an overpass API query
//' @return Rcpp::List objects of OSM data
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_osmdata_df (const std::string& st)
{
    XmlData xml (st);

    const std::map <osmid_t, Node>& nodes = xml.nodes ();
    const std::map <osmid_t, OneWay>& ways = xml.ways ();
    const std::vector <Relation>& rels = xml.relations ();
    const UniqueVals& unique_vals = xml.unique_vals ();

    Rcpp::DataFrame kv_rels, kv_df_ways, kv_df_points;
    Rcpp::CharacterMatrix meta_rels, meta_ways, meta_nodes;
    Rcpp::NumericMatrix center_rels, center_ways, center_nodes;

    /* --------------------------------------------------------------
     * 1. Extract OSM Relations
     * --------------------------------------------------------------*/

    Rcpp::List data_rels = osm_df::get_osm_relations (rels, unique_vals);
    if (data_rels (0) != R_NilValue)
    {
        kv_rels = Rcpp::as <Rcpp::DataFrame> (data_rels (0));
        meta_rels = Rcpp::as <Rcpp::CharacterMatrix> (data_rels (1));
        center_rels = Rcpp::as <Rcpp::NumericMatrix> (data_rels (2));
    }

    /* --------------------------------------------------------------
     * 2. Extract OSM ways
     * --------------------------------------------------------------*/

    std::set <osmid_t> way_ids;
    for (auto itw = ways.begin (); itw != ways.end (); ++itw)
    {
        way_ids.insert ((*itw).first);
    }

    Rcpp::List data_ways = osm_df::get_osm_ways (way_ids, ways, unique_vals);
    if (data_ways (0) != R_NilValue)
    {
        kv_df_ways = Rcpp::as <Rcpp::DataFrame> (data_ways (0));
        meta_ways = Rcpp::as <Rcpp::CharacterMatrix> (data_ways (1));
        center_ways = Rcpp::as <Rcpp::NumericMatrix> (data_ways (2));
    }

    /* --------------------------------------------------------------
     * 3. Extract OSM nodes
     * --------------------------------------------------------------*/

    Rcpp::List data_nodes = osm_df::get_osm_nodes (nodes, unique_vals);
    if (data_nodes (0) != R_NilValue)
    {
        kv_df_points = Rcpp::as <Rcpp::DataFrame> (data_nodes (0));
        meta_nodes = Rcpp::as <Rcpp::CharacterMatrix> (data_nodes (1));
        center_nodes = Rcpp::as <Rcpp::NumericMatrix> (data_nodes (2));
    }

    /* --------------------------------------------------------------
     * 4. Collate all data
     * --------------------------------------------------------------*/

    Rcpp::List ret (9);
    ret [0] = kv_df_points;
    ret [1] = kv_df_ways;
    ret [2] = kv_rels;
    ret [3] = meta_nodes;
    ret [4] = meta_ways;
    ret [5] = meta_rels;
    ret [6] = center_nodes;
    ret [7] = center_ways;
    ret [8] = center_rels;

    std::vector <std::string> retnames {"points_kv", "ways_kv", "rels_kv",
        "points_meta", "ways_meta", "rels_meta",
        "points_center", "ways_center", "rels_center"};
    ret.attr ("names") = retnames;

    return ret;
}
