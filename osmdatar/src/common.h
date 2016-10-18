/***************************************************************************
 *  Project:    osmdatar
 *  File:       common.h
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
 *  Description:    Common header file for get-points/lines/polygons
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
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
#include <unordered_set>
#include <cstring>

// APS uncomment to save xml input string to a file
//#define DUMP_INPUT
#ifdef DUMP_INPUT
#include <fstream>
#endif


// make clear the id type
typedef long long osmid_t;

const float FLOAT_MAX =  std::numeric_limits<float>::max ();

// Convenience typedefs for some rapidxml types
typedef std::unique_ptr<rapidxml::xml_document<>> XmlDocPtr;
typedef const rapidxml::xml_node<>* XmlNodePtr;
typedef const rapidxml::xml_attribute<>* XmlAttrPtr;

XmlDocPtr parseXML (const std::string& xmlString);

struct Node
{
    osmid_t id;
    std::string key, value;
    std::map <std::string, std::string> key_val;
    float lat, lon;
};

/* Traversing the XML tree means keys and values are read sequentially and
 * cannot be processed simultaneously. Each way is thus initially read as a
 * RawWay with separate vectors for keys and values. These are subsequently
 * converted in Way to a vector of <std::pair>. */
struct RawWay
{
    osmid_t id;
    // TODO: APS would (key,value) be better in a std::map?
    std::vector <std::string> key, value;
    std::vector <osmid_t> nodes;
};

struct OneWay
{
    bool oneway;
    osmid_t id;
    std::string type, name;
    std::map <std::string, std::string> key_val;
    std::vector <osmid_t> nodes;
};

struct RawRelation
{
    osmid_t id;
    // APS would (key,value) be better in a std::map?
    std::vector <std::string> key, value;
    std::vector <osmid_t> ways;
    std::vector <bool> outer;
};

struct Relation
{
    osmid_t id;
    std::map<std::string, std::string> key_val;
    std::vector <std::pair <osmid_t, bool> > ways; // bool flags inner/outer
};

typedef std::vector <Relation> Relations;
typedef std::map <osmid_t, OneWay> Ways;

// MP: osmid_t (long long) is Node.id, and thus repetitive, but traverseNode has to
// stored the ID in the Node struct first, before this can be used to make the
// map of Nodes. TODO: Is there a better way?
typedef std::map <osmid_t, Node> Nodes;

