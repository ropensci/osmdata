#pragma once

#include <boost/property_tree/xml_parser.hpp>
#include <boost/property_tree/ptree.hpp>

#include <vector>
#include <unordered_map>
#include <sstream>

typedef std::pair <float, float> ffPair; // lat-lon

typedef std::unordered_map <long long, ffPair> umapPair;
typedef std::unordered_map <long long, ffPair>::const_iterator umapPair_Itr;


struct Node
{
    long long id;
    float lat, lon;
};

/* Traversing the boost::property_tree means keys and values are read
 * sequentially and cannot be processed simultaneously. Each way is thus
 * initially read as a RawWay with separate vectors for keys and values. These
 * are subsequently converted in Way to a vector of <std::pair>. */
struct RawWay
{
    long long id;
    // APS would (key,value) be better in a std::map?
    std::vector <std::string> key, value;
    std::vector <long long> nodes;
};

struct Way
{
    bool oneway;
    long long id;
    std::string type, name; // type is highway type (value for highway key)
    // APS would (key,value) be better in a std::map?
    std::vector <std::pair <std::string, std::string> > key_val;
    std::vector <long long> nodes;
};

typedef std::vector <Way> Ways;
typedef std::vector <Way>::const_iterator Ways_Itr;
typedef std::vector <Node> Nodes;


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                           CLASS::XMLWAYS                           **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

class XmlWays
{
private:

    Nodes m_nodelist;
    Ways m_ways;
    umapPair m_nodes;
    // "nodelist" contains all nodes to be returned as a
    // SpatialPointsDataFrame, while "nodes" is the unordered set used to
    // quickly extract lon-lats from nodal IDs.

public:

    XmlWays (const std::string& str)
    {
        parseXMLWays (str);
    }

    ~XmlWays ()
    {
    }

    // Const accessors for members
    const Nodes& nodelist() const { return m_nodelist; }
    const Ways& ways() const { return m_ways; }
    const umapPair& nodes() const { return m_nodes; }

    void parseXMLWays (const std::string & is );
    void traverseWays (const boost::property_tree::ptree& pt);
    // APS Pass by reference and modify in-place to avoid copy
    void traverseWay (const boost::property_tree::ptree& pt, RawWay& rway);
    // APS Pass by reference and modify in-place to avoid copy
    void traverseNode (const boost::property_tree::ptree& pt, Node& node);
}; // end Class::XmlWays


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::PARSEXMLWAYS                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

// APS inline purely to avoid possible linker errors (if this header was included in multiple sources)
inline void XmlWays::parseXMLWays (const std::string & is )
{
    // populate tree structure pt
    using namespace boost::property_tree;
    ptree pt;
    std::istringstream istream (is);
    xml_parser::read_xml (istream, pt);

    traverseWays (pt);
}


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAYS                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlWays::traverseWays (const boost::property_tree::ptree& pt)
{
    RawWay rway;
    Way way;
    Node node;
    // NOTE: Node is (lon, lat) = (x, y)!

    for (boost::property_tree::ptree::const_iterator it = pt.begin ();
            it != pt.end (); ++it)
    {
        if (it->first == "node")
        {
            // APS this call modifies node
            traverseNode (it->second, node);
            m_nodes [node.id] = std::make_pair (node.lon, node.lat);
        }
        else if (it->first == "way")
        {
            rway.key.clear();
            rway.value.clear();
            rway.nodes.clear();

            // APS this call modifies node
            traverseWay (it->second, rway);
            assert (rway.key.size () == rway.value.size ());

            // This is much easier as explicit loop than with an iterator
            way.id = rway.id;
            way.name = way.type = "";
            way.key_val.clear();
            way.key_val.reserve(rway.key.size ());
            way.nodes.clear();
            way.nodes.reserve(rway.nodes.size());
            way.oneway = false;
            // TODO: oneway also exists in pairs:
            // k='oneway' v='yes'
            // k='oneway:bicycle' v='no'
            for (size_t i=0; i<rway.key.size (); i++)
            {
                if (rway.key [i] == "name")
                    way.name = rway.value [i];
                else if (rway.key [i] == "highway")
                    way.type = rway.value [i];
                else if (rway.key [i] == "oneway" && rway.value [i] == "yes")
                    way.oneway = true;
                else
                    way.key_val.push_back (std::make_pair (rway.key [i], rway.value [i]));
            }
            // Then copy nodes from rway to way.
            std::copy(rway.nodes.begin (), rway.nodes.end(), std::back_inserter(way.nodes));
            m_ways.push_back (way);
        } else
            traverseWays (it->second);
    }

} // end function XmlWays::traverseWays

/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAY                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlWays::traverseWay (const boost::property_tree::ptree& pt, RawWay& rway)
{
    for (boost::property_tree::ptree::const_iterator it = pt.begin ();
            it != pt.end (); ++it)
    {
        if (it->first == "k")
            rway.key.push_back (it->second.get_value <std::string> ());
        else if (it->first == "v")
            rway.value.push_back (it->second.get_value <std::string> ());
        else if (it->first == "id")
            rway.id = it->second.get_value <long long> ();
        else if (it->first == "ref")
            rway.nodes.push_back (it->second.get_value <long long> ());
        traverseWay (it->second, rway);
    }
} // end function XmlWays::traverseWay


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlWays::traverseNode (const boost::property_tree::ptree& pt, Node& node)
{
    // Only coordinates of nodes are read here; full data can be extracted with
    // get-nodes
    for (boost::property_tree::ptree::const_iterator it = pt.begin ();
            it != pt.end (); ++it)
    {
        if (it->first == "id")
            node.id = it->second.get_value <long long> ();
        else if (it->first == "lat")
            node.lat = it->second.get_value <float> ();
        else if (it->first == "lon")
            node.lon = it->second.get_value <float> ();
        traverseNode (it->second, node);
    }
} // end function XmlWays::traverseNode
