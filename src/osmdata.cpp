/***************************************************************************
 *  Project:    osmdata
 *  File:       osmdata.cpp
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
 *  osm-router.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Author:     Mark Padgham / Andrew Smith
 *  E-Mail:     mark.padgham@email.com / andrew@casacazaz.net
 *
 *  Description:    Extract OSM data from an object of class XmlData and return
 *                  it in Rcpp::List format.
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#include "osmdata.h"
#include "get-bbox.h"

#include <Rcpp.h>

#include <algorithm> // for min_element/max_element

// Note: roxygen attempts to import doxygen-style comments, even without
// [[Rcpp::Export]]

/* trace_relation
 *
 * Traces a single relation 
 *
 * @param itr_rel iterator to XmlData::Relations structure
 * @param &ways pointer to Ways structure
 * @param &nodes pointer to Nodes structure
 * @param &lon_vec pointer to 2D array of longitudes
 * @param &lat_vec pointer to 2D array of latitutdes
 * @param &rowname_vec pointer to 2D array of rownames for each node.
 * @param &id_vec pointer to 2D array of OSM IDs for each way in relation
 */
void trace_relation (Relations::const_iterator itr_rel, const Ways &ways,
        const Nodes &nodes, float_arr2 &lon_vec, float_arr2 &lat_vec,
        string_arr2 &rowname_vec, osmt_arr2 &id_vec)
{
    bool closed;
    int this_way;
    osmid_t node0, first_node, last_node;
    std::string this_role;
    std::vector <float> lons, lats;
    std::vector <std::string> rownames;
    std::vector <osmid_t> ids;

    std::vector <std::pair <osmid_t, std::string> > relation_ways;
    for (auto itw = itr_rel->ways.begin (); itw != itr_rel->ways.end (); ++itw)
        relation_ways.push_back (std::make_pair (itw->first, itw->second));

    // Then trace through all those ways and store associated data
    while (relation_ways.size () > 0)
    {
        auto rwi = relation_ways.front ();
        relation_ways.erase (relation_ways.begin() + 0);
        this_role = rwi.second;
        auto wayi = ways.find (rwi.first);
        if (wayi == ways.end ())
            throw std::runtime_error ("way can not be found");

        // Get first way of relation, and starting node
        node0 = wayi->second.nodes.front ();
        last_node = trace_way (ways, nodes, node0,
                wayi->first, ids, lons, lats, rownames);
        closed = false;
        if (last_node == node0)
            closed = true;
        while (!closed)
        {
            first_node = last_node;
            for (auto rwi = relation_ways.begin ();
                    rwi != relation_ways.end (); ++rwi)
            {
                if (rwi->second == this_role)
                {
                    auto wayi = ways.find (rwi->first);
                    if (wayi == ways.end ())
                        throw std::runtime_error ("way can not be found");
                    last_node = trace_way (ways, nodes, first_node,
                            wayi->first, ids, lons, lats, rownames);
                    if (last_node >= 0)
                    {
                        first_node = last_node;
                        this_way = std::distance (relation_ways.begin (),
                                rwi);
                        break;
                    }
                }
            } // end for rwi over relation_ways
            relation_ways.erase (relation_ways.begin () + this_way);
            if (last_node == node0 || relation_ways.size () == 0)
                closed = true;
        } // end while !closed
        if (last_node == node0)
        {
            lon_vec.push_back (lons);
            lat_vec.push_back (lats);
            rowname_vec.push_back (rownames);
            id_vec.push_back (ids);
        } else
        {
            throw std::runtime_error ("last node != node0");
        }
        lats.clear (); // These can't be reserved here
        lons.clear ();
        rownames.clear ();
        ids.clear ();
    } // end while relation_ways.size == 0 - finished tracing relation
}

/* trace_way
 * 
 * Traces a single way and adds (lon,lat,rownames) to corresponding vectors
 * 
 * @param &ways pointer to Ways structure
 * @param &nodes pointer to Nodes structure
 * @param first_node Last node of previous way to find in current
 * @param &wayi_id pointer to ID of current way
 * @param &ids pointer to vector of osm IDs for ways within a single
 * multipolygon relation
 * @param &lons pointer to vector of longitudes
 * @param &lats pointer to vector of latitutdes
 * @param &rownames pointer to vector of rownames for each node.
 * 
 * @return ID of final node in way, or a negative number if first_node does not
 * exist within wayi_id
 */
osmid_t trace_way (const Ways &ways, const Nodes &nodes, 
        osmid_t first_node, const osmid_t &wayi_id, std::vector <osmid_t> &ids,
        std::vector <float> &lons, std::vector <float> &lats,
        std::vector <std::string> &rownames)
{
    osmid_t last_node = -1;
    auto wayi = ways.find (wayi_id);
    std::vector <osmid_t>::const_iterator it_node_begin, it_node_end;

    // Alternative to the following is to pass iterators as .begin() or
    // .rbegin() to a std::for_each, but const Ways and Nodes cannot then
    // (easily) be passed to lambdas. TODO: Find a way
    if (wayi->second.nodes.front () == first_node)
    {
        ids.push_back (wayi->first);
        for (auto ni = wayi->second.nodes.begin ();
                ni != wayi->second.nodes.end (); ++ni)
        {
            if (nodes.find (*ni) == nodes.end ())
                throw std::runtime_error ("node can not be found");
            lons.push_back (nodes.find (*ni)->second.lon);
            lats.push_back (nodes.find (*ni)->second.lat);
            rownames.push_back (std::to_string (*ni));
        }
        last_node = wayi->second.nodes.back ();
    } else if (wayi->second.nodes.back () == first_node)
    {
        ids.push_back (wayi->first);
        for (auto ni = wayi->second.nodes.rbegin ();
                ni != wayi->second.nodes.rend (); ++ni)
        {
            if (nodes.find (*ni) == nodes.end ())
                throw std::runtime_error ("node can not be found");
            lons.push_back (nodes.find (*ni)->second.lon);
            lats.push_back (nodes.find (*ni)->second.lat);
            rownames.push_back (std::to_string (*ni));
        }
        last_node = wayi->second.nodes.front ();
    }

    return last_node;
}

/* check_geom_arrs
 * 
 * Sanity check to ensure all 3D geometry arrays have same sizes
 */
void check_geom_arrs (float_arr3 &lon_arr, float_arr3 &lat_arr,
        string_arr3 &rowname_arr, osmt_arr3 id_arr)
{
    if (lon_arr.size () != lat_arr.size () ||
            lon_arr.size () != rowname_arr.size ())
        throw std::runtime_error ("lons, lats, and rownames differ in size");
    for (int i=0; i<lon_arr.size (); i++)
    {
        if (lon_arr [i].size () != lat_arr [i].size () ||
                lon_arr [i].size () != rowname_arr [i].size ())
            throw std::runtime_error ("lons, lats, and rownames differ in size");
        for (int j=0; j<lon_arr [i].size (); j++)
            if (lon_arr [i][j].size () != lat_arr [i][j].size () ||
                    lon_arr [i][j].size () != rowname_arr [i][j].size ())
                throw std::runtime_error ("lons, lats, and rownames differ in size");
    }
    if (lon_arr.size () != id_arr.size ())
        throw std::runtime_error ("ids and geometries differ in size");
    // NOTE: Other dimensions of id_vec differ, because they hold IDs of all
    // component ways, whereas lon_arr etc only hold (single) concatenated
    // coordinates.
}

/* check_geom_vecs
 * 
 * Clean all 2D geometry arrays 
 */
void clean_geom_vecs (float_arr2 &lon_vec, float_arr2 &lat_vec,
        string_arr2 &rowname_vec, osmt_arr2 id_vec)
{
    for (int i=0; i<lon_vec.size (); i++)
    {
        lon_vec [i].clear ();
        lat_vec [i].clear ();
        rowname_vec [i].clear ();
        id_vec [i].clear ();
    }
    lon_vec.clear ();
    lat_vec.clear ();
    rowname_vec.clear ();
    id_vec.clear ();
}

/* clean_geom_arrs
 * 
 * Clean all 3D geometry arrays 
 */
void clean_geom_arrs (float_arr3 &lon_arr, float_arr3 &lat_arr,
        string_arr3 &rowname_arr, osmt_arr3 id_arr)
{
    for (int i=0; i<lon_arr.size (); i++)
    {
        for (int j=0; j<lon_arr [i].size (); j++)
        {
            lon_arr [i] [j].clear ();
            lat_arr [i] [j].clear ();
            rowname_arr [i] [j].clear ();
            id_arr [i] [j].clear ();
        }
        lon_arr [i].clear ();
        lat_arr [i].clear ();
        rowname_arr [i].clear ();
        id_arr [i].clear ();
    }
    lon_arr.clear ();
    lat_arr.clear ();
    rowname_arr.clear ();
    id_arr.clear ();
}


//' rcpp_osmdata
//'
//' Extracts all polygons from an overpass API query
//'
//' @param st Text contents of an overpass API query
//' @return Rcpp::List objects of OSM data
// [[Rcpp::export]]
Rcpp::List rcpp_osmdata (const std::string& st)
{
#ifdef DUMP_INPUT
    {
        std::ofstream dump ("./osmdata-sp.xml");
        if (dump.is_open())
        {
            dump.write (st.c_str(), st.size());
        }
    }
#endif

    XmlData xml (st);

    const std::map <osmid_t, Node>& nodes = xml.nodes ();
    const std::map <osmid_t, OneWay>& ways = xml.ways ();
    const std::vector <Relation>& rels = xml.relations ();
    const UniqueVals unique_vals = xml.unique_vals ();

    int count = 0;
    std::vector <float> lons, lats;
    std::unordered_set <std::string> idset; // see TODO below
    std::vector <std::string> colnames, rownames, polynames;
    Rcpp::List dimnames (0);
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));

    idset.clear ();

    colnames.push_back ("lon");
    colnames.push_back ("lat");

    // non_poly_ways are returned as line objects
    std::set <osmid_t> poly_ways, non_poly_ways;

    Rcpp::List crs = Rcpp::List::create (NA_INTEGER, 
            Rcpp::CharacterVector::create (NA_STRING));
    crs (0) = 4326;
    crs (1) = p4s;
    //Rcpp::List crs = Rcpp::List::create ((int) 4326, p4s);
    crs.attr ("class") = "crs";
    crs.attr ("names") = Rcpp::CharacterVector::create ("epsg", "proj4string");

    /*
     * Polygons are extracted from the XmlData class in three setps:
     *  1. Get the names of all polygons that are part of multipolygon relations
     *  2. Get the names of any remaining ways that are polygonal (start == end)
     *  3. From the resultant list, extract the actual polygonal ways
     *
     * NOTE: OSM polygons are stored as ways, and thus all objects in the class
     * xmlPolys are rightly referred to as ways. Here within this Rcpp function,
     * these are referred to as Polygons, but the iteration is over the actual
     * polygonal ways.
     */

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                           OSM RELATIONS                            **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    /* Trace all multipolygon relations. These are the only OSM types where
     * sizes are not known before, so lat-lons and node names are stored in
     * dynamic vectors. These are 3D monsters: #1 for relation, #2 for polygon
     * in relation, and #3 for data. There are also associated 2D vector<vector>
     * objects for IDs and roles. */
    float_arr2 lat_vec, lon_vec;
    float_arr3 lat_arr, lon_arr;
    string_arr2 rowname_vec;
    string_arr3 rowname_arr;
    std::vector <osmid_t> rel_id; 
    std::vector <std::vector <osmid_t> > id_vec; 
    std::vector <std::vector <std::vector <osmid_t> > > id_arr;
    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
    {
        if (itr->ispoly) // itr->second can only be "outer" or "inner"
        {
            trace_relation (itr, ways, nodes, lon_vec, lat_vec,
                    rowname_vec, id_vec);
            // Store all ways in that relation and their associated roles
            rel_id.push_back (itr->id);
            lon_arr.push_back (lon_vec);
            lat_arr.push_back (lat_vec);
            rowname_arr.push_back (rowname_vec);
            id_arr.push_back (id_vec);
            clean_geom_vecs (lon_vec, lat_vec, rowname_vec, id_vec);
        } else // store as multilinestring
        {
        }
    }

    check_geom_arrs (lon_arr, lat_arr, rowname_arr, id_arr);
    // Then store the lon-lat and rowname vector<vector> objects as Rcpp::List

    count = 0;
    Rcpp::Rcout << "(lon,lat,rowname).size = (" << lon_arr.size () << ", " <<
        lat_arr.size () << ", " << rowname_arr.size () << "); id_arr = " << 
        id_arr.size () << std::endl;
    for (int i=0; i<lon_arr.size (); i++)
    {
        Rcpp::Rcout << "(lon,lat,rowname)[" << i << "].size = " <<
            lat_arr [i].size () << ", " << lon_arr [i].size () << ", " <<
            rowname_arr [i].size () << "; id_arr = " <<
            id_arr [i].size () << std::endl;
        for (int j=0; j<lon_arr[i].size (); j++)
            Rcpp::Rcout << "(lon,lat,rowname)[" << i << "," << j << "].size = " <<
                lat_arr [i][j].size () << ", " << lon_arr [i][j].size () << ", " <<
                rowname_arr [i][j].size () << "; id_arr = " <<
                id_arr [i][j].size () << std::endl;
        Rcpp::Rcout << "----------" << std::endl;
    }
    // Then actual storage
    Rcpp::List polygonList (lon_arr.size ()), idList (lon_arr.size ());
    polynames.reserve (lon_arr.size ());
    std::vector <osmid_t> id_vec_fl;
    for (int i=0; i<lon_arr.size (); i++) // over all relations
    {
        Rcpp::List polystList_i (lon_arr [i].size ()), 
            idList_i (lon_arr [i].size ());
        for (int j=0; j<lon_arr [i].size (); j++) // over all ways
        {
            int n = lon_arr [i][j].size ();
            nmat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));
            std::copy (lon_arr [i][j].begin (), lon_arr [i][j].end (),
                    nmat.begin ());
            std::copy (lon_arr [i][j].begin (), lon_arr [i][j].end (),
                    nmat.begin () + n);
            dimnames.push_back (rowname_arr [i][j]);
            dimnames.push_back (colnames);
            nmat.attr ("dimnames") = dimnames;
            dimnames.erase (0, dimnames.size ());
            polystList_i [j] = nmat;
            id_vec_fl.clear ();
            id_vec_fl.reserve (id_arr [i][j].size ());
            std::copy (id_arr [i][j].begin (), id_arr [i][j].end (),
                    id_vec_fl.begin ());
            idList_i [j] = id_vec_fl;
        }
        polygonList [i] = polystList_i;
        polynames.push_back (std::to_string (rel_id [i]));
        idList [i] = idList_i;
        idList_i = polystList_i = R_NilValue; // Probably not necessary?
    }
    polygonList.attr ("names") = polynames;
    polynames.clear ();
    idList.attr ("names") = polynames; // needs to be combined in df at end

    // ****** clean up arrays *****
    clean_geom_arrs (lon_arr, lat_arr, rowname_arr, id_arr);
    rel_id.clear ();


    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                           PRE-PROCESSING                           **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    // Step#1: insert all rels into poly_ways
    for (auto itr = rels.begin (); itr != rels.end (); ++itr)
    {
        for (auto itw = (*itr).ways.begin (); itw != (*itr).ways.end (); ++itw)
        {
            if (ways.find (itw->first) == ways.end ())
                throw std::runtime_error ("way can not be found");
            poly_ways.insert (itw->first);
        }
    }

    // Step#2: identify and store poly and non_poly ways
    for (auto itw = ways.begin (); itw != ways.end (); ++itw)
    {
        if ((*itw).second.nodes.front () == (*itw).second.nodes.back ())
        {
            if (poly_ways.find ((*itw).first) == poly_ways.end ())
                poly_ways.insert ((*itw).first);
        } else if (non_poly_ways.find ((*itw).first) == non_poly_ways.end ())
            non_poly_ways.insert ((*itw).first);
    }

    // Step#2b - Erase any ways that contain no data (should not happen).
    for (auto itp = poly_ways.begin (); itp != poly_ways.end (); )
    {
        auto itw = ways.find (*itp);
        if (itw->second.nodes.size () == 0)
            itp = poly_ways.erase (itp);
        else
            ++itp;
    }
    for (auto itnp = non_poly_ways.begin (); itnp != non_poly_ways.end (); )
    {
        auto itw = ways.find (*itnp);
        if (itw->second.nodes.size () == 0)
            itnp = non_poly_ways.erase (itnp);
        else
            ++itnp;
    }

    Rcpp::NumericVector bbox = rcpp_get_bbox_sf (xml.x_min (), xml.x_max (), 
                                              xml.y_min (), xml.y_max ());

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                         STEP#3A: POLYGONS                          **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    std::set <std::string> varnames;
    std::vector <std::string> varnames_vec;
    Rcpp::List polyList (poly_ways.size ());
    polynames.reserve (poly_ways.size ());
    count = 0;
    for (auto pi = poly_ways.begin (); pi != poly_ways.end (); ++pi)
    {
        auto pj = ways.find (*pi);
        polynames.push_back (std::to_string (pj->first));
        // Collect all unique keys
        std::for_each (pj->second.key_val.begin (),
                pj->second.key_val.end (),
                [&](const std::pair <std::string, std::string>& p)
                {
                    varnames.insert (p.first);
                });

        // Then iterate over nodes of that way and store all lat-lons
        size_t n = pj->second.nodes.size ();
        lons.clear ();
        lats.clear ();
        rownames.clear ();
        lons.reserve (n);
        lats.reserve (n);
        rownames.reserve (n);
        for (auto nj = pj->second.nodes.begin ();
                nj != pj->second.nodes.end (); ++nj)
        {
            if (nodes.find (*nj) == nodes.end ())
                throw std::runtime_error ("node can not be found");
            lons.push_back (nodes.find (*nj)->second.lon);
            lats.push_back (nodes.find (*nj)->second.lat);
            rownames.push_back (std::to_string (*nj));
        }

        nmat = Rcpp::NumericMatrix (Rcpp::Dimension (lons.size (), 2));
        std::copy (lons.begin (), lons.end (), nmat.begin ());
        std::copy (lats.begin (), lats.end (), nmat.begin () + lons.size ());

        // This only works with push_back, not with direct re-allocation
        dimnames.push_back (rownames);
        dimnames.push_back (colnames);
        nmat.attr ("dimnames") = dimnames;
        dimnames.erase (0, dimnames.size());

        polyList [count++] = nmat;
    } // end for it over poly_ways
    polyList.attr ("names") = polynames;

    // Store all key-val pairs in one massive DF
    Rcpp::Rcout << "varnames, uv.k_poly = [" << varnames.size () << ", " <<
        unique_vals.k_poly.size () << "]" << std::endl;
    int nrow = poly_ways.size (), ncol = varnames.size ();
    Rcpp::CharacterVector poly_kv_vec (nrow * ncol, Rcpp::CharacterVector::get_na ());
    for (auto pi = poly_ways.begin (); pi != poly_ways.end (); ++pi)
    {
        int rowi = std::distance (poly_ways.begin (), pi);
        auto pj = ways.find (*pi);

        for (auto kv_iter = pj->second.key_val.begin ();
                kv_iter != pj->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto ni = varnames.find (key); // key must exist in varnames!
            int coli = std::distance (varnames.begin (), ni);
            poly_kv_vec (coli * nrow + rowi) = (*kv_iter).second;
        }
    }

    Rcpp::CharacterMatrix poly_kv_mat (nrow, ncol, poly_kv_vec.begin());
    Rcpp::DataFrame poly_kv_df = poly_kv_mat;
    poly_kv_df.attr ("names") = varnames;

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                           STEP#3B: LINES                           **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    Rcpp::List lineList (non_poly_ways.size ());
    std::vector <std::string> linenames;
    linenames.reserve (non_poly_ways.size());

    idset.clear ();
    dimnames.erase (0, dimnames.size());

    // Store all key-val pairs in one massive CharacterMatrix
    nrow = non_poly_ways.size (); 
    ncol = unique_vals.k_line.size ();
    Rcpp::CharacterMatrix kv_mat_lines (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat_lines.begin (), kv_mat_lines.end (), NA_STRING);
    count = 0;
    for (auto wi = non_poly_ways.begin (); wi != non_poly_ways.end (); ++wi)
    {
        auto wj = ways.find (*wi);
        linenames.push_back (std::to_string (wj->first));
        // Then iterate over nodes of that way and store all lat-lons
        size_t n = wj->second.nodes.size ();
        rownames.clear ();
        rownames.reserve (n);
        Rcpp::NumericMatrix lineMat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));
        int tempi = 0;
        for (auto nj = wj->second.nodes.begin ();
                nj != wj->second.nodes.end (); ++nj)
        {
            if (nodes.find (*nj) == nodes.end ())
                throw std::runtime_error ("node can not be found");
            rownames.push_back (std::to_string (*nj));
            lineMat (tempi, 0) = nodes.find (*nj)->second.lon;
            lineMat (tempi++, 1) = nodes.find (*nj)->second.lat;
        }

        // This only works with push_back, not with direct re-allocation
        dimnames.push_back (rownames);
        dimnames.push_back (colnames);
        lineMat.attr ("dimnames") = dimnames;
        lineMat.attr ("class") = Rcpp::CharacterVector::create ("XY", "LINESTRING", "sfg");
        dimnames.erase (0, dimnames.size());

        lineList (count) = lineMat;

        for (auto kv_iter = wj->second.key_val.begin ();
                kv_iter != wj->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto ni = unique_vals.k_line.find (key); // key must exist!
            int coli = std::distance (unique_vals.k_line.begin (), ni);
            kv_mat_lines (count, coli) = (*kv_iter).second;
        }
        count++;
    } // end for wi over non_poly_ways

    lineList.attr ("names") = linenames;
    lineList.attr ("n_empty") = 0;
    lineList.attr ("class") = Rcpp::CharacterVector::create ("sfc_LINESTRING", "sfc");
    lineList.attr ("precision") = 0.0;
    lineList.attr ("bbox") = bbox;
    lineList.attr ("crs") = crs;
    kv_mat_lines.attr ("dimnames") = Rcpp::List::create (linenames, unique_vals.k_line);

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                          STEP#3C: POINTS                           **
     **                                                                    **
     ************************************************************************
     ************************************************************************/

    nrow = nodes.size ();
    ncol = unique_vals.k_point.size ();
    Rcpp::CharacterMatrix kv_mat_points (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat_points.begin (), kv_mat_points.end (), NA_STRING);

    Rcpp::List pointList (nodes.size ());
    std::vector <std::string> ptnames;
    ptnames.reserve (nodes.size ());
    count = 0;
    for (auto ni = nodes.begin (); ni != nodes.end (); ++ni)
    {
        Rcpp::NumericVector ptxy = Rcpp::NumericVector::create (NA_REAL, NA_REAL);
        ptxy.attr ("class") = Rcpp::CharacterVector::create ("XY", "POINT", "sfg");
        ptxy (0) = ni->second.lon;
        ptxy (1) = ni->second.lat;
        pointList (count) = ptxy;
        ptnames.push_back (std::to_string (ni->first));
        for (auto kv_iter = ni->second.key_val.begin ();
                kv_iter != ni->second.key_val.end (); ++kv_iter)
        {
            const std::string& key = (*kv_iter).first;
            auto it = unique_vals.k_point.find (key);
            int ni = std::distance (unique_vals.k_point.begin (), it);
            kv_mat_points (count, ni) = (*kv_iter).second;
        }
        count++;
    }
    kv_mat_points.attr ("dimnames") = Rcpp::List::create (ptnames, unique_vals.k_point);

    pointList.attr ("names") = ptnames;
    ptnames.clear ();
    pointList.attr ("n_empty") = 0;
    pointList.attr ("class") = Rcpp::CharacterVector::create ("sfc_POINT", "sfc");
    pointList.attr ("precision") = 0.0;
    pointList.attr ("bbox") = bbox;
    pointList.attr ("crs") = crs;

    /************************************************************************
     ************************************************************************
     **                                                                    **
     **                      STEP#4: COLLATE ALL DATA                      **
     **                                                                    **
     ************************************************************************
     ************************************************************************/


    Rcpp::List ret (6);
    //ret [0] = bbox;
    ret [0] = pointList;
    ret [1] = kv_mat_points;
    ret [2] = lineList;
    ret [3] = kv_mat_lines;
    ret [4] = polyList;
    ret [5] = poly_kv_df;

    //std::vector <std::string> retnames {"bbox", "points", 
    //    "lines", "lines_kv", "polygons", "polygons_kv"};
    std::vector <std::string> retnames {"points", "points_kv",
        "lines", "lines_kv", "polygons", "polygons_kv"};
    ret.attr ("names") = retnames;
    
    return ret;
}
