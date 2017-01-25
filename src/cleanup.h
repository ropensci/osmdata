/***************************************************************************
 *  Project:    osmdata
 *  File:       cleanup.h
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
 *  Description:    Generic routines to cleck and clean dynamic arrays
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#pragma once

#include "common.h"

void reserve_arrs (std::vector <float> &lats, std::vector <float> &lons,
        std::vector <std::string> &rownames, int n);

void check_geom_arrs (const float_arr3 &lon_arr, const float_arr3 &lat_arr,
        const string_arr3 &rowname_arr);

/*
 * TODO: check that all dynamic arrays are properly de-allocated - valgrind
void clean_geom_arrs (float_arr3 &lon_arr, float_arr3 &lat_arr,
        string_arr3 &rowname_arr);

void clear_id_vecs (std::vector <std::vector <osmid_t> > &id_vec_ls, 
    std::vector <std::vector <std::string> > &id_vec_mp);

void clean_kv_arrs (std::vector <std::vector <std::string> > &value_arr_mp,
        std::vector <std::vector <std::string> > &value_arr_ls);

void clean_geom_vecs (float_arr2 &lon_vec, float_arr2 &lat_vec,
        string_arr2 &rowname_vec);
 */
