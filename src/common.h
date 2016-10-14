#pragma once

// APS TODO segregate this file to make it clear it's 3rdparty code and should not be modified
#include "rapidxml.h"

#include <limits>
#include <memory>
#include <string>

#include <vector>
#include <map>
#include <unordered_set>
#include <unordered_map> // TODO: Delete are fixing get-lines
#include <cstring>

// APS uncomment to save xml input string to a file
//#define DUMP_INPUT
#ifdef DUMP_INPUT
#include <fstream>
#endif


// make clear the id type
typedef long long osmid_t;

const float FLOAT_MAX = std::numeric_limits<float>::max ();
const float FLOAT_MIN = std::numeric_limits<float>::min ();

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
typedef std::map <long long, OneWay> Ways;

// MP: the long long is Node.id, and thus repetitive, but traverseNode has to
// stored the ID in the Node struct first, before this can be used to make the
// map of Nodes. TODO: Is there a better way?
typedef std::map <long long, Node> Nodes;

