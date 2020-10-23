/***************************************************************************
 *  Project:    osmdata
 *  File:       common.h
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
 *  Author:     Mark Padgham / Andrew Smith
 *  E-Mail:     mark.padgham@email.com / andrew@casacazaz.net
 *
 *  Description:    Common header file for get-points/lines/polygons
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdata)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#pragma once

#include "rapidxml.h"

// APS not good pratice to have all the headers included here, adds to compile time
// better to #include as and where needed, ideally in source rather than headers,
// and use fwd declarations wherever possible

#include <limits>
#include <memory>
#include <string>

#include <vector>
#include <map>
#include <set>
#include <unordered_set>
#include <cstring>
#include <sstream>

// APS uncomment to save xml input string to a file
//#define DUMP_INPUT
#ifdef DUMP_INPUT
#include <fstream>
#endif


// make clear the id type
typedef long long osmid_t;

typedef std::vector <std::vector <float> > float_arr2;
typedef std::vector <std::vector <std::vector <float> > > float_arr3;
typedef std::vector <std::vector <double> > double_arr2;
typedef std::vector <std::vector <std::vector <double> > > double_arr3;
typedef std::vector <std::vector <std::string> > string_arr2;
typedef std::vector <std::vector <std::vector <std::string> > > string_arr3;
typedef std::vector <std::vector <osmid_t> > osmt_arr2;
typedef std::vector <std::pair <osmid_t, std::string> > osm_str_vec;
typedef std::vector <std::pair <osmid_t, std::string> >::iterator it_osm_str_vec;

constexpr float FLOAT_MAX =  std::numeric_limits<float>::max ();
constexpr double DOUBLE_MAX =  std::numeric_limits<double>::max ();

// Convenience typedefs for some rapidxml types
typedef std::unique_ptr<rapidxml::xml_document<> > XmlDocPtr;
typedef const rapidxml::xml_node<>* XmlNodePtr;
typedef const rapidxml::xml_attribute<>* XmlAttrPtr;

// ----- functions in common.cpp
XmlDocPtr parseXML (const std::string& xmlString);
// ----- end functions in common.cpp

struct UniqueVals
{
    // OSM IDs are sometimes duplicated, even though they ought not be. Unique
    // IDs are stored in the following sets, ensuring that only the first
    // instance of any given ID will be extracted. Using set.find in constructed
    // takes 45ms for trial code; time without these finds = 60ms - HUH?
    // NOTE: Previous code converted <osmid_t> IDs to std::string and added
    // decimal places to generate unique IDs. This could be re-instated?
    std::set <osmid_t> id_node, id_way, id_rel;
    // Unique keys are also stored to provide column names.  Although std::set
    // is slower than an unordered_set, it is useful to have keys alphabetically
    // ordered.
    std::set <std::string> k_point, k_way, k_rel;
    // A numeric index is also constructed to enable direct indexing into
    // key-val matrices. This is an unsigned int for indexing into Rcpp objects.
    std::map <std::string, unsigned int> k_point_index, k_way_index, k_rel_index;
};

struct RawNode
{
    osmid_t id;
    std::vector <std::string> key, value;
    double lat, lon;
};

struct Node
{
    osmid_t id;
    std::map <std::string, std::string> key_val;
    double lat, lon;
};

/* Traversing the XML tree means keys and values are read sequentially and
 * cannot be processed simultaneously. Each way is thus initially read as a
 * RawWay with separate vectors for keys and values. These are subsequently
 * converted in Way to a vector of <std::pair>. */
struct RawWay
{
    osmid_t id;
    std::vector <std::string> key, value;
    std::vector <osmid_t> nodes;
};

struct OneWay
{
    osmid_t id;
    std::map <std::string, std::string> key_val;
    std::vector <osmid_t> nodes;
};

struct RawRelation
{
    bool ispoly;
    osmid_t id;
    std::string member_type;
    // APS would (key,value) be better in a std::map?
    std::vector <std::string> key, value, role_node, role_way, role_relation;
    std::vector <osmid_t> nodes;
    std::vector <osmid_t> ways;
    std::vector <osmid_t> relations; // relations can contain relations
};

struct Relation
{
    bool ispoly;
    osmid_t id;
    std::string rel_type;
    std::map <std::string, std::string> key_val;
    // Relations may have nodes as members, but these are not used here.
    std::vector <std::pair <osmid_t, std::string> > nodes; // str = role
    std::vector <std::pair <osmid_t, std::string> > ways; // str = role
    std::vector <std::pair <osmid_t, std::string> > relations; // str = role
};

typedef std::vector <Relation> Relations;
typedef std::map <osmid_t, OneWay> Ways;

// MP: osmid_t (long long) is Node.id, and thus repetitive, but traverseNode has
// to store the ID in the Node struct first, before this can be used to make the
// map of Nodes. TODO: Is there a better way?
typedef std::map <osmid_t, Node> Nodes;
