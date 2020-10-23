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
#include "osmdata-sc.h"

// Function to generate IDs for the edges in each way
std::string random_id (size_t len) {
    auto randchar = []() -> char
    {
        const char charset[] = \
            "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
        const size_t max_index = (sizeof(charset) - 1);
        //return charset [ rand() % max_index ];
        size_t i = static_cast <size_t> (floor (Rcpp::runif (1) [0] * max_index));
        return charset [i];
    };
    std::string str (len, 0);
    std::generate_n (str.begin(), len, randchar);
    return str;
}

Rcpp::List rel_membs_as_list (XmlDataSC &xml)
{
    std::unordered_map <std::string, std::vector <std::string> >
        rel_membs = xml.get_rel_membs ();

    Rcpp::List ret (rel_membs.size ());
    std::vector <std::string> retnames (rel_membs.size ());

    size_t i1 = 0; // std::vector index is size_t
    int i2 = 0; // Rcpp index is int
    for (auto m: rel_membs)
    {
        retnames [i1++] = m.first;
        ret [i2++] = m.second;
    }
    ret.attr ("names") = retnames;

    return ret;
}

Rcpp::List way_membs_as_list (XmlDataSC &xml)
{
    std::unordered_map <std::string, std::vector <std::string> >
        way_membs = xml.get_way_membs ();

    Rcpp::List ret (way_membs.size ());
    std::vector <std::string> retnames (way_membs.size ());

    size_t i1 = 0;
    int i2 = 0;
    for (auto m: way_membs)
    {
        retnames [i1] = m.first;
        ret [i2++] = m.second;
    }
    ret.attr ("names") = retnames;

    return ret;
}

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

    XmlDataSC xml (st);

    Rcpp::DataFrame vertex = Rcpp::DataFrame::create (
            Rcpp::Named ("x_") = xml.get_vx (),
            Rcpp::Named ("y_") = xml.get_vy (),
            Rcpp::Named ("vertex_") = xml.get_vert_id (),
            Rcpp::_["stringsAsFactors"] = false );

    Rcpp::DataFrame edge = Rcpp::DataFrame::create (
            Rcpp::Named (".vx0") = xml.get_vx0 (),
            Rcpp::Named (".vx1") = xml.get_vx1 (),
            Rcpp::Named ("edge_") = xml.get_edge (),
            Rcpp::_["stringsAsFactors"] = false );

    Rcpp::DataFrame oXe = Rcpp::DataFrame::create (
            Rcpp::Named ("edge_") = xml.get_edge (),
            Rcpp::Named ("object_") = xml.get_object (),
            Rcpp::_["stringsAsFactors"] = false );

    Rcpp::DataFrame obj_node = Rcpp::DataFrame::create (
            Rcpp::Named ("vertex_") = xml.get_node_id (),
            Rcpp::Named ("key") = xml.get_node_key (),
            Rcpp::Named ("value") = xml.get_node_val (),
            Rcpp::_["stringsAsFactors"] = false );

    Rcpp::DataFrame obj_way = Rcpp::DataFrame::create (
            Rcpp::Named ("object_") = xml.get_way_id (),
            Rcpp::Named ("key") = xml.get_way_key (),
            Rcpp::Named ("value") = xml.get_way_val (),
            Rcpp::_["stringsAsFactors"] = false );

    Rcpp::DataFrame obj_rel_memb = Rcpp::DataFrame::create (
            Rcpp::Named ("relation_") = xml.get_rel_memb_id (),
            Rcpp::Named ("member") = xml.get_rel_ref (),
            Rcpp::Named ("type") = xml.get_rel_memb_type (),
            Rcpp::Named ("role") = xml.get_rel_role (),
            Rcpp::_["stringsAsFactors"] = false );

    Rcpp::DataFrame obj_rel_kv = Rcpp::DataFrame::create (
            Rcpp::Named ("relation_") = xml.get_rel_kv_id (),
            Rcpp::Named ("key") = xml.get_rel_key (),
            Rcpp::Named ("value") = xml.get_rel_val (),
            Rcpp::_["stringsAsFactors"] = false );

    Rcpp::List rel_membs = rel_membs_as_list (xml),
        way_membs = way_membs_as_list (xml);

    Rcpp::List ret (9);
    ret [0] = vertex;
    ret [1] = edge;
    ret [2] = oXe;
    ret [3] = obj_node;
    ret [4] = obj_way; // The SC object table
    ret [5] = obj_rel_memb;
    ret [6] = obj_rel_kv;
    ret [7] = Rcpp::as <Rcpp::List> (way_membs);
    ret [8] = Rcpp::as <Rcpp::List> (rel_membs);

    std::vector <std::string> retnames {"vertex", 
                                        "edge", "object_link_edge",
                                        "nodes", "object",
                                        "relation_members",
                                        "relation_properties",
                                        "way_membs", "rel_membs"};
    ret.attr ("names") = retnames;
    
    return ret;
}
