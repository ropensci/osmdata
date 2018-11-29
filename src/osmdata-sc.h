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
    /* Two main options to efficiently store-on-reading are:
     * 1. Use std::maps for everything, but this would ultimately require
     * copying all entries over to an appropriate Rcpp::Matrix class; or
     * 2. Setting up individual vectors for each (id, key, val), and just
     * Rcpp::wrap-ing them for return.
     * The second is more efficient, and so is implemented here, via an initial
     * read to determine the sizes of the vectors (in Counters), then a second
     * read to store them.
     */

    public:

        struct Counters {
            // Initial function getSizes does an initial scan of the XML doc and
            // establishes the sizes of everything with these counters
            int nnodes, nnode_kv,
                nways, nway_kv, nedges,
                nrels, nrel_kv, nrel_memb;
        };

        struct Vectors {
            // Vectors used to store the data, with sizes allocated according to
            // the values of Counters
            //
            // vectors for key-val pairs in object table:
            std::vector <std::string>
                rel_kv_id, rel_key, rel_val,
                rel_memb_id, rel_memb_type, rel_ref, rel_role,
                way_id, way_key, way_val,
                node_id, node_key, node_val;

            // vectors for edge and object_link_edge tables:
            std::vector <std::string> vx0, vx1, edge, object;
            // vectors for vertex table
            std::vector <double> vx, vy;
            std::vector <std::string> vert_id;
        };

    private:

        Counters counters;
        Vectors vectors;

        // Number of nodes in each way
        std::unordered_map <int, int> waySizes;

    public:

        double xmin = DOUBLE_MAX, xmax = -DOUBLE_MAX,
              ymin = DOUBLE_MAX, ymax = -DOUBLE_MAX;

        XmlDataSC (const std::string& str)
        {
            // APS empty m_nodes/m_ways/m_relations constructed here, no need to explicitly clear
            XmlDocPtr p = parseXML (str);

            zeroCounters (counters);
            getSizes (p->first_node ());
            vectorsResize (vectors, counters);
            Rcpp::Rcout << "n(nodes, ways, rels, edges) = (" << counters.nnodes << ", " <<
                counters.nways << ", " << counters.nrels << ", " << counters.nedges << "); kv = (" <<
                counters.nnode_kv << ", " << counters.nway_kv << ", " << counters.nrel_kv << ")" <<
                std::endl;

            zeroCounters (counters);
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

        const std::vector <std::string>& get_rel_kv_id() const { return vectors.rel_kv_id;  }
        const std::vector <std::string>& get_rel_key() const { return vectors.rel_key;  }
        const std::vector <std::string>& get_rel_val() const { return vectors.rel_val;  }
        const std::vector <std::string>& get_rel_memb_id() const { return vectors.rel_memb_id;  }
        const std::vector <std::string>& get_rel_memb_type() const { return vectors.rel_memb_type;  }
        const std::vector <std::string>& get_rel_ref() const { return vectors.rel_ref;  }
        const std::vector <std::string>& get_rel_role() const { return vectors.rel_role;  }
        const std::vector <std::string>& get_way_id() const { return vectors.way_id;  }
        const std::vector <std::string>& get_way_key() const { return vectors.way_key;  }
        const std::vector <std::string>& get_way_val() const { return vectors.way_val;  }
        const std::vector <std::string>& get_node_id() const { return vectors.node_id;  }
        const std::vector <std::string>& get_node_key() const { return vectors.node_key;  }
        const std::vector <std::string>& get_node_val() const { return vectors.node_val;  }

        // vectors for edge and object_link_edge tables:
        const std::vector <std::string>& get_vx0 () const { return vectors.vx0;  }
        const std::vector <std::string>& get_vx1 () const { return vectors.vx1;  }
        const std::vector <std::string>& get_edge () const { return vectors.edge;  }
        const std::vector <std::string>& get_object () const { return vectors.object;  }

        // vectors for vertex table
        const std::vector <std::string>& get_vert_id () const { return vectors.vert_id;  }
        const std::vector <double>& get_vx () const { return vectors.vx;  }
        const std::vector <double>& get_vy () const { return vectors.vy;  }

    private:

        void zeroCounters (Counters& counters);
        void getSizes (XmlNodePtr pt);
        void vectorsResize (Vectors& vectors, Counters &counters);

        void countRelation (XmlNodePtr pt);
        void countWay (XmlNodePtr pt);
        void countNode (XmlNodePtr pt);

        void traverseWays (XmlNodePtr pt); // The primary function

        void traverseRelation (XmlNodePtr pt);
        void traverseWay (XmlNodePtr pt, int& node_num);
        void traverseNode (XmlNodePtr pt);

}; // end Class::XmlDataSC

inline void XmlDataSC::zeroCounters (Counters& counters)
{
    counters.nnodes = 0;
    counters.nnode_kv = 0;

    counters.nways = 0;
    counters.nway_kv = 0;
    counters.nedges = 0;

    counters.nrels = 0;
    counters.nrel_kv = 0;
    counters.nrel_memb = 0;
}

inline void XmlDataSC::vectorsResize (Vectors& vectors, Counters &counters)
{
    vectors.rel_kv_id.resize (counters.nrel_kv);
    vectors.rel_key.resize (counters.nrel_kv);
    vectors.rel_val.resize (counters.nrel_kv);

    vectors.rel_memb_id.resize (counters.nrel_memb);
    vectors.rel_memb_type.resize (counters.nrel_memb);
    vectors.rel_ref.resize (counters.nrel_memb);
    vectors.rel_role.resize (counters.nrel_memb);

    vectors.way_id.resize (counters.nway_kv);
    vectors.way_key.resize (counters.nway_kv);
    vectors.way_val.resize (counters.nway_kv);

    vectors.node_id.resize (counters.nnode_kv);
    vectors.node_key.resize (counters.nnode_kv);
    vectors.node_val.resize (counters.nnode_kv);

    vectors.vx0.resize (counters.nedges);
    vectors.vx1.resize (counters.nedges);
    vectors.edge.resize (counters.nedges);
    vectors.object.resize (counters.nedges);

    vectors.vx.resize (counters.nnodes);
    vectors.vy.resize (counters.nnodes);
    vectors.vert_id.resize (counters.nnodes);
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
            counters.nnodes++;
        }
        else if (!strcmp (it->name(), "way"))
        {
            int wayLength = counters.nedges;
            countWay (it); // increments nway_kv, nedges
            wayLength = counters.nedges - wayLength;
            counters.nedges--; // counts nodes, so each way has nedges = 1 - nnodes
            waySizes.emplace (counters.nways, wayLength);
            counters.nways++;
        }
        else if (!strcmp (it->name(), "relation"))
        {
            countRelation (it); // increments nrel_kv, nrel_memb
            counters.nrels++;
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
    // Relations can have either members or key-val pairs, counted here with
    // seperate counters
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "type"))
            counters.nrel_memb++;
        if (!strcmp (it->name(), "k"))
            counters.nrel_kv++;
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
    // Ways can have either member nodes, called "ref", or key-val pairs
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "k"))
            counters.nway_kv++;
        else if (!strcmp (it->name(), "ref"))
            counters.nedges++;
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
            counters.nnode_kv++;
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
    RawWay rway;

    for (XmlNodePtr it = pt->first_node (); it != nullptr;
            it = it->next_sibling())
    {
        if (!strcmp (it->name(), "node"))
        {
            traverseNode (it);
            counters.nnodes++;

            /*
            if (rnode.lon < xmin) xmin = rnode.lon;
            if (rnode.lon > xmax) xmax = rnode.lon;
            if (rnode.lat < ymin) ymin = rnode.lat;
            if (rnode.lat > ymax) ymax = rnode.lat;
            */

        } else if (!strcmp (it->name(), "way"))
        {
            int node_num = 0;
            traverseWay (it, node_num);
            counters.nedges--;
            counters.nways++;
        }
        else if (!strcmp (it->name(), "relation"))
        {
            traverseRelation (it);
            counters.nrels++;
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

inline void XmlDataSC::traverseRelation (XmlNodePtr pt)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "id"))
        {
            vectors.rel_kv_id [counters.nrel_kv] = it->value();
            vectors.rel_memb_id [counters.nrel_memb] = it->value();
        } else if (!strcmp (it->name(), "k"))
            vectors.rel_key [counters.nrel_kv] = it->value();
        else if (!strcmp (it->name(), "v"))
            vectors.rel_val [counters.nrel_kv++] = it->value();
        else if (!strcmp (it->name(), "type"))
            vectors.rel_memb_type [counters.nrel_memb] = it->value();
        else if (!strcmp (it->name(), "ref"))
            vectors.rel_ref [counters.nrel_memb] = it->value();
        else if (!strcmp (it->name(), "role"))
            vectors.rel_role [counters.nrel_memb++] = it->value();
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseRelation (it);
    }
} // end function XmlDataSC::traverseRelation


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAY                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlDataSC::traverseWay (XmlNodePtr pt, int& node_num)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "id"))
        {
            vectors.way_id [counters.nway_kv] = it->value();
            vectors.object [counters.nedges] = it->value();
        } else if (!strcmp (it->name(), "k"))
            vectors.way_key [counters.nway_kv] = it->value();
        else if (!strcmp (it->name(), "v"))
            vectors.way_val [counters.nway_kv++] = it->value();
        else if (!strcmp (it->name(), "ref"))
        {
            if (node_num == 0)
                vectors.vx0 [counters.nedges] = it->value();
            else
            {
                vectors.vx1 [counters.nedges] = it->value();
                vectors.edge [counters.nedges] = random_id (10);
                if (node_num != waySizes.at (counters.nways))
                    vectors.vx0 [counters.nedges + 1] = it->value();
                counters.nedges++;
            }
            node_num++;
        }
    }

    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseWay (it, node_num);
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
            vectors.vert_id [counters.nnodes] = it->value();
        else if (!strcmp (it->name(), "lat"))
            vectors.vy [counters.nnodes] = std::stod(it->value());
        else if (!strcmp (it->name(), "lon"))
            vectors.vx [counters.nnodes] = std::stod(it->value());
        else if (!strcmp (it->name(), "k"))
            vectors.node_key [counters.nnode_kv] = it->value();
        else if (!strcmp (it->name(), "v"))
        {
            vectors.node_val [counters.nnode_kv] = it->value();
            vectors.node_id [counters.nnode_kv] = vectors.vert_id [counters.nnodes]; // will always be pre-set
        }
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseNode (it);
    }
} // end function XmlDataSC::traverseNode
