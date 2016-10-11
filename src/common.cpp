
#include "common.h"
#include <boost/property_tree/xml_parser.hpp>

#include <sstream>

boost::property_tree::ptree common::parseXML(const std::string& xmlString)
{
  // populate tree structure pt
  boost::property_tree::ptree pt;
  std::istringstream istream (xmlString, std::stringstream::in);
  boost::property_tree::xml_parser::read_xml (istream, pt);
  // hopfully this copy is elided, might be worth checking
  return pt;
}


