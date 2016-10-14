#include "common.h"

#include <map>
#include <vector>
#include <unordered_map>
#include <cstring>

// TODO: Implement Rcpp error control for asserts

// NOTE: OSM polygons are stored as ways, and thus all objects in the class
// xmlPolys are rightly referred to as ways. 

struct Node
{
    osmid_t id;
    float lat, lon;
};

struct RawWay
{
    osmid_t id;
    std::vector <std::string> key, value;
    std::vector <osmid_t> nodes;
};

struct OneWay
{
    osmid_t id;
    std::string type, name;
    std::map <std::string, std::string> key_val;
    std::vector <osmid_t> nodes;
};

struct RawRelation
{
    osmid_t id;
    std::vector <std::string> key, value;
    std::vector <osmid_t> ways;
    std::vector <bool> outer;
};

struct Relation
{
    osmid_t id;
    std::map<std::string, std::string> key_val;
    std::vector <std::pair <osmid_t, bool> > ways; // bool flags inner/outer
};

typedef std::vector <Relation> Relations;
typedef std::map <long long, OneWay> Ways;

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
        Ways m_ways;
        Relations m_relations;

    public:
        // "nodelist" contains all nodes to be returned as a
        // SpatialPointsDataFrame, while "nodes" is the unordered set used to
        // quickly extract lon-lats from nodal IDs.

        XmlPolys (const std::string& str)
        {
            m_nodes.clear ();
            m_ways.clear ();
            XmlDocPtr p = parseXML (str);
            traverseWays (p->first_node ());
        }

        ~XmlPolys ()
        {
            m_nodes.clear ();
            m_ways.clear ();
        }

        const Nodes& nodes() const { return m_nodes; }
        const Ways& ways() const { return m_ways; }
        const Relations& relations() const { return m_relations; }

    private:

        void traverseWays (XmlNodePtr pt);
        void traverseRelation (XmlNodePtr pt, RawRelation& rrel);
        void traverseWay (XmlNodePtr pt, RawWay& rway);
        void traverseNode (XmlNodePtr pt, Node& node);

}; // end Class::XmlPolys


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSEWAYS                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traverseWays (XmlNodePtr pt)
{
    RawRelation rrel;
    RawWay rway;
    Relation relation;
    OneWay way;
    Node node;

    for (XmlNodePtr it = pt->first_node (); it != nullptr; 
            it = it->next_sibling())
    {
        if (!strcmp (it->name(), "node"))
        {
            traverseNode (it, node);
            //m_nodes [node.id] = std::make_pair (node.lon, node.lat);
            m_nodes.insert (std::make_pair (node.id, node));
        }
        else if (!strcmp (it->name(), "way"))
        {
            rway.key.clear();
            rway.value.clear();
            rway.nodes.clear();

            traverseWay (it, rway);
            assert (rway.key.size () == rway.value.size ());

            // This is much easier as explicit loop than with an iterator
            way.id = rway.id;
            way.name = way.type = "";
            way.key_val.clear();
            way.nodes.clear();
            for (size_t i=0; i<rway.key.size (); i++)
            {
                if (rway.key [i] == "name")
                    way.name = rway.value [i];
                else
                    way.key_val.insert (std::make_pair
                            (rway.key [i], rway.value [i]));
            }
            // This is the only place at which get-polys really differs from
            // get-ways, in that rway is copied to way only if the nodes form
            // a cycle
            if (rway.nodes.size () > 0 &&
                    (rway.nodes.front () == rway.nodes.back ()))
            {
                way.nodes.swap (rway.nodes);
                m_ways.insert (std::make_pair (way.id, way));
            }
        }
        else if (!strcmp (it->name(), "relation"))
        {
            rrel.key.clear();
            rrel.value.clear();
            rrel.ways.clear();
            rrel.outer.clear();

            traverseRelation (it, rrel);
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
        }
        else
        {
            traverseWays (it);
        }
    }

} // end function XmlPolys::traverseWays


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                     FUNCTION::TRAVERSERELATION                     **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traverseRelation (XmlNodePtr pt, RawRelation& rrel)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; 
            it = it->next_attribute())
    {
        if (!strcmp(it->name(), "k"))
            rrel.key.push_back (it->value());
        else if (!strcmp(it->name(), "v"))
            rrel.value.push_back (it->value());
        else if (!strcmp(it->name(), "id"))
            rrel.id = std::stoll(it->value());
        else if (!strcmp(it->name(), "ref"))
            rrel.ways.push_back (std::stoll(it->value()));
        else if (!strcmp(it->name(), "role"))
        {
            if (!strcmp(it->value(), "outer"))
                rrel.outer.push_back (true);
            else
                rrel.outer.push_back (false);
        }
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseRelation (it, rrel);
    }
} // end function XmlPolys::traverseRelation


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAY                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traverseWay (XmlNodePtr pt, RawWay& rway)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; 
            it = it->next_attribute())
    {
        if (!strcmp(it->name(), "k"))
            rway.key.push_back (it->value());
        else if (!strcmp(it->name(), "v"))
            rway.value.push_back (it->value());
        else if (!strcmp(it->name(), "id"))
            rway.id = std::stoll(it->value());
        else if (!strcmp(it->name(), "ref"))
            rway.nodes.push_back (std::stoll(it->value()));
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseWay (it, rway);
    }

} // end function XmlNodes::traverseWay


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traverseNode (XmlNodePtr pt, Node& node)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; 
            it = it->next_attribute())
    {
        if (!strcmp(it->name(), "id"))
            node.id = std::stoll(it->value());
        else if (!strcmp(it->name(), "lat"))
            node.lat = std::stof(it->value());
        else if (!strcmp(it->name(), "lon"))
            node.lon = std::stof(it->value());
    }
    // allows for >1 child nodes
    for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
    {
        traverseNode (it, node);
    }

} // end function XmlNodes::traverseNode

