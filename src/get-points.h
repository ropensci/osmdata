#include "common.h"

#include <map>
#include <unordered_set>


struct Node
{
    long long id;
    std::string key, value;
    std::map<std::string, std::string> key_val;
    float lat, lon;
};

typedef std::vector <Node> Nodes;
typedef std::vector <Node>::const_iterator Nodes_Itr;


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                           CLASS::XMLNODES                          **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

class XmlNodes
{
private:

    Nodes m_nodes;

public:
    XmlNodes (const std::string& str)
    {
      traverseNodes(common::parseXML(str));
    }
    ~XmlNodes ()
    {
    }

    const Nodes& nodes() const { return m_nodes; }

private:
    void traverseNodes (const boost::property_tree::ptree& pt);
    void traverseNode (const boost::property_tree::ptree& pt, Node& node);
}; // end Class::XmlNodes


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODES                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlNodes::traverseNodes (const boost::property_tree::ptree& pt)
{
    std::unordered_set <long long> nodeIDs;
    Node node;
    // NOTE: Node is (lon, lat) = (x, y)!

    for (boost::property_tree::ptree::const_iterator it = pt.begin ();
            it != pt.end (); ++it)
    {
        if (it->first == "node")
        {
            node.key = "";
            node.value = "";
            node.key_val.clear();
            traverseNode (it->second, node);
            if (nodeIDs.find (node.id) == nodeIDs.end ())
            {
                m_nodes.push_back (node);
                nodeIDs.insert (node.id);
            }
        } else
            traverseNodes (it->second);
    }
} // end function XmlNodes::traverseNodes


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlNodes::traverseNode (const boost::property_tree::ptree& pt, Node& node)
{
    for (boost::property_tree::ptree::const_iterator it = pt.begin ();
            it != pt.end (); ++it)
    {
        if (it->first == "id")
            node.id = it->second.get_value <long long> ();
        else if (it->first == "lat")
            node.lat = it->second.get_value <float> ();
        else if (it->first == "lon")
            node.lon = it->second.get_value <float> ();
        else if (it->first == "k")
            node.key = it->second.get_value <std::string> ();
        else if (it->first == "v")
        {
            // Note that values sometimes exist without keys, but the following
            // still inserts the pair because values **always** come after keys.
            node.value = it->second.get_value <std::string> ();
            node.key_val.insert (std::make_pair (node.key, node.value));
            node.key = "";
            node.value = "";
        }

        traverseNode (it->second, node);
    }

} // end function XmlNodes::traverseNode
