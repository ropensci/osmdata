/***************************************************************************
 *  Project:    osmdata
 *  File:       convert_osm_rcpp.cpp
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
 *  Author:     Mark Padgham 
 *  E-Mail:     mark.padgham@email.com 
 *
 *  Description:    Functions to convert OSM data stored in C++ arrays to Rcpp
 *                  structures.
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#include "convert-osm-rcpp.h"


/************************************************************************
 ************************************************************************
 **                                                                    **
 **       FUNCTIONS TO CONVERT C++ OBJECTS TO Rcpp::List OBJECTS       **
 **                                                                    **
 ************************************************************************
 ************************************************************************/

/* Traces a single way and adds (lon,lat,rownames) to an Rcpp::NumericMatrix
 *
 * @param &ways pointer to Ways structure
 * @param &nodes pointer to Nodes structure
 * @param first_node Last node of previous way to find in current
 * @param &wayi_id pointer to ID of current way
 * @lons pointer to vector of longitudes
 * @lats pointer to vector of latitutdes
 * @rownames pointer to vector of rownames for each node.
 * @nmat Rcpp::NumericMatrix to store lons, lats, and rownames
 */
void trace_way_nmat (const Ways &ways, const Nodes &nodes, 
        const osmid_t &wayi_id, Rcpp::NumericMatrix &nmat)
{
    auto wayi = ways.find (wayi_id);
    std::vector <std::string> rownames;
    rownames.clear ();
    int n = wayi->second.nodes.size ();
    rownames.reserve (n);
    nmat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));

    int tempi = 0;
    for (auto ni = wayi->second.nodes.begin ();
            ni != wayi->second.nodes.end (); ++ni)
    {
        rownames.push_back (std::to_string (*ni));
        nmat (tempi, 0) = nodes.find (*ni)->second.lon;
        nmat (tempi++, 1) = nodes.find (*ni)->second.lat;
    }

    std::vector <std::string> colnames = {"lon", "lat"};
    Rcpp::List dimnames (0);
    dimnames.push_back (rownames);
    dimnames.push_back (colnames);
    nmat.attr ("dimnames") = dimnames;
    dimnames.erase (0, dimnames.size ());
}

/* get_value_mat_way
 *
 * Extract key-value pairs for a given way and fill Rcpp::CharacterMatrix
 *
 * @param wayi Constant iterator to one OSM way
 * @param Ways Pointer to the std::vector of all ways
 * @param unique_vals Pointer to the UniqueVals structure
 * @param value_arr Pointer to the Rcpp::CharacterMatrix of values to be filled
 *        by tracing the key-val pairs of the way 'wayi'
 * @param rowi Integer value for the key-val pairs for wayi
 */
// TODO: Is it faster to use a std::vector <std::string> instead of
// Rcpp::CharacterMatrix and then simply
// Rcpp::CharacterMatrix mat (nrow, ncol, value_vec.begin ()); ?
void get_value_mat_way (Ways::const_iterator wayi, const Ways &ways,
        const UniqueVals &unique_vals, Rcpp::CharacterMatrix &value_arr, int rowi)
{
    for (auto kv_iter = wayi->second.key_val.begin ();
            kv_iter != wayi->second.key_val.end (); ++kv_iter)
    {
        const std::string &key = kv_iter->first;
        int coli = std::distance (unique_vals.k_way.begin (),
                unique_vals.k_way.find (key));
        value_arr (rowi, coli) = kv_iter->second;
    }
}

/* get_value_mat_rel
 *
 * Extract key-value pairs for a given relation and fill Rcpp::CharacterMatrix
 *
 * @param reli Constant iterator to one OSM relation
 * @param rels Pointer to the std::vector of all relations
 * @param unique_vals Pointer to the UniqueVals structure
 * @param value_arr Pointer to the Rcpp::CharacterMatrix of values to be filled
 *        by tracing the key-val pairs of the relation 'reli'
 * @param rowi Integer value for the key-val pairs for reli
 */
void get_value_mat_rel (Relations::const_iterator reli, const Relations &rels,
        const UniqueVals &unique_vals, Rcpp::CharacterMatrix &value_arr, int rowi)
{
    for (auto kv_iter = reli->key_val.begin (); kv_iter != reli->key_val.end ();
            ++kv_iter)
    {
        const std::string &key = kv_iter->first;
        int coli = std::distance (unique_vals.k_rel.begin (),
                unique_vals.k_rel.find (key));
        value_arr (rowi, coli) = kv_iter->second;
    }
}


/* restructure_kv_mat
 *
 * Restructures a key-value matrix to reflect typical GDAL output by
 * inserting a first column containing "osm_id" and moving the "name" column to
 * second position.
 *
 * @param kv Pointer to the key-value matrix to be restructured
 * @param ls true only for multilinestrings, which have compound rownames which
 *        include roles
 */
Rcpp::CharacterMatrix restructure_kv_mat (Rcpp::CharacterMatrix &kv, bool ls=false)
{
    // The following has to be done in 2 lines:
    std::vector <std::vector <std::string> > dims = kv.attr ("dimnames");
    std::vector <std::string> ids = dims [0], varnames = dims [1], varnames_new;
    Rcpp::CharacterMatrix kv_out;

    int ni = std::distance (varnames.begin (),
            std::find (varnames.begin (), varnames.end (), "name"));
    int add_lines = 1;
    if (ls)
        add_lines++;

    if (ni < varnames.size ())
    {
        Rcpp::CharacterVector name_vals = kv.column (ni);
        Rcpp::CharacterVector roles; // only for ls, but has to be defined here
        // convert ids to CharacterVector - direct allocation doesn't work
        Rcpp::CharacterVector ids_rcpp (ids.size ());
        if (!ls)
            for (int i=0; i<ids.size (); i++)
                ids_rcpp (i) = ids [i];
        else
        { // extract way roles for multilinestring kev-val matrices
            roles = Rcpp::CharacterVector (ids.size ());
            for (int i=0; i<ids.size (); i++)
            {
                int ipos = ids [i].find ("-", 0);
                ids_rcpp (i) = ids [i].substr (0, ipos).c_str ();
                roles (i) = ids [i].substr (ipos + 1, ids[i].length () - ipos);
            }
        }

        varnames_new.reserve (kv.ncol () + add_lines);
        varnames_new.push_back ("osm_id");
        varnames_new.push_back ("name");
        kv_out = Rcpp::CharacterMatrix (Rcpp::Dimension (kv.nrow (),
                    kv.ncol () + add_lines));
        kv_out.column (0) = ids_rcpp;
        kv_out.column (1) = name_vals;
        if (ls)
        {
            varnames_new.push_back ("role");
            kv_out.column (2) = roles;
        }
        int count = 1 + add_lines;
        for (int i=0; i<kv.ncol (); i++)
            if (i != ni)
            {
                varnames_new.push_back (varnames [i]);
                kv_out.column (count++) = kv.column (i);
            }
        kv_out.attr ("dimnames") = Rcpp::List::create (ids, varnames_new);
    } else
        kv_out = kv;

    return kv_out;
}

