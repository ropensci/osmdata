/***************************************************************************
 *  Project:    osmdata
 *  File:       osmdatap-sc.h
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
 *  Description:    Silicate (SC) parsing of OSM XML file
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdata)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#pragma once

#include <Rcpp.h>

#include "common.h"
#include "get-bbox.h"
#include "trace-osm.h"
#include "convert-osm-rcpp.h"

std::string random_id (size_t len);

/************************************************************************
 ************************************************************************
 **                                                                    **
 **                         CLASS::XMLDATASC                           **
 **                                                                    **
 ************************************************************************
 ************************************************************************/


class XmlDataSC
{
    public:
        struct Counters {
            int nnodes, nnode_kv,
                nways, nway_kv,
                nrels, nrel_kv, nrel_memb,
                nedges;
        };

    private:
        Counters counters;
        int nnodes, nnode_kv,
            nways, nway_kv,
            nrels, nrel_kv, nrel_memb,
            nedges;

        /* Two main options to efficiently store-on-reading are:
         * 1. Use std::maps for everything, but this would ultimately require
         * copying all entries over to an appropriate Rcpp::Matrix class; or
         * 2. Setting up individual vectors for each (id, key, val), and just
         * Rcpp::wrap-ing them for return.
         * The second is more efficient, even though the code is somewhat
         * ungainly, and so is implemented here, via an initial read to
         * determine the sizes of the vectors, then a second read to store them.
         */

        // vectors for key-val pairs in object table:
        std::vector <std::string> m_rel_id, m_rel_key, m_rel_val,
            m_way_id, m_way_key, m_way_val,
            m_node_id, m_node_key, m_node_val;

        // vectors for edge and object_link_edge tables:
        std::vector <std::string> m_vx0, m_vx1, m_edge, m_object;
        // vectors for vertex table
        std::vector <double> m_vx, m_vy;
        std::vector <std::string> m_vert_id;

        // Number of nodes in each way
        std::unordered_map <int, int> waySizes;

    public:

        double xmin = DOUBLE_MAX, xmax = -DOUBLE_MAX,
              ymin = DOUBLE_MAX, ymax = -DOUBLE_MAX;

        XmlDataSC (const std::string& str)
        {
            // APS empty m_nodes/m_ways/m_relations constructed here, no need to explicitly clear
            XmlDocPtr p = parseXML (str);
            nnodes = 0;
            nways = 0;
            nrels = 0;
            nnode_kv = 0;
            nway_kv = 0;
            nrel_kv = 0;
            nrel_memb = 0;
            nedges = 0;
            getSizes (p->first_node ());
            Rcpp::Rcout << "n(nodes, ways, rels, edges) = (" << nnodes << ", " <<
                nways << ", " << nrels << ", " << nedges << "); kv = (" <<
                nnode_kv << ", " << nway_kv << ", " << nrel_kv << ")" <<
                std::endl;

            m_rel_id.resize (nrel_kv);
            m_rel_key.resize (nrel_kv);
            m_rel_val.resize (nrel_kv);
            m_way_id.resize (nway_kv);
            m_way_key.resize (nway_kv);
            m_way_val.resize (nway_kv);
            m_node_id.resize (nnode_kv);
            m_node_key.resize (nnode_kv);
            m_node_val.resize (nnode_kv);

            m_vx0.resize (nedges);
            m_vx1.resize (nedges);
            m_edge.resize (nedges);
            m_object.resize (nedges);

            m_vx.resize (nnodes);
            m_vy.resize (nnodes);
            m_vert_id.resize (nnodes);

            nnodes = 0;
            nways = 0;
            nrels = 0;
            nnode_kv = 0;
            nway_kv = 0;
            nrel_kv = 0;
            nrel_memb = 0;
            nedges = 0;

            traverseWays (p->first_node ());
        }

        // APS make the dtor virtual since compiler support for "final" is limited
        virtual ~XmlDataSC ()
        {
          // APS m_nodes/m_ways/m_relations destructed here, no need to explicitly clear
        }

        // Const accessors for members
        double x_min() { return xmin;  }
        double x_max() { return xmax;  }
        double y_min() { return ymin;  }
        double y_max() { return ymax;  }

        const std::vector <std::string>& get_rel_id() const { return m_rel_id;  }
        const std::vector <std::string>& get_rel_key() const { return m_rel_key;  }
        const std::vector <std::string>& get_rel_val() const { return m_rel_val;  }
        const std::vector <std::string>& get_way_id() const { return m_way_id;  }
        const std::vector <std::string>& get_way_key() const { return m_way_key;  }
        const std::vector <std::string>& get_way_val() const { return m_way_val;  }
        const std::vector <std::string>& get_node_id() const { return m_node_id;  }
        const std::vector <std::string>& get_node_key() const { return m_node_key;  }
        const std::vector <std::string>& get_node_val() const { return m_node_val;  }

        // vectors for edge and object_link_edge tables:
        const std::vector <std::string>& get_vx0 () const { return m_vx0;  }
        const std::vector <std::string>& get_vx1 () const { return m_vx1;  }
        const std::vector <std::string>& get_edge () const { return m_edge;  }
        const std::vector <std::string>& get_object () const { return m_object;  }

        // vectors for vertex table
        const std::vector <std::string>& get_vert_id () const { return m_vert_id;  }
        const std::vector <double>& get_vx () const { return m_vx;  }
        const std::vector <double>& get_vy () const { return m_vy;  }

    private:

        void zeroCounters (Counters& counters);
        void getSizes (XmlNodePtr pt);
        void countRelation (XmlNodePtr pt);
        void countWay (XmlNodePtr pt);
        void countNode (XmlNodePtr pt);
        void traverseWays (XmlNodePtr pt);
        void traverseRelation (XmlNodePtr pt, RawRelation& rrel);
        void traverseWay (XmlNodePtr pt, RawWay& rway);
        void traverseNode (XmlNodePtr pt);

}; // end Class::XmlDataSC

inline void XmlDataSC::zeroCounters (Counters& counters)
{
    counters.nnodes = 0;
    counters.nways = 0;
    counters.nrels = 0;
    counters.nnode_kv = 0;
    counters.nway_kv = 0;
    counters.nrel_kv = 0;
    counters.nrel_memb = 0;
    counters.nedges = 0;
}

/************************************************************************
 ************************************************************************
 **                                                                    **
 **                         FUNCTION::GETSIZES                         **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlDataSC::getSizes (XmlNodePtr pt)
{
    for (XmlNodePtr it = pt->first_node (); it != nullptr;
            it = it->next_sibling())
    {
        if (!strcmp (it->name(), "node"))
        {
            countNode (it); // increments nnode_kv
            nnodes++;
        }
        else if (!strcmp (it->name(), "way"))
        {
            int wayLength = nedges;
            countWay (it); // increments nway_kv, nedges
            wayLength = nedges - wayLength;
            nedges--; // counts nodes, so each way has nedges = 1 - nnodes
            waySizes.emplace (nways, wayLength);
            nways++;
        }
        else if (!strcmp (it->name(), "relation"))
        {
            countRelation (it); // increments nrel_kv, nrel_memb
            nrels++;
        }
        else
        {
            getSizes (it);
        }
    }
} // end function XmlDataSC::getSizes


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::COUNTRELATION                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlDataSC::countRelation (XmlNodePtr pt)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "rel"))
            nrel_memb++;
        if (!strcmp (it->name(), "k"))
            nrel_kv++;
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        countRelation (it);
    }
} // end function XmlDataSC::countRelation


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                          FUNCTION::COUNTWAY                        **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlDataSC::countWay (XmlNodePtr pt)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "k"))
            nway_kv++;
        else if (!strcmp (it->name(), "ref"))
            nedges++;
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        countWay (it);
    }
} // end function XmlDataSC::countWay


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::COUNTNODE                         **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlDataSC::countNode (XmlNodePtr pt)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "k"))
            nnode_kv++;
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        countNode (it);
    }
} // end function XmlDataSC::countNode


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSEWAYS                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlDataSC::traverseWays (XmlNodePtr pt)
{
    RawRelation rrel;
    RawWay rway;

    for (XmlNodePtr it = pt->first_node (); it != nullptr;
            it = it->next_sibling())
    {
        if (!strcmp (it->name(), "node"))
        {
            traverseNode (it);
            nnodes++;

            /*
            if (rnode.lon < xmin) xmin = rnode.lon;
            if (rnode.lon > xmax) xmax = rnode.lon;
            if (rnode.lat < ymin) ymin = rnode.lat;
            if (rnode.lat > ymax) ymax = rnode.lat;
            */

        } else if (!strcmp (it->name(), "way"))
        {
            rway.key.clear ();
            rway.value.clear ();
            rway.nodes.clear ();

            traverseWay (it, rway);

            for (size_t i=0; i<rway.key.size (); i++)
            {
                m_way_id [nway_kv] = std::to_string (rway.id);
                m_way_key [nway_kv] = rway.key [i];
                m_way_val [nway_kv++] = rway.value [i];
            }

            for (auto n = rway.nodes.begin ();
                    n != std::prev (rway.nodes.end ()); n++)
            {
                m_vx0 [nedges] = std::to_string (*n);
                m_vx1 [nedges] = std::to_string (*std::next (n));
                m_edge [nedges] = random_id (10);
                m_object [nedges++] = std::to_string (rway.id);
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

            for (size_t i=0; i<rrel.key.size (); i++)
            {
                m_rel_id [nrel_kv] = std::to_string (rrel.id);
                m_rel_key [nrel_kv] = rrel.key [i];
                m_rel_val [nrel_kv++] = rrel.value [i];
            }
        }
        else
        {
            traverseWays (it);
        }
    }

} // end function XmlDataSC::traverseWays


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                     FUNCTION::TRAVERSERELATION                     **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlDataSC::traverseRelation (XmlNodePtr pt, RawRelation& rrel)
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
            else if (rrel.member_type == "relation")
                rrel.relations.push_back (std::stoll (it->value ()));
            else
                throw std::runtime_error ("unknown member_type");
        } else if (!strcmp (it->name(), "role"))
        {
            if (rrel.member_type == "node")
                rrel.role_node.push_back (it->value ());
            else if (rrel.member_type == "way")
                rrel.role_way.push_back (it->value ());
            else if (rrel.member_type == "relation")
                rrel.role_relation.push_back (it->value ());
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
} // end function XmlDataSC::traverseRelation


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAY                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlDataSC::traverseWay (XmlNodePtr pt, RawWay& rway)
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
} // end function XmlDataSC::traverseWay


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlDataSC::traverseNode (XmlNodePtr pt)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "id"))
            m_vert_id [nnodes] = it->value();
        else if (!strcmp (it->name(), "lat"))
            m_vy [nnodes] = std::stod(it->value());
        else if (!strcmp (it->name(), "lon"))
            m_vx [nnodes] = std::stod(it->value());
        else if (!strcmp (it->name(), "k"))
            m_node_key [nnode_kv] = it->value();
        else if (!strcmp (it->name(), "v"))
        {
            m_node_val [nnode_kv] = it->value();
            m_node_id [nnode_kv] = m_vert_id [nnodes]; // will always be pre-set
        }
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseNode (it);
    }
} // end function XmlDataSC::traverseNode
