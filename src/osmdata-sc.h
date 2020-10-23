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
 *  osm-router.  If not, see <https://www.gnu.org/licenses/>.
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
            size_t nnodes, nnode_kv,
                nways, nway_kv, nedges,
                nrels, nrel_kv, nrel_memb;
            std::string id;
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

        struct Maps {
            std::unordered_map <std::string, std::vector <std::string> >
                rel_membs, way_membs;
        };

    private:

        Counters counters;
        Vectors vectors;
        Maps maps;

        // Number of nodes in each way, and ways in each rel
        std::unordered_map <std::string, size_t> waySizes, relSizes;

    public:

        XmlDataSC (const std::string& str)
        {
            // APS empty m_nodes/m_ways/m_relations constructed here, no need to explicitly clear
            XmlDocPtr p = parseXML (str);

            zeroCounters ();
            getSizes (p->first_node ());
            vectorsResize ();

            zeroCounters ();
            traverseWays (p->first_node ());
        }

        // APS make the dtor virtual since compiler support for "final" is limited
        virtual ~XmlDataSC ()
        {
        }

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

        const std::unordered_map <std::string, std::vector <std::string> >&
            get_rel_membs () const { return maps.rel_membs; }
        const std::unordered_map <std::string, std::vector <std::string> >&
            get_way_membs () const { return maps.way_membs; }

    private:

        void zeroCounters ();
        void getSizes (XmlNodePtr pt);
        void vectorsResize ();

        void countRelation (XmlNodePtr pt);
        void countWay (XmlNodePtr pt);
        void countNode (XmlNodePtr pt);

        void traverseWays (XmlNodePtr pt); // The primary function

        void traverseRelation (XmlNodePtr pt, size_t &memb_num);
        void traverseWay (XmlNodePtr pt, size_t& node_num);
        void traverseNode (XmlNodePtr pt);

}; // end Class::XmlDataSC

inline void XmlDataSC::zeroCounters ()
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

inline void XmlDataSC::vectorsResize ()
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

    for (auto m: relSizes)
    {
        maps.rel_membs.emplace (m.first, std::vector <std::string> (m.second));
    }
    for (auto m: waySizes)
    {
        maps.way_membs.emplace (m.first, std::vector <std::string> (m.second));
    }
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
            size_t wayLength = counters.nedges;
            countWay (it); // increments nway_kv, nedges
            wayLength = counters.nedges - wayLength;
            counters.nedges--; // counts nodes, so each way has nedges = 1 - nnodes
            waySizes.emplace (counters.id, wayLength);
            counters.nways++;
        }
        else if (!strcmp (it->name(), "relation"))
        {
            size_t relLength = counters.nrel_memb;
            countRelation (it); // increments nrel_kv, nrel_memb
            relLength = counters.nrel_memb - relLength;
            relSizes.emplace (counters.id, relLength);
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
    // separate counters
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "id"))
            counters.id = it->value();
        else if (!strcmp (it->name(), "type"))
            counters.nrel_memb++;
        else if (!strcmp (it->name(), "k"))
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
        if (!strcmp (it->name(), "id"))
            counters.id = it->value();
        else if (!strcmp (it->name(), "k"))
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
    for (XmlNodePtr it = pt->first_node (); it != nullptr;
            it = it->next_sibling())
    {
        if (!strcmp (it->name(), "node"))
        {
            traverseNode (it);
            counters.nnodes++;
        } else if (!strcmp (it->name(), "way"))
        {
            size_t node_num = 0;
            traverseWay (it, node_num);
            counters.nways++;
        }
        else if (!strcmp (it->name(), "relation"))
        {
            size_t memb_num = 0;
            traverseRelation (it, memb_num);
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

inline void XmlDataSC::traverseRelation (XmlNodePtr pt, size_t &memb_num)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "id"))
        {
            // These values are always first, so all other clauses are executed
            // after this one
            counters.id = it->value();
        } else if (!strcmp (it->name(), "k"))
        {
            vectors.rel_kv_id [counters.nrel_kv] = counters.id;
            vectors.rel_key [counters.nrel_kv] = it->value();
        } else if (!strcmp (it->name(), "v"))
            vectors.rel_val [counters.nrel_kv++] = it->value();
        else if (!strcmp (it->name(), "type"))
        {
            vectors.rel_memb_type [counters.nrel_memb] = it->value();
            vectors.rel_memb_id [counters.nrel_memb] = counters.id;
        } else if (!strcmp (it->name(), "ref"))
        {
            vectors.rel_ref [counters.nrel_memb] = it->value();
            // TODO: Is there a safer alternative to next line?
            maps.rel_membs.at (counters.id) [memb_num++] = it->value();
        } else if (!strcmp (it->name(), "role"))
            vectors.rel_role [counters.nrel_memb++] = it->value();
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseRelation (it, memb_num);
    }
} // end function XmlDataSC::traverseRelation


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAY                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlDataSC::traverseWay (XmlNodePtr pt, size_t& node_num)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr;
            it = it->next_attribute())
    {
        if (!strcmp (it->name(), "id"))
        {
            // These values are always first, so all other clauses are executed
            // after this one
            counters.id = it->value();
        } else if (!strcmp (it->name(), "k"))
        {
            vectors.way_id [counters.nway_kv] = counters.id;
            vectors.way_key [counters.nway_kv] = it->value();
        } else if (!strcmp (it->name(), "v"))
            vectors.way_val [counters.nway_kv++] = it->value();
        else if (!strcmp (it->name(), "ref"))
        {
            maps.way_membs.at (counters.id) [node_num] = it->value();
            if (node_num == 0)
                vectors.vx0 [counters.nedges] = it->value();
            else
            {
                vectors.vx1 [counters.nedges] = it->value();
                vectors.object [counters.nedges] = counters.id;
                vectors.edge [counters.nedges] = random_id (10);
                counters.nedges++;
                if (counters.nedges < vectors.vx0.size ())
                {
                    vectors.vx0 [counters.nedges] = it->value();
                }
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
            vectors.node_id [counters.nnode_kv] =
                vectors.vert_id [counters.nnodes]; // will always be pre-set
            counters.nnode_kv++;
        }
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseNode (it);
    }
} // end function XmlDataSC::traverseNode


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       ADDITIONAL FUNCTIONS                         **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

Rcpp::List rel_membs_as_list (XmlDataSC &xml);
Rcpp::List way_membs_as_list (XmlDataSC &xml);
