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
Rcpp::DataFrame osm_df::get_osm_relations (const Relations &rels, 
        const UniqueVals &unique_vals)
{
    std::vector <std::string> ids_mp; 

    const unsigned int nmp = rels.size ();

    size_t ncol = unique_vals.k_rel.size ();

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nmp, ncol));
    unsigned int count = 0;

    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
    {
        if (count % 1000 == 0)
            Rcpp::checkUserInterrupt ();


        osm_convert::get_value_mat_rel (itr, unique_vals, kv_mat, count++);
    }

    Rcpp::DataFrame kv_df;
    if (nmp > 0)
    {
        kv_mat.attr ("names") = unique_vals.k_rel;
        kv_df = osm_convert::restructure_kv_mat (kv_mat, false);
    } else
        kv_df = R_NilValue;

    return kv_df;
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
void osm_df::get_osm_ways (Rcpp::DataFrame &kv_df,
        const std::set <osmid_t> &way_ids, const Ways &ways,
        const UniqueVals &unique_vals)
{

    size_t nrow = way_ids.size (), ncol = unique_vals.k_way.size ();

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);
    unsigned int count = 0;
    for (auto wi = way_ids.begin (); wi != way_ids.end (); ++wi)
    {
        if (count % 1000 == 0)
            Rcpp::checkUserInterrupt ();
        auto wj = ways.find (*wi);
        osm_convert::get_value_mat_way (wj, unique_vals, kv_mat, count);
        count++;
    }

    kv_df = R_NilValue;
    if (way_ids.size () > 0)
    {
        kv_mat.attr ("names") = unique_vals.k_way;
        kv_mat.attr ("dimnames") = Rcpp::List::create (waynames, unique_vals.k_way);
        if (kv_mat.nrow () > 0 && kv_mat.ncol () > 0)
            kv_df = osm_convert::restructure_kv_mat (kv_mat, false);
    }
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
void osm_df::get_osm_nodes (Rcpp::DataFrame &kv_df,
        const Nodes &nodes, const UniqueVals &unique_vals)
{
    size_t nrow = nodes.size (), ncol = unique_vals.k_point.size ();

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);

    unsigned int count = 0;
    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        if (count % 1000 == 0)
            Rcpp::checkUserInterrupt ();

        ptnames.push_back (std::to_string (ni->first));
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
        kv_mat.attr ("names") = unique_vals.k_point;
        kv_df = osm_convert::restructure_kv_mat (kv_mat, false);
    } else
        kv_df = R_NilValue;

    ptnames.clear ();
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

    /* --------------------------------------------------------------
     * 1. Extract OSM Relations
     * --------------------------------------------------------------*/

    Rcpp::DataFrame kv_rels = osm_df::get_osm_relations (rels, unique_vals);

    /* --------------------------------------------------------------
     * 2. Extract OSM ways
     * --------------------------------------------------------------*/

    std::set <osmid_t> way_ids;
    for (auto itw = ways.begin (); itw != ways.end (); ++itw)
    {
        way_ids.insert ((*itw).first);
    }

    Rcpp::List polyList (way_ids.size ());
    Rcpp::DataFrame kv_df_ways;
    osm_df::get_osm_ways (kv_df_ways, way_ids, ways, unique_vals);

    /* --------------------------------------------------------------
     * 3. Extract OSM nodes
     * --------------------------------------------------------------*/

    Rcpp::DataFrame kv_df_points;
    osm_df::get_osm_nodes (kv_df_points, nodes, unique_vals);

    /* --------------------------------------------------------------
     * 4. Collate all data
     * --------------------------------------------------------------*/

    Rcpp::List ret (3);
    ret [0] = kv_df_points;
    ret [1] = kv_df_ways;
    ret [2] = kv_rels;

    std::vector <std::string> retnames {"points_kv", "ways_kv", "rels_kv"};
    ret.attr ("names") = retnames;
    
    return ret;
}
