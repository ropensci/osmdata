/***************************************************************************
 *  Project:    osmdatar
 *  File:       get-polygons.h
 *  Language:   C++
 *
 *  osmdatar is free software: you can redistribute it and/or modify it under
 *  the terms of the GNU General Public License as published by the Free
 *  Software Foundation, either version 3 of the License, or (at your option)
 *  any later version.
 *
 *  osmdatar is distributed in the hope that it will be useful, but WITHOUT ANY
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
 *  Description:    Class definition of XmlPolys
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
 *
 *  Compiler Options:   -std=c++11 
 ***************************************************************************/

#pragma once

#include "common.h"

// TODO: Implement Rcpp error control for asserts

/************************************************************************
 ************************************************************************
 **                                                                    **
 **                          CLASS::XMLPOLYS                           **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

class XmlPolys
{
    private:

        Nodes m_nodes;
        Ways m_ways;
        Relations m_relations;

    public:

        XmlPolys (const std::string& str)
        {
            m_nodes.clear ();
            m_ways.clear ();
            XmlDocPtr p = parseXML (str);
            traverseWays (p->first_node ());
        }

        ~XmlPolys ()
        {
            m_nodes.clear ();
            m_ways.clear ();
        }

        // Const accessors for members
        const Nodes& nodes() const { return m_nodes; }
        const Ways& ways() const { return m_ways; }
        const Relations& relations() const { return m_relations; }

    private:

        void traverseWays (XmlNodePtr pt);
        void traverseRelation (XmlNodePtr pt, RawRelation& rrel);
        void traverseWay (XmlNodePtr pt, RawWay& rway);
        void traverseNode (XmlNodePtr pt, Node& node);

}; // end Class::XmlPolys


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSEWAYS                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traverseWays (XmlNodePtr pt)
{
    RawRelation rrel;
    RawWay rway;
    Relation relation;
    OneWay way;
    Node node;

    for (XmlNodePtr it = pt->first_node (); it != nullptr; 
            it = it->next_sibling())
    {
        if (!strcmp (it->name(), "node"))
        {
            traverseNode (it, node);
            m_nodes.insert (std::make_pair (node.id, node));
        }
        else if (!strcmp (it->name(), "way"))
        {
            rway.key.clear();
            rway.value.clear();
            rway.nodes.clear();

            traverseWay (it, rway);
            assert (rway.key.size () == rway.value.size ());

            // This is much easier as explicit loop than with an iterator
            way.id = rway.id;
            way.name = way.type = "";
            way.key_val.clear();
            way.nodes.clear();
            for (size_t i=0; i<rway.key.size (); i++)
            {
                if (rway.key [i] == "name")
                    way.name = rway.value [i];
                else
                    way.key_val.insert (std::make_pair
                            (rway.key [i], rway.value [i]));
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
            assert (rrel.key.size () == rrel.value.size ());
            assert (rrel.ways.size () == rrel.outer.size ());

            relation.id = rrel.id;
            relation.key_val.clear();
            relation.ways.clear();
            for (size_t i=0; i<rrel.key.size (); i++)
                relation.key_val.insert (std::make_pair (rrel.key [i],
                            rrel.value [i]));
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

} // end function XmlPolys::traverseWays


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                     FUNCTION::TRAVERSERELATION                     **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traverseRelation (XmlNodePtr pt, RawRelation& rrel)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; 
            it = it->next_attribute())
    {
        if (!strcmp(it->name(), "k"))
            rrel.key.push_back (it->value());
        else if (!strcmp(it->name(), "v"))
            rrel.value.push_back (it->value());
        else if (!strcmp(it->name(), "id"))
            rrel.id = std::stoll(it->value());
        else if (!strcmp(it->name(), "ref"))
            rrel.ways.push_back (std::stoll(it->value()));
        else if (!strcmp(it->name(), "role"))
        {
            if (!strcmp(it->value(), "outer"))
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
} // end function XmlPolys::traverseRelation


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAY                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traverseWay (XmlNodePtr pt, RawWay& rway)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; 
            it = it->next_attribute())
    {
        if (!strcmp(it->name(), "k"))
            rway.key.push_back (it->value());
        else if (!strcmp(it->name(), "v"))
            rway.value.push_back (it->value());
        else if (!strcmp(it->name(), "id"))
            rway.id = std::stoll(it->value());
        else if (!strcmp(it->name(), "ref"))
            rway.nodes.push_back (std::stoll(it->value()));
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseWay (it, rway);
    }
} // end function XmlNodes::traverseWay


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traverseNode (XmlNodePtr pt, Node& node)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; 
            it = it->next_attribute())
    {
        if (!strcmp(it->name(), "id"))
            node.id = std::stoll(it->value());
        else if (!strcmp(it->name(), "lat"))
            node.lat = std::stof(it->value());
        else if (!strcmp(it->name(), "lon"))
            node.lon = std::stof(it->value());
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseNode (it, node);
    }
} // end function XmlNodes::traverseNode

