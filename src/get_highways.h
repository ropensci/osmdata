#include <string>
#include <fstream> // ifstream
#include <iostream>
#include <boost/property_tree/xml_parser.hpp>
#include <boost/property_tree/ptree.hpp>
#include <boost/unordered_map.hpp>

typedef std::pair <float, float> ffPair; // lat-lon

typedef boost::unordered_map <long long, ffPair> umapPair;
typedef boost::unordered_map <long long, ffPair>::iterator umapPair_Itr;

// See http://theboostcpplibraries.com/boost.unordered
std::size_t hash_value(const ffPair &f)
{
    std::size_t seed = 0;
    boost::hash_combine(seed, f.first);
    boost::hash_combine(seed, f.second);
    return seed;
}

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
    std::vector <std::string> key, value;
    std::vector <long long> nodes;
};

struct Way
{
    bool oneway;
    long long id;
    std::string type, name; // type is highway type (value for highway key)
    std::vector <std::pair <std::string, std::string> > key_val;
    std::vector <long long> nodes;
};

typedef std::vector <Way> Ways;
typedef std::vector <Way>::iterator Ways_Itr;


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                             CLASS::XML                             **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

class Xml 
{
    private:
        std::string _tempstr;
    protected:
    public:
        std::string tempstr;
        Ways ways;
        umapPair nodes;

    Xml (std::string str)
        : _tempstr (str)
    {
        ways.resize (0);
        nodes.clear ();

        parseXML (_tempstr);
    }
    ~Xml ()
    {
        ways.resize (0);
        nodes.clear ();
    }

    void parseXML ( std::string & is );
    void traverseXML (const boost::property_tree::ptree& pt);
    RawWay traverseWay (const boost::property_tree::ptree& pt, RawWay rway);
    Node traverseNode (const boost::property_tree::ptree& pt, Node node);
}; // end Class::Xml


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                         FUNCTION::PARSEXML                         **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

void Xml::parseXML ( std::string & is )
{
    // populate tree structure pt
    using boost::property_tree::ptree;
    ptree pt;
    std::stringstream istream (is, std::stringstream::in);
    read_xml (istream, pt);

    traverseXML (pt);
}


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEXML                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

void Xml::traverseXML (const boost::property_tree::ptree& pt)
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
            node = traverseNode (it->second, node);
            nodes [node.id] = std::make_pair (node.lon, node.lat);
        }
        if (it->first == "way")
        {
            rway.key.resize (0);
            rway.value.resize (0);
            rway.nodes.resize (0);

            rway = traverseWay (it->second, rway);
            assert (rway.key.size () == rway.value.size ());

            // This is much easier as explicit loop than with an iterator
            way.id = rway.id;
            way.name = way.type = "";
            way.key_val.resize (0);
            way.oneway = false;
            // TODO: oneway also exists is pairs:
            // k='oneway' v='yes'
            // k='oneway:bicycle' v='no'
            for (int i=0; i<rway.key.size (); i++)
                if (rway.key [i] == "name")
                    way.name = rway.value [i];
                else if (rway.key [i] == "highway")
                    way.type = rway.value [i];
                else if (rway.key [i] == "oneway" && rway.value [i] == "yes")
                    way.oneway = true;
                else
                    way.key_val.push_back (std::make_pair (rway.key [i], rway.value [i]));

            // Then copy nodes from rway to way. 
            way.nodes.resize (0);
            for (std::vector <long long>::iterator it = rway.nodes.begin ();
                    it != rway.nodes.end (); it++)
                way.nodes.push_back (*it);
            ways.push_back (way);
        } else
            traverseXML (it->second);
    }
    rway.key.resize (0);
    rway.value.resize (0);
    rway.nodes.resize (0);
} // end function Xml::traverseXML

/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAY                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

RawWay Xml::traverseWay (const boost::property_tree::ptree& pt, RawWay rway)
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
        rway = traverseWay (it->second, rway);
    }

    return rway;
} // end function Xml::traverseWay


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

Node Xml::traverseNode (const boost::property_tree::ptree& pt, Node node)
{
    // Only coordinates of nodes are read, because only those are stored in the
    // unordered map. More node info is unlikely to be necessary ... ?
    for (boost::property_tree::ptree::const_iterator it = pt.begin ();
            it != pt.end (); ++it)
    {
        if (it->first == "id")
            node.id = it->second.get_value <long long> ();
        else if (it->first == "lat")
            node.lat = it->second.get_value <float> ();
        else if (it->first == "lon")
            node.lon = it->second.get_value <float> ();
        // No other key-value pairs currently extracted for nodes
        node = traverseNode (it->second, node);
    }

    return node;
} // end function Xml::traverseNode
