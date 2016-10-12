#include "common.h"

#include <map>
#include <vector>
#include <unordered_set>

#include <cstring>


// APS TODO fix multiple definitions in different headers
struct Node
{
    osmid_t id;
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
        //traverseNodes(common::parseXMLold(str));
        XmlDocPtr p = parseXML(str);
        traverseNodes(p->first_node());
    }
    ~XmlNodes ()
    {
    }

    const Nodes& nodes() const { return m_nodes; }

private:
    void traverseNodes (XmlNodePtr pt);
    void traverseNode (XmlNodePtr pt, Node& node);
}; // end Class::XmlNodes


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODES                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlNodes::traverseNodes (XmlNodePtr pt)
{
  std::unordered_set <osmid_t> nodeIDs;
  Node node;
  // NOTE: Node is (lon, lat) = (x, y)!


  for (XmlNodePtr it = pt->first_node (); it != nullptr; it = it->next_sibling())
  {
    if (!strcmp(it->name(), "node"))
    {
      node.key = "";
      node.value = "";
      node.key_val.clear();
      traverseNode (it, node);
      if (nodeIDs.find (node.id) == nodeIDs.end ())
      {
        m_nodes.push_back (node);
        nodeIDs.insert (node.id);
      }
    }
    else
    {
      traverseNodes (it);
    }
  }
}


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlNodes::traverseNode (XmlNodePtr pt,
                                    Node& node)
{
  for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; it = it->next_attribute())
  {
    if (!strcmp(it->name(), "id"))
      node.id = std::stoll(it->value());
    else if (!strcmp(it->name(), "lat"))
      node.lat = std::stof(it->value());
    else if (!strcmp(it->name(), "lon"))
      node.lon = std::stof(it->value());
    else if (!strcmp(it->name(), "k"))
      node.key = it->value();
    else if (!strcmp(it->name(), "v"))
    {
      // Note that values sometimes exist without keys, but the following
      // still inserts the pair because values **always** come after keys.
      node.value = it->value();
      node.key_val.insert (std::make_pair (node.key, node.value));
      node.key = "";
      node.value = "";
    }

  }
  // allows for >1 child nodes
  for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
  {
    traverseNode (it, node);
  }

} // end function XmlNodes::traverseNode

