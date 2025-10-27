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

// sf::st_crs(4326)$wkt
const std::string wkt =
"GEOGCRS[\"WGS 84\",\n\
    ENSEMBLE[\"World Geodetic System 1984 ensemble\",\n\
        MEMBER[\"World Geodetic System 1984 (Transit)\"],\n\
        MEMBER[\"World Geodetic System 1984 (G730)\"],\n\
        MEMBER[\"World Geodetic System 1984 (G873)\"],\n\
        MEMBER[\"World Geodetic System 1984 (G1150)\"],\n\
        MEMBER[\"World Geodetic System 1984 (G1674)\"],\n\
        MEMBER[\"World Geodetic System 1984 (G1762)\"],\n\
        ELLIPSOID[\"WGS 84\",6378137,298.257223563,\n\
            LENGTHUNIT[\"metre\",1]],\n\
        ENSEMBLEACCURACY[2.0]],\n\
    PRIMEM[\"Greenwich\",0,\n\
        ANGLEUNIT[\"degree\",0.0174532925199433]],\n\
    CS[ellipsoidal,2],\n\
        AXIS[\"geodetic latitude (Lat)\",north,\n\
            ORDER[1],\n\
            ANGLEUNIT[\"degree\",0.0174532925199433]],\n\
        AXIS[\"geodetic longitude (Lon)\",east,\n\
            ORDER[2],\n\
            ANGLEUNIT[\"degree\",0.0174532925199433]],\n\
    USAGE[\n\
        SCOPE[\"Horizontal component of 3D system.\"],\n\
        AREA[\"World.\"],\n\
        BBOX[-90,-180,90,180]],\n\
    ID[\"EPSG\",4326]]";

const Rcpp::CharacterVector metanames = {"_version", "_timestamp", "_changeset", "_uid", "_user"};
const Rcpp::CharacterVector centernames = {"_lat", "_lon"};

/************************************************************************
 ************************************************************************
 **                                                                    **
 **                      STRUCTURE OF THESE FILES                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************
 *
 * 1. osmdata.h = Class definition of XmlData that reads initial XML structure
 * 2. trace_osm.h = Primary functions to trace ways and relations (pure C++)
 *      2a. trace_multipolygon ()
 *      2b. trace_multilinestring ()
 *      2c. trace_way ()
 * 3. convert_osm_rcpp.h = Functions to convert C++ objects to Rcpp::List objects
 *      3a. trace_way_nmat () (here coz it uses Rcpp)
 *      3b. get_value_mat_way ()
 *      3c. get_value_mat_rel ()
 *      3d. convert_poly_linestring_to_Rcpp ()
 *      3e. restructure_kv_mat ()
 * 4. osmdata.cpp
 *      5c. get_osm_relations ()
 *      5d. get_osm_ways ()
 *      5e. get_osm_nodes ()
 *      5a. rcpp_osmdata () - The final Rcpp function called by osmdata_sf
 *
 * ----------------------------------------------------------------------
 *
 *  The calling hierarchy extends generally from bottom to top as follows:
 *  rcpp_osmdata () {
 *      -> get_osm_relations ()
 *      {
 *          -> trace_multipolygon ()
 *              -> trace_way ()
 *              -> restructure_kv_mat
 *          -> trace_multilinestring ()
 *              -> trace_way ()
 *              -> restructure_kv_mat
 *          -> get_value_vec ()
 *          -> convert_poly_linestring_to_Rcpp ()
 *          -> [... most check and clean functions ...]
 *      }
 *      -> get_osm_ways ()
 *      {
 *          -> trace_way_nmat ()
 *          -> get_value_mat_way ()
 *          -> restructure_kv_mat
 *      }
 *      -> get_osm_nodes ()
 *          -> restructure_kv_mat
 *  }
 */

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

    public:

        double xmin = DOUBLE_MAX, xmax = -DOUBLE_MAX,
              ymin = DOUBLE_MAX, ymax = -DOUBLE_MAX;

        XmlData (const std::string& str)
        {
            // APS empty m_nodes/m_ways/m_relations constructed here, no need to explicitly clear
            XmlDocPtr p = parseXML (str);
            traverseWays (p->first_node ());
            make_key_val_indices ();
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
        double x_min() { return xmin;  }
        double x_max() { return xmax;  }
        double y_min() { return ymin;  }
        double y_max() { return ymax;  }

    private:

        void traverseWays (XmlNodePtr pt);
        void traverseRelation (XmlNodePtr pt, RawRelation& rrel);
        void traverseWay (XmlNodePtr pt, RawWay& rway);
        void traverseNode (XmlNodePtr pt, RawNode& rnode);
        void make_key_val_indices ();

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
                // metadata:
                node._version = rnode._version;
                node._changeset = rnode._changeset;
                node._timestamp = rnode._timestamp;
                node._uid = rnode._uid;
                node._user = rnode._user;

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
                    m_unique.k_way.insert (rway.key [i]);
                }
                // metadata:
                way._version = rway._version;
                way._changeset = rway._changeset;
                way._timestamp = rway._timestamp;
                way._uid = rway._uid;
                way._user = rway._user;
                // center:
                way._lat = rway._lat;
                way._lon = rway._lon;

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
                    m_unique.k_rel.insert (rrel.key [i]);
                    if (rrel.key [i] == "type")
                        relation.rel_type = rrel.value [i];
                }
                for (size_t i=0; i<rrel.ways.size (); i++)
                    relation.ways.push_back (std::make_pair (rrel.ways [i],
                                rrel.role_way [i]));
                for (size_t i=0; i<rrel.nodes.size (); i++)
                    relation.nodes.push_back (std::make_pair (rrel.nodes [i],
                                rrel.role_node [i]));
                // metadata:
                relation._version = rrel._version;
                relation._changeset = rrel._changeset;
                relation._timestamp = rrel._timestamp;
                relation._uid = rrel._uid;
                relation._user = rrel._user;
                // center:
                relation._lat = rrel._lat;
                relation._lon = rrel._lon;

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
        } else if (!strcmp (it->name(), "version"))
            rrel._version = it->value();
        else if (!strcmp (it->name(), "timestamp"))
            rrel._timestamp = it->value();
        else if (!strcmp (it->name(), "changeset"))
            rrel._changeset = it->value();
        else if (!strcmp (it->name(), "uid"))
            rrel._uid = it->value();
        else if (!strcmp (it->name(), "user"))
            rrel._user = it->value();
        else if (!strcmp (it->name(), "lat"))
            rrel._lat = std::stod(it->value());
        else if (!strcmp (it->name(), "lon"))
            rrel._lon = std::stod(it->value());
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
        else if (!strcmp (it->name(), "version"))
            rway._version = it->value();
        else if (!strcmp (it->name(), "timestamp"))
            rway._timestamp = it->value();
        else if (!strcmp (it->name(), "changeset"))
            rway._changeset = it->value();
        else if (!strcmp (it->name(), "uid"))
            rway._uid = it->value();
        else if (!strcmp (it->name(), "user"))
            rway._user = it->value();
        else if (!strcmp (it->name(), "lat"))
            rway._lat = std::stod(it->value());
        else if (!strcmp (it->name(), "lon"))
            rway._lon = std::stod(it->value());
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
            rnode.lat = std::stod(it->value());
        else if (!strcmp (it->name(), "lon"))
            rnode.lon = std::stod(it->value());
        else if (!strcmp (it->name(), "k"))
            rnode.key.push_back (it->value ());
        else if (!strcmp (it->name(), "v"))
            rnode.value.push_back (it->value ());
        else if (!strcmp (it->name(), "version")) // metadata
            rnode._version = it->value ();
        else if (!strcmp (it->name(), "timestamp")) // metadata
            rnode._timestamp = it->value ();
        else if (!strcmp (it->name(), "changeset")) // metadata
            rnode._changeset = it->value ();
        else if (!strcmp (it->name(), "uid")) // metadata
            rnode._uid = it->value ();
        else if (!strcmp (it->name(), "user")) // metadata
            rnode._user = it->value ();
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseNode (it, rnode);
    }
} // end function XmlData::traverseNode

inline void XmlData::make_key_val_indices ()
{
    // These are std::maps which enable keys to be mapped directly onto their
    // column number in the key-val matrices
    unsigned int i = 0;
    for (auto m: m_unique.k_point)
        m_unique.k_point_index.insert (std::make_pair (m, i++));

    i = 0;
    for (auto m: m_unique.k_way)
        m_unique.k_way_index.insert (std::make_pair (m, i++));

    i = 0;
    for (auto m: m_unique.k_rel)
        m_unique.k_rel_index.insert (std::make_pair (m, i++));
}

/*---------------------------- fn headers -----------------------------*/

namespace osm_sf {

Rcpp::List get_osm_relations (const Relations &rels,
        const std::map <osmid_t, Node> &nodes,
        const std::map <osmid_t, OneWay> &ways, const UniqueVals &unique_vals,
        const Rcpp::NumericVector &bbox, const Rcpp::List &crs);
void get_osm_ways (Rcpp::List &wayList, Rcpp::DataFrame &kv_df,
        Rcpp::DataFrame &meta_df,
        const std::set <osmid_t> &way_ids, const Ways &ways, const Nodes &nodes,
        const UniqueVals &unique_vals, const std::string &geom_type,
        const Rcpp::NumericVector &bbox, const Rcpp::List &crs);
void get_osm_nodes (Rcpp::List &ptList, Rcpp::DataFrame &kv_df,
        Rcpp::DataFrame &meta_df,
        const Nodes &nodes, const UniqueVals &unique_vals,
        const Rcpp::NumericVector &bbox, const Rcpp::List &crs);

} // end namespace osm_sf

Rcpp::List rcpp_osmdata_sf (const std::string& st);

namespace osm_sp {

void get_osm_nodes (Rcpp::S4 &sp_points, const Nodes &nodes,
        const UniqueVals &unique_vals);
void get_osm_ways (Rcpp::S4 &sp_ways,
        const std::set <osmid_t> &way_ids, const Ways &ways, const Nodes &nodes,
        const UniqueVals &unique_vals, const std::string &geom_type);
void get_osm_relations (Rcpp::S4 &multilines, Rcpp::S4 &multipolygons,
        const Relations &rels, const std::map <osmid_t, Node> &nodes,
        const std::map <osmid_t, OneWay> &ways, const UniqueVals &unique_vals);

} // end namespace osm_sp

Rcpp::List rcpp_osmdata_sp (const std::string& st);

namespace osm_sc {

void get_osm_relations (Rcpp::DataFrame &rel_df, Rcpp::DataFrame &kv_df,
        const Relations &rels);
void get_osm_ways (Rcpp::DataFrame &edge,
        Rcpp::DataFrame &object_link_edge, Rcpp::DataFrame &kv_df,
        const Ways &ways);
void get_osm_nodes (Rcpp::DataFrame &node_df, Rcpp::DataFrame &kv_df,
        const Nodes &nodes);

} // end namespace osm_sc

Rcpp::List rcpp_osmdata_sc (const std::string& st);

namespace osm_df {

Rcpp::List get_osm_relations (const Relations &rels,
        const UniqueVals &unique_vals);
Rcpp::List get_osm_ways (const std::set <osmid_t> &way_ids,
        const Ways &ways, const UniqueVals &unique_vals);
Rcpp::List get_osm_nodes (const Nodes &nodes,
        const UniqueVals &unique_vals);

} // end namespace osm_df

Rcpp::List rcpp_osmdata_df (const std::string& st);
