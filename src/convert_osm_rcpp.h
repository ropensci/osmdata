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

#pragma once

#include "common.h"

#include <Rcpp.h>

void trace_way_nmat (const Ways &ways, const Nodes &nodes, 
        const osmid_t &wayi_id, Rcpp::NumericMatrix &nmat);

void get_value_mat_way (Ways::const_iterator wayi, const Ways &ways,
        const UniqueVals &unique_vals, Rcpp::CharacterMatrix &value_arr, int rowi);

void get_value_mat_rel (Relations::const_iterator reli, const Relations &rels,
        const UniqueVals &unique_vals, Rcpp::CharacterMatrix &value_arr, int rowi);

Rcpp::CharacterMatrix restructure_kv_mat (Rcpp::CharacterMatrix &kv, bool ls);

/* convert_poly_linestring_to_Rcpp
 *
 * Converts the data contained in all the arguments into an Rcpp::List object
 * to be used as the geometry column of a Simple Features Colletion
 *
 * @param lon_arr 3D array of longitudinal coordinates
 * @param lat_arr 3D array of latgitudinal coordinates
 * @param rowname_arr 3D array of <osmid_t> IDs for nodes of all (lon,lat)
 * @param id_vec 2D array of either <std::string> or <osmid_t> IDs for all ways
 *        used in the geometry.
 * @param rel_id Vector of <osmid_t> IDs for each relation.
 *
 * @return An Rcpp::List object of [relation][way][node/geom] data.
 */
// TODO: Replace return value with pointer to List as argument?
template <typename T, typename A> // std::vector of osmid_t or std::string
Rcpp::List convert_poly_linestring_to_Rcpp (const float_arr3 lon_arr, 
        const float_arr3 lat_arr, const string_arr3 rowname_arr, 
        const std::vector <std::vector <T,A> > &id_vec, 
        const std::vector <std::string> &rel_id, const std::string type)
{
    if (!(type == "MULTILINESTRING" || type == "MULTIPOLYGON"))
        throw std::runtime_error ("type must be multilinestring/polygon");
    Rcpp::List outList (lon_arr.size ()); 
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));
    Rcpp::List dimnames (0);
    std::vector <std::string> colnames = {"lat", "lon"};
    for (int i=0; i<lon_arr.size (); i++) // over all relations
    {
        Rcpp::List outList_i (lon_arr [i].size ()); 
        for (int j=0; j<lon_arr [i].size (); j++) // over all ways
        {
            int n = lon_arr [i][j].size ();
            nmat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));
            std::copy (lon_arr [i][j].begin (), lon_arr [i][j].end (),
                    nmat.begin ());
            std::copy (lat_arr [i][j].begin (), lat_arr [i][j].end (),
                    nmat.begin () + n);
            dimnames.push_back (rowname_arr [i][j]);
            dimnames.push_back (colnames);
            nmat.attr ("dimnames") = dimnames;
            dimnames.erase (0, dimnames.size ());
            outList_i [j] = nmat;
        }
        outList_i.attr ("names") = id_vec [i];
        if (type == "MULTIPOLYGON")
        {
            Rcpp::List tempList (1);
            tempList (0) = outList_i;
            tempList.attr ("class") = Rcpp::CharacterVector::create ("XY", type, "sfg");
            outList [i] = tempList;
        } else
        {
            outList_i.attr ("class") = Rcpp::CharacterVector::create ("XY", type, "sfg");
            outList [i] = outList_i;
        }
    }
    outList.attr ("names") = rel_id;

    return outList;
}

