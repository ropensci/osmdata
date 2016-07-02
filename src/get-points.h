#include "header.h"


struct Node
{
    long long id;
    std::string key, value;
    std::vector <std::pair <std::string, std::string> > key_val;
    float lat, lon;
};

typedef std::vector <Node> Nodes;
typedef std::vector <Node>::iterator Nodes_Itr;


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
        std::string _tempstr;
    protected:
    public:
        std::string tempstr;
        Nodes nodes;

    XmlNodes (std::string str)
        : _tempstr (str)
    {
        nodes.resize (0);

        parseXMLNodes (_tempstr);
    }
    ~XmlNodes ()
    {
        nodes.resize (0);
    }

    void parseXMLNodes ( std::string & is );
    void traverseNodes (const boost::property_tree::ptree& pt);
    Node traverseNode (const boost::property_tree::ptree& pt, Node node);
}; // end Class::XmlNodes


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::PARSEXMLNODES                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

void XmlNodes::parseXMLNodes ( std::string & is )
{
    // populate tree structure pt
    using boost::property_tree::ptree;
    ptree pt;
    std::stringstream istream (is, std::stringstream::in);
    read_xml (istream, pt);

    traverseNodes (pt);
}


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODES                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

void XmlNodes::traverseNodes (const boost::property_tree::ptree& pt)
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
            node.key_val.resize (0);
            node = traverseNode (it->second, node);
            if (nodeIDs.find (node.id) == nodeIDs.end ())
            {
                nodes.push_back (node);
                auto p = nodeIDs.insert (node.id);
            }
        } else
            traverseNodes (it->second);
    }
    nodeIDs.clear ();
    node.key_val.resize (0);
} // end function XmlNodes::traverseNodes


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

Node XmlNodes::traverseNode (const boost::property_tree::ptree& pt, Node node)
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
            node.key_val.push_back (std::make_pair (node.key, node.value));
            node.key = "";
            node.value = "";
        }

        node = traverseNode (it->second, node);
    }

    return node;
} // end function XmlNodes::traverseNode
