/***************************************************************************
 *  Project:    osmdata
 *  File:       cleanup.cpp
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
 *                  it in Rcpp::List format.
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#include "cleanup.h"

void reserve_arrs (std::vector <float> &lats, std::vector <float> &lons,
        std::vector <std::string> &rownames, int n)
{
        lons.clear ();
        lats.clear ();
        rownames.clear ();
        lons.reserve (n);
        lats.reserve (n);
        rownames.reserve (n);
}

// Sanity check to ensure all 3D geometry arrays have same sizes
void check_geom_arrs (const float_arr3 &lon_arr, const float_arr3 &lat_arr,
        const string_arr3 &rowname_arr)
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
}

