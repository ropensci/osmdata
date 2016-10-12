#pragma once

// APS TODO segregate this file to make it clear it's 3rdparty code and should not be modified
#include "rapidxml.h"

#include <limits>
#include <memory>
#include <string>

// make clear the id type
typedef long long osmid_t;

const float FLOAT_MAX = std::numeric_limits<float>::max ();
const float FLOAT_MIN = std::numeric_limits<float>::min ();

// Convenience typedefs for some rapidxml types
typedef std::unique_ptr<rapidxml::xml_document<>> XmlDocPtr;
typedef const rapidxml::xml_node<>* XmlNodePtr;
typedef const rapidxml::xml_attribute<>* XmlAttrPtr;

XmlDocPtr parseXML (const std::string& xmlString);

