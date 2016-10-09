#pragma once

#include <boost/property_tree/ptree.hpp>

namespace common {

boost::property_tree::ptree parseXML(const std::string& xmlString);

}
