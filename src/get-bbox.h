/***************************************************************************
 *  Project:    osmdata
 *  File:       get-bbox.h
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
 *  Description:    Header for rcpp_get_bbox
 *
 *  Limitations:
 *
 *  Dependencies:       none (rapidXML header included in osmdata)
 *
 *  Compiler Options:   -std=c++11 
 ***************************************************************************/

#pragma once

#include <Rcpp.h>

Rcpp::NumericMatrix rcpp_get_bbox (double xmin, double xmax, double ymin, double ymax);
Rcpp::NumericVector rcpp_get_bbox_sf (double xmin, double xmax, double ymin, double ymax);
