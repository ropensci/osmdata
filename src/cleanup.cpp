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
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
 *
 *  Compiler Options:   -std=c++11
 ***************************************************************************/

#include "cleanup.h"


// ----- clean_vec
template <typename T> void clean_vec (std::vector <std::vector <T> > &arr2)
{
    for (unsigned i=0; i<arr2.size (); i++)
        arr2 [i].clear ();
    arr2.clear ();
}
template void clean_vec <float> (std::vector <std::vector <float> > &arr2);
template void clean_vec <osmid_t> (std::vector <std::vector <osmid_t> > &arr2);
template void clean_vec <std::string> (std::vector <std::vector <std::string> > &arr2);

// ----- clean_vecs with 2 args
template <typename T1, typename T2> void clean_vecs (
        std::vector <std::vector <T1> > &arr2_1,
        std::vector <std::vector <T2> > &arr2_2)
{
    clean_vec (arr2_1);
    clean_vec (arr2_2);
}
template void clean_vecs <std::string, osmid_t> (
        std::vector <std::vector <std::string> > &arr2_1,
        std::vector <std::vector <osmid_t> > &arr2_2);

// ----- clean_vecs with 3 args
template <typename T1, typename T2, typename T3> void clean_vecs (
        std::vector <std::vector <T1> > &arr2_1,
        std::vector <std::vector <T2> > &arr2_2,
        std::vector <std::vector <T3> > &arr2_3)
{
    clean_vec (arr2_1);
    clean_vec (arr2_2);
    clean_vec (arr2_3);
}
template void clean_vecs <float, float, std::string> (
        std::vector <std::vector <float> > &arr2_1,
        std::vector <std::vector <float> > &arr2_2,
        std::vector <std::vector <std::string> > &arr2_3);

// ----- clean_arr
template <typename T> void clean_arr (
        std::vector <std::vector <std::vector <T> > > &arr3)
{
    for (unsigned i=0; i<arr3.size (); i++)
    {
        for (unsigned j=0; j<arr3[i].size (); j++)
            arr3 [i][j].clear ();
        arr3 [i].clear ();
    }
    arr3.clear ();
}
template void clean_arr <float> (
        std::vector <std::vector <std::vector <float> > > &arr3);
template void clean_arr <std::string> (
        std::vector <std::vector <std::vector <std::string> > > &arr3);

// ----- clean_arrs with 2 args - not used
template <typename T1, typename T2> void clean_arrs (
        std::vector <std::vector <std::vector <T1> > > &arr3_1,
        std::vector <std::vector <std::vector <T2> > > &arr3_2)
{
    clean_arr (arr3_1);
    clean_arr (arr3_2);
}

// ----- clean_arrs with 3 args
template <typename T1, typename T2, typename T3> void clean_arrs (
        std::vector <std::vector <std::vector <T1> > > &arr3_1,
        std::vector <std::vector <std::vector <T2> > > &arr3_2,
        std::vector <std::vector <std::vector <T3> > > &arr3_3)
{
    clean_arr (arr3_1);
    clean_arr (arr3_2);
    clean_arr (arr3_3);
}
template void clean_arrs <float, float, std::string> (
        std::vector <std::vector <std::vector <float> > > &arr3_1,
        std::vector <std::vector <std::vector <float> > > &arr3_2,
        std::vector <std::vector <std::vector <std::string> > > &arr3_3);
