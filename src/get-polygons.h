#include "common.h"

#include <map>
#include <unordered_map>

// TODO: Implement Rcpp error control for asserts


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
    std::map <std::string, std::string> key_val;
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
    std::map<std::string, std::string> key_val;
    std::vector <std::pair <long long, bool> > ways; // bool flags inner/outer
};

typedef std::vector <Relation> Relations;
typedef std::vector <Poly> Polys;
typedef std::vector <Poly>::const_iterator Polys_Itr;
//typedef std::map <long long, Poly> Polys;
//typedef std::map <long long, Poly>::const_iterator Polys_Itr;

// MP: the long long is Node.id, and thus repetitive, but traverseNode has to
// stored the ID in the Node struct first, before this can be used to make the
// map of Nodes. TODO: Is there a better way?
typedef std::map <long long, Node> Nodes;

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
    Nodes m_nodes;
    Polys m_polys;
    Relations m_relations;

public:
    // "nodelist" contains all nodes to be returned as a
    // SpatialPointsDataFrame, while "nodes" is the unordered set used to
    // quickly extract lon-lats from nodal IDs.

    XmlPolys (const std::string& str)
    {
        m_nodes.clear ();
        m_polys.clear ();
        traversePolys (common::parseXML (str));
    }
    ~XmlPolys ()
    {
        m_nodes.clear ();
        m_polys.clear ();
    }

    const Nodes& nodes() const { return m_nodes; }
    const Polys& polys() const { return m_polys; }
    const Relations& relations() const { return m_relations; }

private:
    void traversePolys (const boost::property_tree::ptree& pt);
    void traverseRelation (const boost::property_tree::ptree& pt, 
            RawRelation& rrel);
    void traversePoly (const boost::property_tree::ptree& pt, RawPoly& rpoly);
    void traverseNode (const boost::property_tree::ptree& pt, Node& node);
}; // end Class::XmlPolys


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSEPOLYS                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traversePolys (const boost::property_tree::ptree& pt)
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
            traverseNode (it->second, node);
            m_nodes.insert (std::make_pair (node.id, node));
        }
        else if (it->first == "way")
        {
            rpoly.key.clear();
            rpoly.value.clear();
            rpoly.nodes.clear();

            traversePoly(it->second, rpoly);
            assert (rpoly.key.size () == rpoly.value.size ());

            // This is much easier as explicit loop than with an iterator
            poly.id = rpoly.id;
            poly.name = poly.type = "";
            poly.key_val.clear();
            poly.nodes.clear();
            for (size_t i=0; i<rpoly.key.size (); i++)
                if (rpoly.key [i] == "name")
                    poly.name = rpoly.value [i];
                else
                    poly.key_val.insert (std::make_pair
                            (rpoly.key [i], rpoly.value [i]));

            // This is the only place at which get-polys really differs from
            // get-ways, in that rpoly is copied to poly only if the nodes form
            // a cycle
            if (rpoly.nodes.size () > 0 &&
                    (rpoly.nodes.front () == rpoly.nodes.back ()))
            {
                poly.nodes.swap (rpoly.nodes);
                m_polys.push_back (poly);
            }
        } else if (it->first == "relation")
        {
            rrel.key.clear();
            rrel.value.clear();
            rrel.ways.clear();
            rrel.outer.clear();

            traverseRelation (it->second, rrel);
            assert (rrel.key.size () == rrel.value.size ());
            assert (rrel.ways.size () == rrel.outer.size ());

            relation.id = rrel.id;
            relation.key_val.clear();
            relation.ways.clear();
            for (size_t i=0; i<rrel.key.size (); i++)
                relation.key_val.insert (std::make_pair (rrel.key [i],
                            rrel.value [i]));
            for (size_t i=0; i<rrel.ways.size (); i++)
                relation.ways.push_back (std::make_pair (rrel.ways [i],
                            rrel.outer [i]));
            m_relations.push_back (relation);
        } else
            traversePolys (it->second);
    }

} // end function XmlPolys::traversePolys


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                     FUNCTION::TRAVERSERELATION                     **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traverseRelation (const boost::property_tree::ptree& pt,
        RawRelation& rrel)
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
        traverseRelation (it->second, rrel);
    }
} // end function XmlPolys::traverseRelation



/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEPOLY                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traversePoly(const boost::property_tree::ptree& pt,
        RawPoly& rpoly)
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
        traversePoly (it->second, rpoly);
    }
} // end function XmlPolys::traversePoly


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traverseNode (const boost::property_tree::ptree& pt, 
        Node& node)
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
} // end function XmlPolys::traverseNode
