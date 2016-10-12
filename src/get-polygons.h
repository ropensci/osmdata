#include "common.h"

#include <map>
#include <vector>
#include <unordered_map>

#include <cstring>

// get-polygons is most adapted directly from get-ways
// TODO: Implement Rcpp error control for asserts

typedef std::pair <float, float> ffPair; // lat-lon

typedef std::unordered_map <osmid_t, ffPair> UMapPair;
typedef std::unordered_map <osmid_t, ffPair>::const_iterator UMapPair_Itr;


struct Node
{
    osmid_t id;
    float lat, lon;
};

struct RawPoly
{
    osmid_t id;
    std::vector <std::string> key, value;
    std::vector <osmid_t> nodes;
};

struct Poly
{
    osmid_t id;
    std::string type, name;
    std::map<std::string, std::string> key_val;
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
typedef std::vector <Poly> Polys;
typedef std::vector <Poly>::const_iterator Polys_Itr;
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
    Nodes m_nodelist;
    Polys m_polys;
    Relations m_relations;
    UMapPair m_nodes;
    // "nodelist" contains all nodes to be returned as a
    // SpatialPointsDataFrame, while "nodes" is the unordered set used to
    // quickly extract lon-lats from nodal IDs.

public:
    XmlPolys (const std::string& str)
    {
      XmlDocPtr p = parseXML(str);
      traversePolys(p->first_node());
    }

    ~XmlPolys ()
    {
    }

    const Nodes& nodelist() const { return m_nodelist; }
    const Polys& polys() const { return m_polys; }
    const Relations& relations() const { return m_relations; }
    const UMapPair& nodes() const { return m_nodes; }

private:

    void traversePolys (XmlNodePtr pt);
    void traverseRelation (XmlNodePtr pt, RawRelation& rrel);
    void traversePoly (XmlNodePtr pt, RawPoly& rpoly);
    void traverseNode (XmlNodePtr pt, Node& node);

}; // end Class::XmlPolys


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSEPOLYS                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traversePolys (XmlNodePtr pt)
{
  RawRelation rrel;
  RawPoly rpoly;
  Relation relation;
  Poly poly;
  Node node;
  // NOTE: Node is (lon, lat) = (x, y)!

  for (XmlNodePtr it = pt->first_node (); it != nullptr; it = it->next_sibling())
  {
    if (!strcmp(it->name(), "node"))
    {
      traverseNode (it, node);
      m_nodes [node.id] = std::make_pair (node.lon, node.lat);
    }
    else if (!strcmp(it->name(), "way"))
    {
      rpoly.key.clear();
      rpoly.value.clear();
      rpoly.nodes.clear();

      traversePoly(it, rpoly);
      assert (rpoly.key.size () == rpoly.value.size ());

      // This is much easier as explicit loop than with an iterator
      poly.id = rpoly.id;
      poly.name = poly.type = "";
      poly.key_val.clear();
      poly.nodes.clear();
      for (size_t i=0; i<rpoly.key.size (); i++)
      {
        if (rpoly.key [i] == "name")
          poly.name = rpoly.value [i];
        else
          poly.key_val.insert (std::make_pair
                                 (rpoly.key [i], rpoly.value [i]));
      }
      // This is the only place at which get-polys really differs from
      // get-ways, in that rpoly is copied to poly only if the nodes form
      // a cycle
      if (rpoly.nodes.size () > 0 &&
          (rpoly.nodes.front () == rpoly.nodes.back ()))
      {
        poly.nodes.swap(rpoly.nodes);
        m_polys.push_back (poly);
      }
    }
    else if (!strcmp(it->name(), "relation"))
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
      traversePolys (it);
    }
  }

} // end function XmlWays::traverseWays


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                     FUNCTION::TRAVERSERELATION                     **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traverseRelation (XmlNodePtr pt, RawRelation& rrel)
{
  for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; it = it->next_attribute())
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
 **                        FUNCTION::TRAVERSEPOLY                      **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traversePoly (XmlNodePtr pt, RawPoly& rpoly)
{
  for (XmlAttrPtr it = pt->first_attribute (); it != nullptr; it = it->next_attribute())
  {
    if (!strcmp(it->name(), "k"))
      rpoly.key.push_back (it->value());
    else if (!strcmp(it->name(), "v"))
      rpoly.value.push_back (it->value());
    else if (!strcmp(it->name(), "id"))
      rpoly.id = std::stoll(it->value());
    else if (!strcmp(it->name(), "ref"))
      rpoly.nodes.push_back (std::stoll(it->value()));
  }
  // allows for >1 child nodes
  for (XmlNodePtr it = pt->first_node(); it != nullptr; it = it->next_sibling())
  {
    traversePoly (it, rpoly);
  }

} // end function XmlNodes::traverseNode


/************************************************************************
 ************************************************************************
 **                                                                    **
 **                       FUNCTION::TRAVERSENODE                       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

inline void XmlPolys::traverseNode (XmlNodePtr pt, Node& node)
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

