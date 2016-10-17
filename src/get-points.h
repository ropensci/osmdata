/***************************************************************************
 *  Project:    osmdatar
 *  File:       get-points.h
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
 *  Description:    Class definition of XmlNodes
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
//
/************************************************************************
 ************************************************************************
 **                                                                    **
 **                           CLASS::XMLNODES                          **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

// APS make the class final so don't need to make destructor virtual
class XmlNodes
{
    private:

        Nodes m_nodes;

    public:

        XmlNodes (const std::string& str)
        {
            // APS empty m_nodes constructed here, no need to explicitly clear
            XmlDocPtr p = parseXML (str);
            traverseNodes (p->first_node());
        }

        // APS make the dtor virtual since compiler support for "final" is limited
        virtual ~XmlNodes ()
        {
          // APS m_nodes destructed here, no need to explicitly clear
        }

        const Nodes& nodes() const { return m_nodes; }

    private:

        void traverseNodes (XmlNodePtr pt);
        void traverseNode (XmlNodePtr pt, Node& node);
}; // end Class::XmlNodes


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODES                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlNodes::traverseNodes (XmlNodePtr pt)
{
    std::unordered_set <osmid_t> nodeIDs;
    Node node;

    for (XmlNodePtr it = pt->first_node (); it != nullptr;
            it = it->next_sibling())
    {
        if (!strcmp (it->name(), "node"))
        {
            node.key = "";
            node.value = "";
            node.key_val.clear();
            traverseNode (it, node);
            if (nodeIDs.find (node.id) == nodeIDs.end ())
            {
                nodeIDs.insert (node.id);
                m_nodes.insert (std::make_pair (node.id, node));
            }
        }
        else
        {
            traverseNodes (it);
        }
    }
}


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlNodes::traverseNode (XmlNodePtr pt,
        Node& node)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; it = it->next_attribute())
    {
        if (!strcmp(it->name(), "id"))
            node.id = std::stoll(it->value());
        else if (!strcmp(it->name(), "lat"))
            node.lat = std::stof(it->value());
        else if (!strcmp(it->name(), "lon"))
            node.lon = std::stof(it->value());
        else if (!strcmp(it->name(), "k"))
            node.key = it->value();
        else if (!strcmp(it->name(), "v"))
        {
            // Note that values sometimes exist without keys, but the following
            // still inserts the pair because values **always** come after keys.
            node.value = it->value();
            node.key_val.insert (std::make_pair (node.key, node.value));
            node.key = "";
            node.value = "";
        }

    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseNode (it, node);
    }

} // end function XmlNodes::traverseNode

