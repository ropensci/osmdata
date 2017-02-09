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

template <typename T> void clean_vec (std::vector <std::vector <T> > &arr2);

template <typename T1, typename T2> void clean_vecs (
        std::vector <std::vector <T1> > &arr2_1,
        std::vector <std::vector <T2> > &arr2_2);

template <typename T1, typename T2, typename T3> void clean_vecs (
        std::vector <std::vector <T1> > &arr2_1,
        std::vector <std::vector <T2> > &arr2_2,
        std::vector <std::vector <T3> > &arr2_3);

template <typename T> void clean_arr (
        std::vector <std::vector <std::vector <T> > > &arr3);

template <typename T1, typename T2> void clean_arrs (
        std::vector <std::vector <std::vector <T1> > > &arr3_1,
        std::vector <std::vector <std::vector <T2> > > &arr3_2);

template <typename T1, typename T2, typename T3> void clean_arrs (
        std::vector <std::vector <std::vector <T1> > > &arr3_1,
        std::vector <std::vector <std::vector <T2> > > &arr3_2,
        std::vector <std::vector <std::vector <T3> > > &arr3_3);
