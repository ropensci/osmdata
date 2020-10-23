/***************************************************************************
 *  Project:    osmdata
 *  File:       trace-osm.cpp
 *  Language:   C++
 *
 *  osmdata is free software: you can redistribute it and/or modify it under
 *  the terms of the GNU General Public License as published by the Free
 *  Software Foundation, either version 3 of the License, or (at your option)
 *  any later version.
 *
 *  osmdata is distributed in the hope that it will be useful, but WITHOUT ANY
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 *  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 *  details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  osm-router.  If not, see <https://www.gnu.org/licenses/>.
 *
 *  Author:     Mark Padgham 
 *  E-Mail:     mark.padgham@email.com 
 *
 *  Description:    Functions to trace OSM ways and store in C++ dynamic arrays
 *                  (no RCpp here).
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdata)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#include "trace-osm.h"

/* Traces a single relation of any type (SC only)
 *
 * @param itr_rel iterator to XmlData::Relations structure
 */
void trace_relation (Relations::const_iterator &itr_rel,
        osm_str_vec &relation_ways, 
        std::vector <std::pair <std::string, std::string> > & relation_kv)
{
    relation_ways.reserve (itr_rel->ways.size ());
    for (auto itw = itr_rel->ways.begin (); itw != itr_rel->ways.end (); ++itw)
            relation_ways.push_back (std::make_pair (itw->first, itw->second));

    relation_kv.reserve (itr_rel->key_val.size ());
    for (auto itk = itr_rel->key_val.begin ();
            itk != itr_rel->key_val.end (); ++itk)
        relation_kv.push_back (std::make_pair (itk->first, itk->second));
}


/* Traces a single multipolygon relation 
 * 
 * @param itr_rel iterator to XmlData::Relations structure
 * @param &ways pointer to Ways structure
 * @param &nodes pointer to Nodes structure
 * @param &lon_vec pointer to 2D array of longitudes
 * @param &lat_vec pointer to 2D array of latitudes
 * @param &rowname_vec pointer to 2D array of rownames for each node.
 * @param &id_vec pointer to 2D array of OSM IDs for each way in relation
 */
void trace_multipolygon (Relations::const_iterator &itr_rel, const Ways &ways,
        const Nodes &nodes, double_arr2 &lon_vec, double_arr2 &lat_vec,
        string_arr2 &rowname_vec, std::vector <std::string> &ids)
{
    bool closed, ptr_check;
    osmid_t node0, first_node, last_node;
    std::string this_role;
    std::stringstream this_way;
    std::vector <double> lons, lats;
    std::vector <std::string> rownames, wayname_vec;

    osm_str_vec relation_ways;
    relation_ways.reserve (itr_rel->ways.size ());
    for (auto itw = itr_rel->ways.begin (); itw != itr_rel->ways.end (); ++itw)
        relation_ways.push_back (std::make_pair (itw->first, itw->second));
    it_osm_str_vec itr_rw;

    bool way_okay = true;
    // Then trace through all those relations and store associated data
    while (relation_ways.size () > 0)
    {
        auto rwi = relation_ways.begin ();
        if (rwi->second != "outer") // "outer" role first 
        {
            while (std::distance (rwi, relation_ways.end ()) > 1)
            {
                std::advance (rwi, 1);
                if (rwi->second == "outer")
                    break;
            }
            if (rwi->second != "outer") // just reset to first
                rwi = relation_ways.begin ();
        }
        this_role = rwi->second;
        auto wayi = ways.find (rwi->first);
        if (wayi == ways.end ())
            throw std::runtime_error ("way can not be found");
        this_way.str ("");
        this_way << std::to_string (rwi->first);
        relation_ways.erase (rwi);

        // Get first way of relation, and starting node
        node0 = wayi->second.nodes.front ();
        last_node = trace_way (ways, nodes, node0,
                wayi->first, lons, lats, rownames, false);
        closed = false;
        if (last_node == node0)
            closed = true;
        while (!closed)
        {
            first_node = last_node;
            ptr_check = false;
            for (auto itw = relation_ways.begin ();
                    itw != relation_ways.end (); ++itw)
            {
                if (itw->second == this_role)
                {
                    auto wayj = ways.find (itw->first);
                    if (wayj == ways.end ())
                        throw std::runtime_error ("way can not be found");
                    last_node = trace_way (ways, nodes, first_node,
                            wayj->first, lons, lats, rownames, true);
                    this_way << "-" << std::to_string (wayj->first);
                    if (last_node >= 0)
                    {
                        first_node = last_node;
                        itr_rw = itw;
                        ptr_check = true;
                        break;
                    }
                }
            } // end for itw over relation_ways
            if (ptr_check)
                relation_ways.erase (itr_rw);
            else
            {
                // not all OSM multipolygons join up
                way_okay = false;
                break;
                //throw std::runtime_error ("pointer not assigned");
            }
            if (last_node == node0 || relation_ways.size () == 0)
                closed = true;
        } // end while !closed
        if (way_okay && last_node == node0)
        {
            lon_vec.push_back (lons);
            lat_vec.push_back (lats);
            rowname_vec.push_back (rownames);
            wayname_vec.push_back (this_way.str ());
            ids.push_back (this_way.str ());
        } 
        lats.clear (); // These can't be reserved here
        lons.clear ();
        rownames.clear ();
    } // end while relation_ways.size == 0 - finished tracing relation
    wayname_vec.clear ();
}


/* Traces a single multilinestring relation 
 *
 *
 * GDAL does a simple dump of all ways as one multistring. osmdata creates one
 * multistring for each separate relation role, resulting in as many multistrings
 * as there are roles.
 *
 * @param itr_rel iterator to XmlData::Relations structure
 * @param role trace ways only matching this role in the relation
 * @param &ways pointer to Ways structure
 * @param &nodes pointer to Nodes structure
 * @param &lon_vec pointer to 2D array of longitudes
 * @param &lat_vec pointer to 2D array of latitudes
 * @param &rowname_vec pointer to 2D array of rownames for each node.
 * @param &id_vec pointer to 2D array of OSM IDs for each way in relation
 */
void trace_multilinestring (Relations::const_iterator &itr_rel, 
        const std::string role, const Ways &ways, const Nodes &nodes, 
        double_arr2 &lon_vec, double_arr2 &lat_vec, string_arr2 &rowname_vec,
        std::vector <osmid_t> &ids)
{
    std::vector <double> lons, lats;
    std::vector <std::string> rownames;

    osm_str_vec relation_ways;
    //relation_ways.reserve (itr_rel->ways.size ());
    for (auto itw = itr_rel->ways.begin (); itw != itr_rel->ways.end (); ++itw)
        if (itw->second == role)
            relation_ways.push_back (std::make_pair (itw->first, itw->second));

    // Then trace through all those relations and store associated data
    while (relation_ways.size () > 0)
    {
        auto rwi = relation_ways.begin ();
        ids.push_back (rwi->first);
        auto wayi = ways.find (rwi->first);
        //if (wayi == ways.end ())
        //    throw std::runtime_error ("way can not be found");
        // Non-overpass OSM data sets can have way IDs in old changelogs that no
        // longer exist; this clause ensures that they are simply skipped but
        // reading continues. Thanks @RobinLovelace
        if (wayi != ways.end ())
        {
            osmid_t first_node = wayi->second.nodes.front ();
            first_node = trace_way (ways, nodes, first_node, 
                    wayi->first, lons, lats, rownames, false);

            lon_vec.push_back (lons);
            lat_vec.push_back (lats);
            rowname_vec.push_back (rownames);

            lons.clear ();
            lats.clear ();
            rownames.clear ();
            relation_ways.erase (rwi);
        }
    } // end while relation_ways.size > 0
}


/* trace_way
 *
 * Traces a single way and adds (lon,lat,rownames) to corresponding vectors.
 * This is used only for tracing ways in OSM relations. Direct tracing of ways
 * stored as 'LINESTRING' or 'POLYGON' objects is done with 'trace_way_nmat ()',
 * which dumps the results directly to an 'Rcpp::NumericMatrix'.
 *
 * @param &ways pointer to Ways structure
 * @param &nodes pointer to Nodes structure
 * @param first_node Last node of previous way to find in current
 * @param &wayi_id pointer to ID of current way
 * @lons pointer to vector of longitudes
 * @lats pointer to vector of latitudes
 * @rownames pointer to vector of rownames for each node.
 *       
 * @returnn ID of final node in way, or a negative number if first_node does not
 *          within wayi_id
 */
osmid_t trace_way (const Ways &ways, const Nodes &nodes, osmid_t first_node,
        const osmid_t &wayi_id, std::vector <double> &lons, 
        std::vector <double> &lats, std::vector <std::string> &rownames,
        const bool append)
{
    osmid_t last_node = -1;
    auto wayi = ways.find (wayi_id);
    bool add_node = true;
    if (append)
        add_node = false;

    // Alternative to the following is to pass iterators as .begin() or
    // .rbegin() to a std::for_each, but const Ways and Nodes cannot then
    // (easily) be passed to lambdas. TODO: Find a way
    if (first_node < 0 || wayi->second.nodes.front () == first_node)
    {
        for (auto ni = wayi->second.nodes.begin ();
                ni != wayi->second.nodes.end (); ++ni)
        {
            if (nodes.find (*ni) == nodes.end ())
                throw std::runtime_error ("node can not be found");
            if (!add_node)
                add_node = true;
            else
            { 
                lons.push_back (nodes.find (*ni)->second.lon);
                lats.push_back (nodes.find (*ni)->second.lat);
                rownames.push_back (std::to_string (*ni));
            }
        }
        last_node = wayi->second.nodes.back ();
    } else if (wayi->second.nodes.back () == first_node)
    {
        for (auto ni = wayi->second.nodes.rbegin ();
                ni != wayi->second.nodes.rend (); ++ni)
        {
            if (nodes.find (*ni) == nodes.end ())
                throw std::runtime_error ("node can not be found");
            if (!add_node)
                add_node = true;
            else
            {
                lons.push_back (nodes.find (*ni)->second.lon);
                lats.push_back (nodes.find (*ni)->second.lat);
                rownames.push_back (std::to_string (*ni));
            }
        }
        last_node = wayi->second.nodes.front ();
    }

    return last_node;
}
