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
void osm_convert::trace_way_nmat (const Ways &ways, const Nodes &nodes, 
        const osmid_t &wayi_id, Rcpp::NumericMatrix &nmat)
{
    auto wayi = ways.find (wayi_id);
    std::vector <std::string> rownames;
    rownames.clear ();
    size_t n = wayi->second.nodes.size ();
    rownames.reserve (n);
    nmat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));

    size_t tempi = 0;
    for (auto ni = wayi->second.nodes.begin ();
            ni != wayi->second.nodes.end (); ++ni)
    {
        rownames.push_back (std::to_string (*ni));
        //nmat (tempi, 0) = static_cast <double> (nodes.find (*ni)->second.lon);
        //nmat (tempi++, 1) = static_cast <double> (nodes.find (*ni)->second.lat);
        nmat (tempi, 0) = nodes.find (*ni)->second.lon;
        nmat (tempi++, 1) = nodes.find (*ni)->second.lat;
    }

    std::vector <std::string> colnames = {"lon", "lat"};
    Rcpp::List dimnames (0);
    dimnames.push_back (rownames);
    dimnames.push_back (colnames);
    nmat.attr ("dimnames") = dimnames;
    //dimnames.erase (0, static_cast <int> (dimnames.size ()));
    dimnames.erase (0, 2);
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
void osm_convert::get_value_mat_way (Ways::const_iterator wayi,
        const UniqueVals &unique_vals, Rcpp::CharacterMatrix &value_arr,
        unsigned int rowi)
{
    for (auto kv_iter = wayi->second.key_val.begin ();
            kv_iter != wayi->second.key_val.end (); ++kv_iter)
    {
        const std::string &key = kv_iter->first;
        unsigned int coli = unique_vals.k_way_index.at (key);
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
void osm_convert::get_value_mat_rel (Relations::const_iterator &reli,
        const UniqueVals &unique_vals, Rcpp::CharacterMatrix &value_arr,
        unsigned int rowi)
{
    for (auto kv_iter = reli->key_val.begin (); kv_iter != reli->key_val.end ();
            ++kv_iter)
    {
        const std::string &key = kv_iter->first;
        unsigned int coli = unique_vals.k_rel_index.at (key);
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
Rcpp::CharacterMatrix osm_convert::restructure_kv_mat (Rcpp::CharacterMatrix &kv, bool ls=false)
{
    // The following has to be done in 2 lines:
    std::vector <std::vector <std::string> > dims = kv.attr ("dimnames");
    std::vector <std::string> ids = dims [0], varnames = dims [1], varnames_new;
    Rcpp::CharacterMatrix kv_out;

    int ni = static_cast <int> (std::distance (varnames.begin (),
            std::find (varnames.begin (), varnames.end (), "name")));
    unsigned int add_lines = 1;
    if (ls)
        add_lines++;

    // This only processes entries that have key = "name". Those that don't do
    // not get their osm_id values appended. It's then easier to post-append
    // these, rather than modify this code
    if (ni < static_cast <int> (varnames.size ()))
    {
        Rcpp::CharacterVector name_vals = kv.column (ni);
        Rcpp::CharacterVector roles; // only for ls, but has to be defined here
        // convert ids to CharacterVector - direct allocation doesn't work
        Rcpp::CharacterVector ids_rcpp (ids.size ());
        if (!ls)
            for (unsigned int i=0; i<ids.size (); i++)
                ids_rcpp (i) = ids [i];
        else
        { // extract way roles for multilinestring kev-val matrices
            roles = Rcpp::CharacterVector (ids.size ());
            for (unsigned int i=0; i<ids.size (); i++)
            {
                size_t ipos = ids [i].find ("-", 0);
                ids_rcpp (i) = ids [i].substr (0, ipos).c_str ();
                roles (i) = ids [i].substr (ipos + 1, ids[i].length () - ipos);
            }
        }

        varnames_new.reserve (static_cast <unsigned int> (kv.ncol ()) +
                add_lines);
        varnames_new.push_back ("osm_id");
        varnames_new.push_back ("name");
        kv_out = Rcpp::CharacterMatrix (Rcpp::Dimension (
                    static_cast <unsigned int> (kv.nrow ()),
                    static_cast <unsigned int> (kv.ncol ()) + add_lines));
        kv_out.column (0) = ids_rcpp;
        kv_out.column (1) = name_vals;
        if (ls)
        {
            varnames_new.push_back ("role");
            kv_out.column (2) = roles;
        }
        int count = 1 + static_cast <int> (add_lines);
        int i_int = 0;
        for (unsigned int i=0; i<static_cast <unsigned int> (kv.ncol ()); i++)
        {
            if (i != static_cast <unsigned int> (ni))
            {
                varnames_new.push_back (varnames [i]);
                kv_out.column (count++) = kv.column (i_int);
            }
            i_int++;
        }
        kv_out.attr ("dimnames") = Rcpp::List::create (ids, varnames_new);
    } else
        kv_out = kv;

    return kv_out;
}

/* convert_poly_linestring_to_sf
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
template <typename T> Rcpp::List osm_convert::convert_poly_linestring_to_sf (
        const double_arr3 &lon_arr, const double_arr3 &lat_arr, 
        const string_arr3 &rowname_arr, 
        const std::vector <std::vector <T> > &id_vec, 
        const std::vector <std::string> &rel_id, const std::string type)
{
    if (!(type == "MULTILINESTRING" || type == "MULTIPOLYGON"))
        throw std::runtime_error ("type must be multilinestring/polygon"); // # nocov
    Rcpp::List outList (lon_arr.size ()); 
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));
    Rcpp::List dimnames (0);
    std::vector <std::string> colnames = {"lat", "lon"};
    for (unsigned int i=0; i<lon_arr.size (); i++) // over all relations
    {
        Rcpp::List outList_i (lon_arr [i].size ()); 
        for (unsigned int j=0; j<lon_arr [i].size (); j++) // over all ways
        {
            size_t n = lon_arr [i][j].size ();
            nmat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));
            std::copy (lon_arr [i][j].begin (), lon_arr [i][j].end (),
                    nmat.begin ());
            std::copy (lat_arr [i][j].begin (), lat_arr [i][j].end (),
                    nmat.begin () + n);
            dimnames.push_back (rowname_arr [i][j]);
            dimnames.push_back (colnames);
            nmat.attr ("dimnames") = dimnames;
            //dimnames.erase (0, static_cast <int> (dimnames.size ()));
            dimnames.erase (0, 2);
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
template Rcpp::List osm_convert::convert_poly_linestring_to_sf <osmid_t> (
        const double_arr3 &lon_arr, const double_arr3 &lat_arr, 
        const string_arr3 &rowname_arr, 
        const std::vector <std::vector <osmid_t> > &id_vec, 
        const std::vector <std::string> &rel_id, const std::string type);
template Rcpp::List osm_convert::convert_poly_linestring_to_sf <std::string> (
        const double_arr3 &lon_arr, const double_arr3 &lat_arr, 
        const string_arr3 &rowname_arr, 
        const std::vector <std::vector <std::string> > &id_vec, 
        const std::vector <std::string> &rel_id, const std::string type);

/* convert_multipoly_to_sp
 *
 * Converts the data contained in all the arguments into a
 * SpatialPolygonsDataFrame
 *
 * @param lon_arr 3D array of longitudinal coordinates
 * @param lat_arr 3D array of latgitudinal coordinates
 * @param rowname_arr 3D array of <osmid_t> IDs for nodes of all (lon,lat)
 * @param id_vec 2D array of either <std::string> or <osmid_t> IDs for all ways
 *        used in the geometry.
 * @param rel_id Vector of <osmid_t> IDs for each relation.
 *
 * @return Object pointed to by 'multipolygons' is constructed.
 */
void osm_convert::convert_multipoly_to_sp (Rcpp::S4 &multipolygons, const Relations &rels,
        const double_arr3 &lon_arr, const double_arr3 &lat_arr, 
        const string_arr3 &rowname_arr, const string_arr2 &id_vec,
        const UniqueVals &unique_vals)
{
    Rcpp::Environment sp_env = Rcpp::Environment::namespace_env ("sp");
    Rcpp::Function Polygon = sp_env ["Polygon"];
    Rcpp::Language polygons_call ("new", "Polygons");

    size_t nrow = lon_arr.size (), ncol = unique_vals.k_rel.size ();
    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nrow, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);

    Rcpp::List outList (lon_arr.size ()); 
    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));
    Rcpp::List dimnames (0);
    std::vector <std::string> colnames = {"lat", "lon"}, rel_id;

    unsigned int npolys = 0;
    for (auto itr = rels.begin (); itr != rels.end (); itr++)
        if (itr->ispoly)
            npolys++;
    if (npolys != lon_arr.size ())
        throw std::runtime_error ("polygons must be same size as geometries"); // # nocov
    rel_id.reserve (npolys);

    unsigned int i = 0;
    for (auto itr = rels.begin (); itr != rels.end (); itr++)
        if (itr->ispoly)
        {
            Rcpp::List outList_i (lon_arr [i].size ()); 
            // j over all ways, with outer always first followed by inner
            bool outer = true;
            //std::vector <int> plotorder (lon_arr [i].size ());
            Rcpp::IntegerVector plotorder (lon_arr [i].size ());
            for (unsigned int j=0; j<lon_arr [i].size (); j++) 
            {
                size_t n = lon_arr [i][j].size ();
                nmat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));
                std::copy (lon_arr [i][j].begin (), lon_arr [i][j].end (),
                        nmat.begin ());
                std::copy (lat_arr [i][j].begin (), lat_arr [i][j].end (),
                        nmat.begin () + n);
                dimnames.push_back (rowname_arr [i][j]);
                dimnames.push_back (colnames);
                nmat.attr ("dimnames") = dimnames;
                //dimnames.erase (0, static_cast <int> (dimnames.size ()));
                dimnames.erase (0, 2);

                Rcpp::S4 poly = Polygon (nmat);
                poly.slot ("hole") = !outer;
                poly.slot ("ringDir") = static_cast <int> (1);
                if (outer)
                    outer = false;
                else
                    poly.slot ("ringDir") = static_cast <int> (-1);
                outList_i [j] = poly;
                plotorder [j] = static_cast <int> (j) + 1; // 1-based R values
            }
            outList_i.attr ("names") = id_vec [i];

            Rcpp::S4 polygons = polygons_call.eval ();
            polygons.slot ("Polygons") = outList_i;
            // Issue #36 caused by data with one item having no actual data for
            // one item, so id_vec[i].size = lon_vec[i].size = ... = 0
            if (id_vec [i].size () > 0)
            {
                // convert id_vec to single string
                std::string id_vec_str = id_vec [i] [0];
                for (unsigned int j = 1;
                        j < static_cast <unsigned int> (id_vec [i].size ()); j++)
                    id_vec_str += "." + id_vec [i] [j];
                polygons.slot ("ID") = id_vec_str;
            }
            //polygons.slot ("ID") = id_vec [i]; // sp expects char not vec!
            polygons.slot ("plotOrder") = plotorder;
            //polygons.slot ("labpt") = poly.slot ("labpt");
            //polygons.slot ("area") = poly.slot ("area");
            outList [i] = polygons;
            rel_id.push_back (std::to_string (itr->id));

            osm_convert::get_value_mat_rel (itr, unique_vals, kv_mat, i++);
        } // end if ispoly & for i
    outList.attr ("names") = rel_id;

    Rcpp::Language sp_polys_call ("new", "SpatialPolygonsDataFrame");
    multipolygons = sp_polys_call.eval ();
    multipolygons.slot ("polygons") = outList;

    // Fill plotOrder slot with int vector - this has to be int, not
    // unsigned int!
    std::vector <int> plotord (rels.size ());
    for (size_t j = 0; j < rels.size (); j++)
        plotord [j] = static_cast <int> (j + 1);
    multipolygons.slot ("plotOrder") = plotord;
    plotord.clear ();

    Rcpp::DataFrame kv_df = R_NilValue;
    if (rel_id.size () > 0)
    {
        kv_mat.attr ("names") = unique_vals.k_rel;
        kv_mat.attr ("dimnames") = Rcpp::List::create (rel_id, unique_vals.k_rel);
        kv_mat.attr ("names") = unique_vals.k_rel;
        if (kv_mat.nrow () > 0 && kv_mat.ncol () > 0)
            kv_df = osm_convert::restructure_kv_mat (kv_mat, false);
        multipolygons.slot ("data") = kv_df;
    }
    rel_id.clear ();
}


/* convert_multiline_to_sp
 *
 * Converts the data contained in all the arguments into a SpatialLinesDataFrame
 *
 * @param lon_arr 3D array of longitudinal coordinates
 * @param lat_arr 3D array of latgitudinal coordinates
 * @param rowname_arr 3D array of <osmid_t> IDs for nodes of all (lon,lat)
 * @param id_vec 2D array of either <std::string> or <osmid_t> IDs for all ways
 *        used in the geometry.
 * @param rel_id Vector of <osmid_t> IDs for each relation.
 *
 * @return Object pointed to by 'multilines' is constructed.
 */
void osm_convert::convert_multiline_to_sp (Rcpp::S4 &multilines, const Relations &rels,
        const double_arr3 &lon_arr, const double_arr3 &lat_arr, 
        const string_arr3 &rowname_arr, const osmt_arr2 &id_vec,
        const UniqueVals &unique_vals)
{

    Rcpp::Language line_call ("new", "Line");
    Rcpp::Language lines_call ("new", "Lines");

    Rcpp::NumericMatrix nmat (Rcpp::Dimension (0, 0));
    Rcpp::List dimnames (0);
    std::vector <std::string> colnames = {"lat", "lon"}, rel_id;

    unsigned int nlines = 0;
    for (auto itr = rels.begin (); itr != rels.end (); itr++)
        if (!itr->ispoly)
            nlines++;
    rel_id.reserve (nlines);

    Rcpp::List outList (nlines); 
    size_t ncol = unique_vals.k_rel.size ();
    Rcpp::CharacterMatrix kv_mat (Rcpp::Dimension (nlines, ncol));
    std::fill (kv_mat.begin (), kv_mat.end (), NA_STRING);

    unsigned int i = 0;
    for (auto itr = rels.begin (); itr != rels.end (); itr++)
        if (!itr->ispoly)
        {
            Rcpp::List outList_i (lon_arr [i].size ()); 
            // j over all ways
            for (unsigned int j=0; j<lon_arr [i].size (); j++) 
            {
                size_t n = lon_arr [i][j].size ();
                nmat = Rcpp::NumericMatrix (Rcpp::Dimension (n, 2));
                std::copy (lon_arr [i][j].begin (), lon_arr [i][j].end (),
                        nmat.begin ());
                std::copy (lat_arr [i][j].begin (), lat_arr [i][j].end (),
                        nmat.begin () + n);
                dimnames.push_back (rowname_arr [i][j]);
                dimnames.push_back (colnames);
                nmat.attr ("dimnames") = dimnames;
                //dimnames.erase (0, static_cast <int> (dimnames.size ()));
                dimnames.erase (0, 2);

                Rcpp::S4 line = line_call.eval ();
                line.slot ("coords") = nmat;

                outList_i [j] = line;
            }
            outList_i.attr ("names") = id_vec [i]; // implicit type conversion
            Rcpp::S4 lines = lines_call.eval ();
            lines.slot ("Lines") = outList_i;
            lines.slot ("ID") = itr->id;

            outList [i] = lines;
            rel_id.push_back (std::to_string (itr->id));

            osm_convert::get_value_mat_rel (itr, unique_vals, kv_mat, i++);
        } // end if ispoly & for i
    outList.attr ("names") = rel_id;

    Rcpp::Language sp_lines_call ("new", "SpatialLinesDataFrame");
    multilines = sp_lines_call.eval ();
    multilines.slot ("lines") = outList;

    Rcpp::DataFrame kv_df = R_NilValue;
    if (rel_id.size () > 0)
    {
        kv_mat.attr ("names") = unique_vals.k_rel;
        kv_mat.attr ("dimnames") = Rcpp::List::create (rel_id, unique_vals.k_rel);
        kv_mat.attr ("names") = unique_vals.k_rel;
        if (kv_mat.nrow () > 0 && kv_mat.ncol () > 0)
            kv_df = osm_convert::restructure_kv_mat (kv_mat, true);
        multilines.slot ("data") = kv_df;
    }
    rel_id.clear ();
}

/* convert_relation_to_sc
 *
 * Converts the data contained in all the arguments into an SC object
 *
 * @param id_vec 2D array of either <std::string> or <osmid_t> IDs for all ways
 *        used in the geometry.
 *
 * @return Objects pointed to by 'members_out' and 'kv_out' are constructed.
 */
void osm_convert::convert_relation_to_sc (string_arr2 &members_out,
        string_arr2 &kv_out, const Relations &rels,
        const UniqueVals &unique_vals)
{
    size_t nmembers = 0;
    for (auto itr = rels.begin (); itr != rels.end (); itr++)
        nmembers += itr->relations.size ();

    members_out.resize (nmembers);
    for (auto m: members_out)
        m.resize (3);

    size_t ncol = unique_vals.k_rel.size ();
    kv_out.resize (ncol);
    for (auto k: kv_out)
        k.resize (rels.size ());

    unsigned int rowi = 0; // explicit loop index - see note at top of osmdata-sf
    for (auto itr = rels.begin (); itr != rels.end (); itr++)
    {
        //const unsigned int rowi = static_cast <unsigned int> (
        //        std::distance (rels.begin (), itr));

        // Get all members of that relation and their roles:
        unsigned int rowj = rowi;
        for (auto ritr = itr->relations.begin ();
                ritr != itr->relations.end (); ++ritr)
        {
            //const unsigned int rowj = rowi + static_cast <unsigned int> (
            //        std::distance (itr->relations.begin (), ritr));
            members_out [rowj] [0] = std::to_string (itr->id);
            members_out [rowj] [1] = std::to_string (ritr->first); // OSM id
            members_out [rowj++] [2] = ritr->second; // role
        }
        
        // And then key-value pairs
        for (auto kv_iter = itr->key_val.begin ();
                kv_iter != itr->key_val.end (); ++kv_iter)
        {
            const std::string &key = kv_iter->first;
            //long int coli = static_cast <long int> (
            //        unique_vals.k_rel_index.at (key));
            unsigned int coli = unique_vals.k_rel_index.at (key);
            kv_out [coli] [rowi] = kv_iter->second;
        }
        rowi++;
    } // end for itr
}
