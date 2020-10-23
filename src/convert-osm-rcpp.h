/***************************************************************************
 *  Project:    osmdata
 *  File:       convert_osm_rcpp.h
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
 *  Description:    Functions to convert OSM data stored in C++ arrays to Rcpp
 *                  structures.
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdata)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#pragma once

#include "common.h"

#include <Rcpp.h>

namespace osm_convert {

void trace_way_nmat (const Ways &ways, const Nodes &nodes, 
        const osmid_t &wayi_id, Rcpp::NumericMatrix &nmat);

void get_value_mat_way (Ways::const_iterator wayi,
        const UniqueVals &unique_vals, Rcpp::CharacterMatrix &value_arr,
        unsigned int rowi);

void get_value_mat_rel (Relations::const_iterator &reli,
        const UniqueVals &unique_vals, Rcpp::CharacterMatrix &value_arr,
        unsigned int rowi);

Rcpp::CharacterMatrix restructure_kv_mat (Rcpp::CharacterMatrix &kv, bool ls);

template <typename T> Rcpp::List convert_poly_linestring_to_sf (
        const double_arr3 &lon_arr, const double_arr3 &lat_arr, 
        const string_arr3 &rowname_arr, 
        const std::vector <std::vector <T> > &id_vec, 
        const std::vector <std::string> &rel_id, const std::string type);

void convert_multipoly_to_sp (Rcpp::S4 &multipolygons, const Relations &rels,
        const double_arr3 &lon_arr, const double_arr3 &lat_arr, 
        const string_arr3 &rowname_arr, const string_arr2 &id_vec,
        const UniqueVals &unique_vals);

void convert_multiline_to_sp (Rcpp::S4 &multilines, const Relations &rels,
        const double_arr3 &lon_arr, const double_arr3 &lat_arr, 
        const string_arr3 &rowname_arr, const osmt_arr2 &id_vec,
        const UniqueVals &unique_vals);

void convert_relation_to_sc (string_arr2 &members_out,
        string_arr2 &kv_out, const Relations &rels,
        const UniqueVals &unique_vals);

} // end namespace osm_convert
