/***************************************************************************
 *  Project:    osmdatar
 *  File:       get-lines.h
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
 *  Description:    Class definition of XmlWays
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
 **                           CLASS::XMLWAYS                           **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

// APS make the class final so don't need to make destructor virtual
class XmlWays
{
    private:

        Nodes m_nodes;
        Ways m_ways;

    public:

        XmlWays (const std::string& str)
        {
          // APS empty m_nodes/m_ways constructed here, no need to explicitly clear
          XmlDocPtr p = parseXML (str);
            traverseWays (p->first_node());
        }

        // APS make the dtor virtual since compiler support for "final" is limited
        ~XmlWays ()
        {
          // APS m_nodes/m_ways destructed here, no need to explicitly clear
        }

        // Const accessors for members
        const Nodes& nodes() const { return m_nodes; }
        const Ways& ways() const { return m_ways; }

    private:

        void traverseWays (XmlNodePtr pt);
        void traverseWay (XmlNodePtr pt, RawWay& way);
        void traverseNode (XmlNodePtr pt, Node& node);

}; // end Class::XmlWays



/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAYS                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlWays::traverseWays (XmlNodePtr pt)
{
    RawWay rway;
    OneWay way;
    Node node;

    for (XmlNodePtr it = pt->first_node (); it != nullptr;
            it = it->next_sibling())
    {
        if (!strcmp(it->name(), "node"))
        {
            traverseNode (it, node);
            m_nodes.insert (std::make_pair (node.id, node));
        }
        else if (!strcmp(it->name(), "way"))
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
            way.nodes.reserve(rway.nodes.size());
            way.oneway = false;
            // TODO: oneway also exists in pairs:
            // k='oneway' v='yes'
            // k='oneway:bicycle' v='no'
            for (size_t i=0; i<rway.key.size (); i++)
            {
                if (rway.key [i] == "name")
                    way.name = rway.value [i];
                else if (rway.key [i] == "highway")
                    way.type = rway.value [i];
                else if (rway.key [i] == "oneway" && rway.value [i] == "yes")
                    way.oneway = true;
                else
                    way.key_val.insert (std::make_pair (rway.key [i],
                                rway.value [i]));
            }
            // Then copy nodes from rway to way.
            //std::copy(rway.nodes.begin (), rway.nodes.end(),
            //        std::back_inserter(way.nodes));
            way.nodes.swap (rway.nodes);
            m_ways.insert (std::make_pair (way.id, way));
        }
        else
        {
            traverseWays (it);
        }
    }

} // end function XmlWays::traverseWays


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAY                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlWays::traverseWay (XmlNodePtr pt, RawWay& rway)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; it =
            it->next_attribute())
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
} // end function XmlWays::traverseWay


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlWays::traverseNode (XmlNodePtr pt, Node& node)
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

