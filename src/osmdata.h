/***************************************************************************
 *  Project:    osmdata
 *  File:       osmdatap.h
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
 *  Description:    Class definition of XmlData
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#pragma once

#include "common.h"

//const std::string crs = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0";
const std::string p4s = "+proj=longlat +datum=WGS84 +no_defs";

typedef std::vector <std::vector <float> > float_arr2;
typedef std::vector <std::vector <std::vector <float> > > float_arr3;
typedef std::vector <std::vector <std::string> > string_arr2;
typedef std::vector <std::vector <std::vector <std::string> > > string_arr3;
typedef std::vector <std::vector <osmid_t> > osmt_arr2;
typedef std::vector <std::pair <osmid_t, std::string> > osm_str_vec;
typedef std::vector <std::pair <osmid_t, std::string> >::iterator it_osm_str_vec;

/************************************************************************
 ************************************************************************
 **                                                                    **
 **                          CLASS::XMLDATA                            **
 **                                                                    **
 ************************************************************************
 ************************************************************************/


class XmlData
{
    private:

        Nodes m_nodes;
        Ways m_ways;
        Relations m_relations;
        UniqueVals m_unique;
        float xmin=FLOAT_MAX, xmax=-FLOAT_MAX, ymin=FLOAT_MAX, ymax=-FLOAT_MAX;

    public:

        XmlData (const std::string& str)
        {
            // APS empty m_nodes/m_ways/m_relations constructed here, no need to explicitly clear
            XmlDocPtr p = parseXML (str);
            traverseWays (p->first_node ());
        }

        // APS make the dtor virtual since compiler support for "final" is limited
        virtual ~XmlData ()
        {
          // APS m_nodes/m_ways/m_relations destructed here, no need to explicitly clear
        }

        // Const accessors for members
        const Nodes& nodes() const { return m_nodes; }
        const Ways& ways() const { return m_ways; }
        const Relations& relations() const { return m_relations; }
        const UniqueVals& unique_vals() const { return m_unique; }
        const float x_min() { return xmin;  }
        const float x_max() { return xmax;  }
        const float y_min() { return ymin;  }
        const float y_max() { return ymax;  }

    private:

        void traverseWays (XmlNodePtr pt);
        void traverseRelation (XmlNodePtr pt, RawRelation& rrel);
        void traverseWay (XmlNodePtr pt, RawWay& rway);
        void traverseNode (XmlNodePtr pt, RawNode& rnode);

}; // end Class::XmlData


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSEWAYS                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlData::traverseWays (XmlNodePtr pt)
{
    RawRelation rrel;
    RawWay rway;
    Relation relation;
    OneWay way;
    RawNode rnode;
    Node node;

    for (XmlNodePtr it = pt->first_node (); it != nullptr;
            it = it->next_sibling())
    {
        if (!strcmp (it->name(), "node"))
        {
            rnode.key.clear ();
            rnode.value.clear ();

            traverseNode (it, rnode);
            if (rnode.key.size () != rnode.value.size ())
                throw std::runtime_error ("sizes of keys and values differ");

            // Only insert unique nodes
            if (m_unique.id_node.find (rnode.id) == m_unique.id_node.end ())
            {
                if (rnode.lon < xmin) xmin = rnode.lon;
                if (rnode.lon > xmax) xmax = rnode.lon;
                if (rnode.lat < ymin) ymin = rnode.lat;
                if (rnode.lat > ymax) ymax = rnode.lat;
                m_unique.id_node.insert (rnode.id);
                node.id = rnode.id;
                node.lat = rnode.lat;
                node.lon = rnode.lon;
                node.key_val.clear ();
                for (size_t i=0; i<rnode.key.size (); i++)
                {
                    node.key_val.insert (std::make_pair
                            (rnode.key [i], rnode.value [i]));
                    m_unique.k_point.insert (rnode.key [i]); // only inserts unique keys
                }
                m_nodes.insert (std::make_pair (node.id, node));
            }
        }
        else if (!strcmp (it->name(), "way"))
        {
            rway.key.clear ();
            rway.value.clear ();
            rway.nodes.clear ();

            traverseWay (it, rway);
            if (rway.key.size () != rway.value.size ())
                throw std::runtime_error ("sizes of keys and values differ");

            if (m_unique.id_way.find (rway.id) == m_unique.id_way.end ())
            {
                m_unique.id_way.insert (rway.id);
                way.id = rway.id;
                way.key_val.clear();
                way.nodes.clear();
                for (size_t i=0; i<rway.key.size (); i++)
                {
                    way.key_val.insert (std::make_pair
                            (rway.key [i], rway.value [i]));
                    if (rway.nodes.front () == rway.nodes.back ())
                        m_unique.k_poly.insert (rway.key [i]);
                    else
                        m_unique.k_way.insert (rway.key [i]);
                }
                // Then copy nodes from rway to way.
                way.nodes.swap (rway.nodes);
                m_ways.insert (std::make_pair (way.id, way));
            }
        }
        else if (!strcmp (it->name(), "relation"))
        {
            rrel.key.clear();
            rrel.value.clear();
            rrel.role_way.clear();
            rrel.role_node.clear();
            rrel.ways.clear();
            rrel.nodes.clear();
            rrel.member_type = "";
            rrel.ispoly = false;

            traverseRelation (it, rrel);
            if (rrel.key.size () != rrel.value.size ())
                throw std::runtime_error ("sizes of keys and values differ");
            if (rrel.ways.size () != rrel.role_way.size ())
                throw std::runtime_error ("size of ways and roles differ");
            if (rrel.nodes.size () != rrel.role_node.size ())
                throw std::runtime_error ("size of nodes and roles differ");

            if (m_unique.id_rel.find (rrel.id) == m_unique.id_rel.end ())
            {
                m_unique.id_rel.insert (rrel.id);
                relation.id = rrel.id;
                relation.key_val.clear();
                relation.ways.clear();
                relation.ispoly = rrel.ispoly;
                for (size_t i=0; i<rrel.key.size (); i++)
                {
                    relation.key_val.insert (std::make_pair (rrel.key [i],
                                rrel.value [i]));
                    m_unique.k_poly.insert (rrel.key [i]);
                    if (rrel.key [i] == "type")
                        relation.rel_type = rrel.value [i];
                }
                for (size_t i=0; i<rrel.ways.size (); i++)
                    relation.ways.push_back (std::make_pair (rrel.ways [i],
                                rrel.role_way [i]));
                for (size_t i=0; i<rrel.nodes.size (); i++)
                    relation.nodes.push_back (std::make_pair (rrel.nodes [i],
                                rrel.role_node [i]));
                m_relations.push_back (relation);
            }
        }
        else
        {
            traverseWays (it);
        }
    }

} // end function XmlData::traverseWays


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                     FUNCTION::TRAVERSERELATION                     **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlData::traverseRelation (XmlNodePtr pt, RawRelation& rrel)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "k"))
            rrel.key.push_back (it->value());
        else if (!strcmp (it->name(), "v"))
            rrel.value.push_back (it->value());
        else if (!strcmp (it->name(), "id"))
            rrel.id = std::stoll(it->value());
        else if (!strcmp (it->name(), "type"))
            rrel.member_type = it->value ();
        else if (!strcmp (it->name(), "ref"))
        {
            if (rrel.member_type == "node")
                rrel.nodes.push_back (std::stoll (it->value ()));
            else if (rrel.member_type == "way")
                rrel.ways.push_back (std::stoll (it->value ()));
            else
                throw std::runtime_error ("unknown member_type");
        } else if (!strcmp (it->name(), "role"))
        {
            if (rrel.member_type == "node")
                rrel.role_node.push_back (it->value ());
            else if (rrel.member_type == "way")
                rrel.role_way.push_back (it->value ());
            else
                throw std::runtime_error ("unknown member_type");
            // Not all OSM Multipolygons have (key="type",
            // value="multipolygon"): For example, (key="type",
            // value="boundary") are often multipolygons. The things they all
            // have are "inner" and "outer" roles.
            if (!strcmp (it->value(), "inner") || !strcmp (it->value(), "outer"))
                rrel.ispoly = true;
        }
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseRelation (it, rrel);
    }
} // end function XmlData::traverseRelation


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAY                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlData::traverseWay (XmlNodePtr pt, RawWay& rway)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "k"))
            rway.key.push_back (it->value());
        else if (!strcmp (it->name(), "v"))
            rway.value.push_back (it->value());
        else if (!strcmp (it->name(), "id"))
            rway.id = std::stoll(it->value());
        else if (!strcmp (it->name(), "ref"))
            rway.nodes.push_back (std::stoll(it->value()));
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseWay (it, rway);
    }
} // end function XmlData::traverseWay


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlData::traverseNode (XmlNodePtr pt, RawNode& rnode)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "id"))
            rnode.id = std::stoll(it->value());
        else if (!strcmp (it->name(), "lat"))
            rnode.lat = std::stof(it->value());
        else if (!strcmp (it->name(), "lon"))
            rnode.lon = std::stof(it->value());
        else if (!strcmp (it->name(), "k"))
            rnode.key.push_back (it->value ());
        else if (!strcmp (it->name(), "v"))
            rnode.value.push_back (it->value ());
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseNode (it, rnode);
    }
} // end function XmlData::traverseNode


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                          OTHER FUNCTIONS                           **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

void trace_multipolygon (Relations::const_iterator itr_rel, const Ways &ways,
        const Nodes &nodes, float_arr2 &lon_vec, float_arr2 &lat_vec,
        string_arr2 &rowname_vec, std::vector <std::string> &ids);

void trace_multilinestring (Relations::const_iterator itr_rel, const std::string role,
        const Ways &ways, const Nodes &nodes, float_arr2 &lon_vec, 
        float_arr2 &lat_vec, string_arr2 &rowname_vec, std::vector <osmid_t> &ids);

osmid_t trace_way (const Ways &ways, const Nodes &nodes, osmid_t first_node,
        const osmid_t &wayi_id, std::vector <float> &lons, 
        std::vector <float> &lats, std::vector <std::string> &rownames);

void get_value_vec (Relations::const_iterator itr, 
        const std::set <std::string> keyset, std::vector <std::string> &value_vec);

void check_geom_arrs (const float_arr3 &lon_arr, const float_arr3 &lat_arr,
        const string_arr3 &rowname_arr);

void clean_geom_arrs (float_arr3 &lon_arr, float_arr3 &lat_arr,
        string_arr3 &rowname_arr);

void clear_id_vecs (std::vector <std::vector <osmid_t> > &id_vec_ls, 
    std::vector <std::vector <std::string> > &id_vec_mp);

void clean_kv_arrs (std::vector <std::vector <std::string> > &value_arr_mp,
        std::vector <std::vector <std::string> > &value_arr_ls);

void clean_geom_vecs (float_arr2 &lon_vec, float_arr2 &lat_vec,
        string_arr2 &rowname_vec);
