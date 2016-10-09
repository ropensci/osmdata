#include "header.h"

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

struct RawRelation
{
    long long id;
    std::vector <std::string> key, value;
    std::vector <long long> ways;
    std::vector <bool> outer;
};

struct Relation
{
    long long id;
    std::vector <std::pair <std::string, std::string> > key_val;
    std::vector <std::pair <long long, bool> > ways; // bool flags inner/outer
};

typedef std::vector <Relation> Relations;
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
        Relations relations;
        umapPair nodes;
        // "nodelist" contains all nodes to be returned as a
        // SpatialPointsDataFrame, while "nodes" is the unordered set used to
        // quickly extract lon-lats from nodal IDs.

    XmlPolys (std::string str)
        : _tempstr (str)
    {
        relations.resize (0);
        polys.resize (0);
        nodelist.resize (0);
        nodes.clear ();

        parseXMLPolys (_tempstr);
    }
    ~XmlPolys ()
    {
        relations.resize (0);
        polys.resize (0);
        nodelist.resize (0);
        nodes.clear ();
    }

    void parseXMLPolys ( std::string & is );
    void traversePolys (const boost::property_tree::ptree& pt);
    RawRelation traverseRelation (const boost::property_tree::ptree& pt,
            RawRelation rrel);
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
    RawRelation rrel;
    RawPoly rpoly;
    Relation relation;
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
            for (size_t i=0; i<rpoly.key.size (); i++)
                if (rpoly.key [i] == "name")
                    poly.name = rpoly.value [i];
                else
                    poly.key_val.push_back (std::make_pair
                            (rpoly.key [i], rpoly.value [i]));

            // This is the only place at which get-polys really differs from
            // get-ways, in that rpoly is copied to poly only if the nodes form
            // a cycle
            if (rpoly.nodes.size () > 0 &&
                    (rpoly.nodes.front () == rpoly.nodes.back ()))
            {
                for (std::vector <long long>::iterator it = rpoly.nodes.begin ();
                        it != rpoly.nodes.end (); it++)
                    poly.nodes.push_back (*it);
                polys.push_back (poly);
            }
        } else if (it->first == "relation")
        {
            rrel.key.resize (0);
            rrel.value.resize (0);
            rrel.ways.resize (0);
            rrel.outer.resize (0);

            rrel = traverseRelation (it->second, rrel);
            assert (rrel.key.size () == rrel.value.size ());

            relation.id = rrel.id;
            relation.key_val.resize (0);
            relation.ways.resize (0);
            for (size_t i=0; i<rrel.key.size (); i++)
                relation.key_val.push_back (std::make_pair
                        (rrel.key [i], rrel.value [i]));
            relations.push_back (relation);
        } else
            traversePolys (it->second);
    }
    rpoly.key.resize (0);
    rpoly.value.resize (0);
    rpoly.nodes.resize (0);
    poly.nodes.resize (0);
    poly.key_val.resize (0);
    rrel.key.resize (0);
    rrel.value.resize (0);
    rrel.ways.resize (0);
    rrel.outer.resize (0);

} // end function XmlPolys::traversePolys


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                     FUNCTION::TRAVERSERELATION                     **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

RawRelation XmlPolys::traverseRelation (const boost::property_tree::ptree& pt,
        RawRelation rrel)
{
    std::string outer;

    for (boost::property_tree::ptree::const_iterator it = pt.begin ();
            it != pt.end (); ++it)
    {
        if (it->first == "k")
            rrel.key.push_back (it->second.get_value <std::string> ());
        else if (it->first == "v")
            rrel.value.push_back (it->second.get_value <std::string> ());
        else if (it->first == "id")
            rrel.id = it->second.get_value <long long> ();
        else if (it->first == "ref")
            rrel.ways.push_back (it->second.get_value <long long> ());
        else if (it->first == "role")
        {
            outer = it->second.get_value <std::string> ();
            if (outer == "outer")
                rrel.outer.push_back (true);
            else
                rrel.outer.push_back (false);
        }
        rrel = traverseRelation (it->second, rrel);
    }

    return rrel;
} // end function XmlPolys::traverseRelation



/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEPOLY                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

RawPoly XmlPolys::traversePoly(const boost::property_tree::ptree& pt,
        RawPoly rpoly)
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
