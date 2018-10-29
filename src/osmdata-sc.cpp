/***************************************************************************
 *  Project:    osmdata
 *  File:       osmdata-sc.cpp
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
 *                  it in Rcpp::List format.
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#include "osmdata.h"

#include <Rcpp.h>


/************************************************************************
 ************************************************************************
 **                                                                    **
 **          1. PRIMARY FUNCTIONS TO TRACE WAYS AND RELATIONS          **
 **                                                                    **
 ************************************************************************
 ************************************************************************/


//' get_osm_relations
//'
//' Return an Rcpp::List containing all OSM relations.
//'
//' @param rels Pointer to the vector of Relation objects
//' @param nodes Pointer to the vector of node objects
//' @param ways Pointer to the vector of way objects
//' @param unique_vals Pointer to a UniqueVals object containing std::sets of all
//'       unique IDs and keys for each kind of OSM object (nodes, ways, rels).
//'
//' @return An Rcpp::List
//' 
//' @noRd 
Rcpp::List osm_sc::get_osm_relations (const Relations &rels) 
{
    std::vector <osmid_t> ids (rels.size ()); 

    size_t nrow_kv = 0, nrow_memb = 0;
    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
    {
        nrow_kv += itr->key_val.size ();
        nrow_memb += itr->ways.size ();
    }

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow_kv, 3));
    Rcpp::CharacterMatrix rel_mat (Rcpp::Dimension (nrow_memb, 3));
    // rel_mat has [rel ID, member ID, member role]

    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
    {
        Rcpp::checkUserInterrupt ();
        osm_str_vec relation_ways;
        std::vector <std::pair <std::string, std::string> > relation_kv;
        trace_relation (itr, relation_ways, relation_kv);

        unsigned int i = std::distance (rels.begin (), itr);
        ids [i] = itr->id;
        for (auto r = relation_ways.begin (); r != relation_ways.end (); ++r)
        {
            unsigned int j = i + static_cast <unsigned int> (
                    std::distance (relation_ways.begin (), r));
            rel_mat (j, 0) = std::to_string (itr->id); // relation ID
            rel_mat (j, 1) = std::to_string (r->first); // ref ID of component obj
            rel_mat (j, 2) = r->second; // role of component
        }

        for (auto k = itr->key_val.begin (); k != itr->key_val.end (); ++k)
        {
            unsigned int j = i + static_cast <unsigned int> (
                    std::distance (itr->key_val.begin (), k));
            kv_mat (j, 0) = std::to_string (itr->id);
            kv_mat (j, 1) = k->first;
            kv_mat (j, 2) = k->second;
        }
    }
    std::vector <std::string> relnames {"id", "ref", "role"};
    std::vector <std::string> nullvec;
    rel_mat.attr ("dimnames") = Rcpp::List::create (nullvec, relnames);

    std::vector <std::string> kvnames {"id", "key", "value"};
    kv_mat.attr ("dimnames") = Rcpp::List::create (nullvec, kvnames);

    Rcpp::List ret (2);
    ret [0] = rel_mat;
    ret [1] = kv_mat;
    return ret;
}

//' get_osm_ways
//'
//' @param wayList Pointer to Rcpp::List to hold the resultant geometries
//' @param kv_df Pointer to Rcpp::DataFrame to hold key-value pairs
//' @param way_ids Vector of <osmid_t> IDs of ways to trace
//' @param ways Pointer to all ways in data set
//' @param nodes Pointer to all nodes in data set
//' @param unique_vals pointer to all unique values (OSM IDs and keys) in data set
//' @param bbox Pointer to the bbox needed for `sf` construction
//' @param crs Pointer to the crs needed for `sf` construction
//' 
//' @noRd 
void osm_sc::get_osm_ways (Rcpp::DataFrame &way_df, Rcpp::DataFrame &kv_df,
        const Ways &ways)
{
    int nrefs = 0, nkv = 0;
    for (auto wi = ways.begin (); wi != ways.end (); ++wi)
    {
        nrefs += wi->second.nodes.size ();
        nkv += wi->second.key_val.size ();
    }

    Rcpp::CharacterMatrix way_mat (Rcpp::Dimension (nrefs, 2));
    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nkv, 3));

    // TODO: Impelement these properly with std::distance
    int count_w = 0, count_k = 0;
    for (auto wi = ways.begin (); wi != ways.end (); ++wi)
    {
        Rcpp::checkUserInterrupt ();
        unsigned int i = static_cast <unsigned int> (
                std::distance (ways.begin (), wi));

        for (auto wj = wi->second.nodes.begin ();
                wj != wi->second.nodes.end (); ++wj)
        {
            way_mat (count_w, 0) = std::to_string (wi->first);
            way_mat (count_w++, 1) = std::to_string (*wj);
        }
        
        for (auto kj = wi->second.key_val.begin ();
                kj != wi->second.key_val.end (); ++kj)
        {
            kv_mat (count_k, 0) = std::to_string (wi->first);
            kv_mat (count_k, 1) = kj->first;
            kv_mat (count_k++, 2) = kj->second;
        }
    }
    std::vector <std::string> relnames {"id", "ref"};
    std::vector <std::string> nullvec;
    way_mat.attr ("dimnames") = Rcpp::List::create (nullvec, relnames);
    way_df = way_mat;

    std::vector <std::string> kvnames {"id", "key", "value"};
    kv_mat.attr ("dimnames") = Rcpp::List::create (nullvec, kvnames);
    kv_df = kv_mat;
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
void osm_sc::get_osm_nodes (Rcpp::List &ptList, Rcpp::DataFrame &kv_df,
        const Nodes &nodes, const UniqueVals &unique_vals, 
        const Rcpp::NumericVector &bbox, const Rcpp::List &crs)
{
    size_t nrow = nodes.size (), ncol = unique_vals.k_point.size ();

    if (static_cast <size_t> (ptList.size ()) != nrow)
        throw std::runtime_error ("points must have same size as nodes");

    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);

    std::vector <std::string> ptnames;
    ptnames.reserve (nodes.size ());
    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        unsigned int count = static_cast <unsigned int> (
                std::distance (nodes.begin (), ni));
        Rcpp::checkUserInterrupt ();
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
            unsigned int ndi = static_cast <unsigned int> (
                    std::distance (unique_vals.k_point.begin (),
                    unique_vals.k_point.find (key)));
            kv_mat (count, ndi) = kv_iter->second;
        }
    }
    if (unique_vals.k_point.size () > 0)
    {
        kv_mat.attr ("dimnames") = Rcpp::List::create (ptnames, unique_vals.k_point);
        kv_df = osm_convert::restructure_kv_mat (kv_mat, false);
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
 **            THE FINAL RCPP FUNCTION CALLED BY osmdata_sc            **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

//' rcpp_osmdata_sc
//'
//' Return OSM data in silicate (SC) format
//'
//' @param st Text contents of an overpass API query
//' @return Rcpp::List objects of OSM data
//' 
//' @noRd 
// [[Rcpp::export]]
Rcpp::List rcpp_osmdata_sc (const std::string& st)
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

    std::vector <double> lons, lats;
    std::set <std::string> keyset; // must be ordered!
    Rcpp::List dimnames (0);
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    /* --------------------------------------------------------------
     * 2. Extract OSM Relations
     * --------------------------------------------------------------*/

    Rcpp::List tempList = osm_sc::get_osm_relations (rels);
    Rcpp::DataFrame rel_df, rel_kv_df;
    rel_df = tempList [0];
    if (rel_df.nrow () == 0)
        rel_df = R_NilValue;
    rel_kv_df = tempList [1];
    if (rel_kv_df.nrow () == 0)
        rel_kv_df = R_NilValue;

    /* --------------------------------------------------------------
     * 3. Extract OSM ways
     * --------------------------------------------------------------*/

    Rcpp::DataFrame way_df, way_kv_df;
    osm_sc::get_osm_ways (way_df, way_kv_df, ways);

    /* --------------------------------------------------------------
     * 3. Extract OSM nodes
     * --------------------------------------------------------------*/

    /*
    Rcpp::List pointList (nodes.size ());
    Rcpp::DataFrame kv_df_points;
    osm_sc::get_osm_nodes (pointList, kv_df_points, nodes, unique_vals, bbox, crs);
    */


    /* --------------------------------------------------------------
     * 5. Collate all data
     * --------------------------------------------------------------*/

    Rcpp::List ret (4);
    ret [0] = rel_df;
    ret [1] = rel_kv_df;
    ret [2] = way_df;
    ret [3] = way_kv_df;

    std::vector <std::string> retnames {"rel", "rel_kv", "way", "way_kv"};
    ret.attr ("names") = retnames;
    
    return ret;
}
