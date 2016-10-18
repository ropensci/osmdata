/***************************************************************************
 *  Project:    osmdatar
 *  File:       get-bbox.h
 *  Language:   C++
 *
 *  osmdatar is free software: you can redistribute it and/or modify it under
 *  the terms of the GNU General Public License as published by the Free
 *  Software Foundation, either version 3 of the License, or (at your option)
 *  any later version.
 *
 *  osmdatar is distributed in the hope that it will be useful, but WITHOUT ANY
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
 *  Description:    Header for rcpp_get_bbox
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdatar)
 *
 *  Compiler Options:   -std=c++11 
 ***************************************************************************/

#ifndef GETBBOX_H
#define GETBBOX_H

#include <Rcpp.h>

Rcpp::NumericMatrix rcpp_get_bbox (float xmin, float xmax, float ymin, float ymax);

#endif
