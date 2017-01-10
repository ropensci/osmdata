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

const std::string crs = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0";

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
        UniqueKeys m_keys;

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
        const UniqueKeys& keys() const { return m_keys; }

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

            node.id = rnode.id;
            node.lat = rnode.lat;
            node.lon = rnode.lon;
            node.key_val.clear ();
            for (size_t i=0; i<rnode.key.size (); i++)
            {
                node.key_val.insert (std::make_pair
                        (rnode.key [i], rnode.value [i]));
                m_keys.k_point.insert (rnode.key [i]); // only inserts unique keys
            }
            m_nodes.insert (std::make_pair (node.id, node));
        }
        else if (!strcmp (it->name(), "way"))
        {
            rway.key.clear ();
            rway.value.clear ();
            rway.nodes.clear ();

            traverseWay (it, rway);
            if (rway.key.size () != rway.value.size ())
                throw std::runtime_error ("sizes of keys and values differ");

            // This is much easier as explicit loop than with an iterator
            way.id = rway.id;
            way.key_val.clear();
            way.nodes.clear();
            bool isWayPoly = false;
            if (rway.nodes.front () == rway.nodes.back ())
                isWayPoly = true;
            for (size_t i=0; i<rway.key.size (); i++)
            {
                //if (rway.key [i] == "name")
                //    way.name = rway.value [i];
                //else
                    way.key_val.insert (std::make_pair
                            (rway.key [i], rway.value [i]));
                if (!isWayPoly)
                    m_keys.k_line.insert (rway.key [i]);
                else
                    m_keys.k_poly.insert (rway.key [i]);
            }
            // Then copy nodes from rway to way.
            way.nodes.swap (rway.nodes);
            m_ways.insert (std::make_pair (way.id, way));
        }
        else if (!strcmp (it->name(), "relation"))
        {
            rrel.key.clear();
            rrel.value.clear();
            rrel.ways.clear();
            rrel.outer.clear();

            traverseRelation (it, rrel);
            if (rrel.key.size () != rrel.value.size ())
                throw std::runtime_error ("sizes of keys and values differ");
            if (rrel.ways.size () != rrel.outer.size ())
                throw std::runtime_error ("size of ways and outer differ");

            relation.id = rrel.id;
            relation.key_val.clear();
            relation.ways.clear();
            for (size_t i=0; i<rrel.key.size (); i++)
            {
                relation.key_val.insert (std::make_pair (rrel.key [i],
                            rrel.value [i]));
                m_keys.k_poly.insert (rrel.key [i]);
            }
            for (size_t i=0; i<rrel.ways.size (); i++)
                relation.ways.push_back (std::make_pair (rrel.ways [i],
                            rrel.outer [i]));
            m_relations.push_back (relation);
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
        else if (!strcmp (it->name(), "ref"))
            rrel.ways.push_back (std::stoll(it->value()));
        else if (!strcmp (it->name(), "role"))
        {
            if (!strcmp (it->value(), "outer"))
                rrel.outer.push_back (true);
            else
                rrel.outer.push_back (false);
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

