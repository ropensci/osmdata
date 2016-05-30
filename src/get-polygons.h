#include <string>
#include <fstream> // ifstream
#include <iostream>
#include <unordered_set>
#include <boost/property_tree/xml_parser.hpp>
#include <boost/property_tree/ptree.hpp>
#include <boost/unordered_map.hpp>

// get-polygons is most adapted directly from get-ways
// TODO: Implement Rcpp error control for asserts

typedef std::pair <float, float> ffPair; // lat-lon

typedef boost::unordered_map <long long, ffPair> umapPair;
typedef boost::unordered_map <long long, ffPair>::iterator umapPair_Itr;

// See http://theboostcpplibraries.com/boost.unordered
/*
std::size_t hash_value(const ffPair &f)
{
    std::size_t seed = 0;
    boost::hash_combine(seed, f.first);
    boost::hash_combine(seed, f.second);
    return seed;
}
*/

struct Node
{
    long long id;
    float lat, lon;
};

struct RawPoly
{
    long long id;
    std::vector <std::string> key, value;
    std::vector <long long> nodes;
};

struct Poly
{
    long long id;
    std::string type, name; 
    std::vector <std::pair <std::string, std::string> > key_val;
    std::vector <long long> nodes;
};

typedef std::vector <Poly> Polys;
typedef std::vector <Poly>::iterator Polys_Itr;
typedef std::vector <Node> Nodes;


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                          CLASS::XMLPOLYS                           **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

class XmlPolys
{
    private:
        std::string _tempstr;
    protected:
    public:
        std::string tempstr;
        Nodes nodelist;
        Polys polys;
        umapPair nodes;
        // "nodelist" contains all nodes to be returned as a
        // SpatialPointsDataFrame, while "nodes" is the unordered set used to
        // quickly extract lon-lats from nodal IDs.

    XmlPolys (std::string str)
        : _tempstr (str)
    {
        polys.resize (0);
        nodelist.resize (0);
        nodes.clear ();

        parseXMLPolys (_tempstr);
    }
    ~XmlPolys ()
    {
        polys.resize (0);
        nodelist.resize (0);
        nodes.clear ();
    }

    void parseXMLPolys ( std::string & is );
    void traversePolys (const boost::property_tree::ptree& pt);
    RawPoly traversePoly (const boost::property_tree::ptree& pt, RawPoly rpoly);
    Node traverseNode (const boost::property_tree::ptree& pt, Node node);
}; // end Class::XmlPolys


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                      FUNCTION::PARSEXMLPOLYS                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

void XmlPolys::parseXMLPolys ( std::string & is )
{
    // populate tree structure pt
    using boost::property_tree::ptree;
    ptree pt;
    std::stringstream istream (is, std::stringstream::in);
    read_xml (istream, pt);

    traversePolys (pt);
}


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSEPOLYS                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

void XmlPolys::traversePolys (const boost::property_tree::ptree& pt)
{
    RawPoly rpoly;
    Poly poly;
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
        else if (it->first == "way")
        {
            rpoly.key.resize (0);
            rpoly.value.resize (0);
            rpoly.nodes.resize (0);

            rpoly = traversePoly(it->second, rpoly);
            assert (rpoly.key.size () == rpoly.value.size ());

            // This is much easier as explicit loop than with an iterator
            poly.id = rpoly.id;
            poly.name = poly.type = "";
            poly.key_val.resize (0);
            poly.nodes.resize (0);
            for (int i=0; i<rpoly.key.size (); i++)
                if (rpoly.key [i] == "name")
                    poly.name = rpoly.value [i];
                else
                    poly.key_val.push_back (std::make_pair (rpoly.key [i], rpoly.value [i]));

            // This is the only place at which get-polys really differs from
            // get-ways, in that rpoly is copied to poly only if the nodes form
            // a cycle
            long long junk = *rpoly.nodes.begin ();
            if (rpoly.nodes.size () > 0 && 
                    (*rpoly.nodes.begin () == *rpoly.nodes.end ()))
            {
                for (std::vector <long long>::iterator it = rpoly.nodes.begin ();
                        it != rpoly.nodes.end (); it++)
                    poly.nodes.push_back (*it);
                polys.push_back (poly);
            }
        } else
            traversePolys (it->second);
    }
    rpoly.key.resize (0);
    rpoly.value.resize (0);
    rpoly.nodes.resize (0);
    poly.nodes.resize (0);
    poly.key_val.resize (0);
} // end function XmlPolys::traversePolys

/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEPOLY                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

RawPoly XmlPolys::traversePoly(const boost::property_tree::ptree& pt, RawPoly rpoly)
{
    for (boost::property_tree::ptree::const_iterator it = pt.begin ();
            it != pt.end (); ++it)
    {
        if (it->first == "k")
            rpoly.key.push_back (it->second.get_value <std::string> ());
        else if (it->first == "v")
            rpoly.value.push_back (it->second.get_value <std::string> ());
        else if (it->first == "id")
            rpoly.id = it->second.get_value <long long> ();
        else if (it->first == "ref")
            rpoly.nodes.push_back (it->second.get_value <long long> ());
        rpoly = traversePoly (it->second, rpoly);
    }

    return rpoly;
} // end function XmlPolys::traversePoly


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

Node XmlPolys::traverseNode (const boost::property_tree::ptree& pt, Node node)
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
        node = traverseNode (it->second, node);
    }

    return node;
} // end function XmlPolys::traverseNode
