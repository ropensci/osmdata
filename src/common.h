#pragma once

#include <boost/property_tree/ptree.hpp>

const float FLOAT_MAX = std::numeric_limits<float>::max ();

namespace common {

boost::property_tree::ptree parseXML(const std::string& xmlString);

}
