#pragma once

#include "common.h"

typedef std::pair <float, float> ffPair; // lat-lon

typedef std::unordered_map <osmid_t, ffPair> umapPair;
typedef std::unordered_map <osmid_t, ffPair>::const_iterator umapPair_Itr;


struct Node
{
    osmid_t id;
    float lat, lon;
};

/* Traversing the boost::property_tree means keys and values are read
 * sequentially and cannot be processed simultaneously. Each way is thus
 * initially read as a RawWay with separate vectors for keys and values. These
 * are subsequently converted in Way to a vector of <std::pair>. */
struct RawWay
{
    osmid_t id;
    // APS would (key,value) be better in a std::map?
    std::vector <std::string> key, value;
    std::vector <osmid_t> nodes;
};

struct Way
{
    bool oneway;
    osmid_t id;
    std::string type, name; 
    // APS would (key,value) be better in a std::map?
    std::map<std::string, std::string> key_val;
    std::vector <osmid_t> nodes;
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
            XmlDocPtr p = parseXML (str);
            traverseWays (p->first_node());
        }

        ~XmlWays ()
        {
        }

        // Const accessors for members
        const Nodes& nodelist() const { return m_nodelist; }
        const Ways& ways() const { return m_ways; }
        const umapPair& nodes() const { return m_nodes; }

    private:

        void traverseWays (XmlNodePtr pt);
        void traverseWay (XmlNodePtr pt, RawWay& way);
        void traverseNode (XmlNodePtr pt, Node& node);

}; // end Class::XmlWays



/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAYS                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlWays::traverseWays (XmlNodePtr pt)
{
    RawWay rway;
    Way way;
    Node node;
    // NOTE: Node is (lon, lat) = (x, y)!

    for (XmlNodePtr it = pt->first_node (); it != nullptr; 
            it = it->next_sibling())
    {
        if (!strcmp(it->name(), "node"))
        {
            // APS this call modifies node
            traverseNode (it, node);
            m_nodes [node.id] = std::make_pair (node.lon, node.lat);
        }
        else if (!strcmp(it->name(), "way"))
        {
            rway.key.clear();
            rway.value.clear();
            rway.nodes.clear();

            // APS this call modifies node
            traverseWay (it, rway);
            assert (rway.key.size () == rway.value.size ());

            // This is much easier as explicit loop than with an iterator
            way.id = rway.id;
            way.name = way.type = "";
            way.key_val.clear();
            //way.key_val.reserve(rway.key.size ());
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
                    way.key_val.insert (std::make_pair (rway.key [i],
                                rway.value [i]));
            }
            // Then copy nodes from rway to way.
            std::copy(rway.nodes.begin (), rway.nodes.end(),
                    std::back_inserter(way.nodes));
            m_ways.push_back (way);
        }
        else
        {
            traverseWays (it);
        }
    }

} // end function XmlWays::traverseWays


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                        FUNCTION::TRAVERSEWAY                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlWays::traverseWay (XmlNodePtr pt, RawWay& rway)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; it = 
            it->next_attribute())
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
} // end function XmlWays::traverseWay


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlWays::traverseNode (XmlNodePtr pt, Node& node)
{
    for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; it = it->next_attribute())
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


