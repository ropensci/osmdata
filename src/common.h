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

