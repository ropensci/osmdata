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
Rcpp::List osm_sc::get_osm_relations (const Relations &rels, 
        const UniqueVals &unique_vals)
{
    std::vector <osmid_t> ids (rels.size ()); 

    size_t nrow_kv = 0, nrow_memb = 0;
    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
    {
        nrow_kv += itr->key_val.size ();
        nrow_memb += itr->relations.size ();
    }

    Rcpp::DataFrame kv_df (Rcpp::Dimension (nrow_kv, unique_vals.k_rel.size ()));
    Rcpp::DataFrame rel_df (Rcpp::Dimension (nrow_memb, 3));
    // rel_df has [rel ID, member ID, member role]

    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
    {
        Rcpp::checkUserInterrupt ();
        osm_str_vec relation_ways;
        std::vector <std::pair <std::string, std::string> > relation_kv;
        trace_relation (itr, relation_ways, relation_kv);

        unsigned int i = std::distance (rels.begin (), itr);
        ids [i] = itr->id;
        for (auto r = itr->relations.begin (); r != itr->relations.end (); ++r)
        {
            unsigned int j = i + static_cast <unsigned int> (
                    std::distance (itr->relations.begin (), r));
            rel_df (j, 0) = itr->id;
            rel_df (j, 1) = std::to_string (r->first);
            rel_df (j, 2) = r->second;
        }

        for (auto k = itr->key_val.begin (); k != itr->key_val.end (); ++k)
        {
            unsigned int j = i + static_cast <unsigned int> (
                    std::distance (itr->key_val.begin (), k));
            const std::string &key = k->first;
            long int coli = std::distance (unique_vals.k_rel.begin (),
                    unique_vals.k_rel.find (key));
            kv_df (j, static_cast <unsigned int> (coli)) = k->second;
        }
    }

    Rcpp::List ret (2);
    ret [0] = rel_df;
    ret [1] = kv_df;
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
void osm_sc::get_osm_ways (Rcpp::List &wayList, Rcpp::DataFrame &kv_df,
        const std::set <osmid_t> way_ids, const Ways &ways, const Nodes &nodes,
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
    for (auto wi = way_ids.begin (); wi != way_ids.end (); ++wi)
    {
        unsigned int count = static_cast <unsigned int> (
                std::distance (way_ids.begin (), wi));
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
    } // end for it over poly_ways

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
    const UniqueVals unique_vals = xml.unique_vals ();

    std::vector <double> lons, lats;
    std::set <std::string> keyset; // must be ordered!
    Rcpp::List dimnames (0);
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    /* --------------------------------------------------------------
     * 2. Extract OSM Relations
     * --------------------------------------------------------------*/

    Rcpp::List tempList = osm_sc::get_osm_relations (rels, unique_vals);
    Rcpp::List kv_df = tempList [1];
    kv_df.attr ("class") = "data.frame";

    /* --------------------------------------------------------------
     * 3. Extract OSM ways
     * --------------------------------------------------------------*/

    /*
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
    osm_sc::get_osm_ways (polyList, kv_df_polys, poly_ways, ways, nodes, unique_vals,
            "POLYGON", bbox, crs);

    Rcpp::List lineList (non_poly_ways.size ());
    Rcpp::DataFrame kv_df_lines;
    osm_sc::get_osm_ways (lineList, kv_df_lines, non_poly_ways, ways, nodes, unique_vals,
            "LINESTRING", bbox, crs);
    */

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

    Rcpp::List ret (1);
    ret [1] = kv_df;

    std::vector <std::string> retnames {"kv"};
    ret.attr ("names") = retnames;
    
    return ret;
}
