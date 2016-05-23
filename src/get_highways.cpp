#include "get_highways.h"
#include <Rcpp.h>

using namespace Rcpp;

// [[Rcpp::export]]
List get_highways (std::string st)
{
    Xml xml (st);

    int count = 0;
    long long ni;
    umapPair_Itr umapitr;
    typedef std::vector <long long>::iterator ll_Itr;

    std::vector <float> lat, lon;
    std::vector <std::string> colnames, waynames;
    colnames.push_back ("lon");
    colnames.push_back ("lat");
    List dimnames (2), result (xml.ways.size ());
    NumericMatrix nmat (Dimension (0, 0));

    waynames.resize (0);

    for (Ways_Itr wi = xml.ways.begin(); wi != xml.ways.end(); ++wi)
    {
        waynames.push_back (std::to_string ((*wi).id));
        // Set up first origin node
        ni = (*wi).nodes.front ();

        lon.resize (0);
        lat.resize (0);
        // TODO: Find out why the following pointer lines do not work here
        // assert ((umapitr = xml.nodes.find (ni)) != xml.nodes.end ());
        //lon.push_back ((*umapitr).second.first);
        //lat.push_back ((*umapitr).second.second);
        lon.push_back (xml.nodes [ni].first);
        lat.push_back (xml.nodes [ni].second);

        // Then iterate over the remaining nodes of that way
        for (ll_Itr it = std::next ((*wi).nodes.begin ());
                it != (*wi).nodes.end (); it++)
        {
            //assert ((umapitr = nodes.find (*it)) != nodes.end ());
            lon.push_back (xml.nodes [*it].first);
            lat.push_back (xml.nodes [*it].second);
        }

        // Current solution: Copy to nmat. TODO: Improve?
        nmat = NumericMatrix (Dimension (lon.size (), 2));
        for (int i=0; i<lon.size (); i++)
        {
            nmat (i, 0) = lon [i];
            nmat (i, 1) = lat [i];
        }
        // name can be stored for each list element, but this is slower:
        //nmat.attr ("name") = std::to_string ((*wi).id);
        dimnames (1) = colnames;
        nmat.attr ("dimnames") = dimnames;
        result [count++] = nmat;
    }
    result.attr ("names") = waynames;

    lon.resize (0);
    lat.resize (0);
    waynames.resize (0);
    colnames.resize (0);

    return result;
}

// [[Rcpp::export]]
List get_highways_with_id (std::string st)
{
    Xml xml (st);

    int count = 0;
    long long ni;
    umapPair_Itr umapitr;
    typedef std::vector <long long>::iterator ll_Itr;

    std::vector <float> lat, lon;
    std::vector <std::string> colnames, waynames;
    colnames.push_back ("id");
    colnames.push_back ("lon");
    colnames.push_back ("lat");
    List dimnames (2), result (xml.ways.size ());
    NumericMatrix nmat (Dimension (0, 0));

    waynames.resize (0);

    for (Ways_Itr wi = xml.ways.begin(); wi != xml.ways.end(); ++wi)
    {
        waynames.push_back (std::to_string ((*wi).id));
        // Set up first origin node
        ni = (*wi).nodes.front ();

        lon.resize (0);
        lat.resize (0);
        lon.push_back (xml.nodes [ni].first);
        lat.push_back (xml.nodes [ni].second);

        // Then iterate over the remaining nodes of that way
        for (ll_Itr it = std::next ((*wi).nodes.begin ());
                it != (*wi).nodes.end (); it++)
        {
            lon.push_back (xml.nodes [*it].first);
            lat.push_back (xml.nodes [*it].second);
        }

        // Current solution: Copy to nmat. TODO: Improve?
        nmat = NumericMatrix (Dimension (lon.size (), 3));
        for (int i=0; i<lon.size (); i++)
        {
            nmat (i, 0) = (*wi).id;
            nmat (i, 1) = lon [i];
            nmat (i, 2) = lat [i];
        }
        dimnames (1) = colnames;
        nmat.attr ("dimnames") = dimnames;
        result [count++] = nmat;
    }
    result.attr ("names") = waynames;

    lon.resize (0);
    lat.resize (0);
    colnames.resize (0);
    waynames.resize (0);

    return result;
}


// [[Rcpp::export]]
List get_highways_sp (std::string st)
{
    Xml xml (st);

    int count = 0;
    long long ni;
    umapPair_Itr umapitr;
    typedef std::vector <long long>::iterator ll_Itr;

    std::vector <float> lat, lon;
    std::vector <std::string> colnames, waynames;
    colnames.push_back ("lon");
    colnames.push_back ("lat");
    List dimnames (2);
    dimnames (1) = colnames;
    NumericMatrix nmat (Dimension (0, 0));
    List result (xml.ways.size ());

    Rcpp::Language line_call ("new", "Line");
    Rcpp::Language lines_call ("new", "Lines");
    Rcpp::S4 line;
    Rcpp::S4 lines;
    Rcpp::List dummy_list (0);

    waynames.resize (0);

    for (Ways_Itr wi = xml.ways.begin(); wi != xml.ways.end(); ++wi)
    {
        waynames.push_back (std::to_string ((*wi).id));
        // Set up first origin node
        ni = (*wi).nodes.front ();

        lon.resize (0);
        lat.resize (0);
        // TODO: Find out why the following pointer lines do not work here
        // assert ((umapitr = xml.nodes.find (ni)) != xml.nodes.end ());
        //lon.push_back ((*umapitr).second.first);
        //lat.push_back ((*umapitr).second.second);
        lon.push_back (xml.nodes [ni].first);
        lat.push_back (xml.nodes [ni].second);

        // Then iterate over the remaining nodes of that way
        for (ll_Itr it = std::next ((*wi).nodes.begin ());
                it != (*wi).nodes.end (); it++)
        {
            //assert ((umapitr = nodes.find (*it)) != nodes.end ());
            lon.push_back (xml.nodes [*it].first);
            lat.push_back (xml.nodes [*it].second);
        }

        // Current solution: Copy to nmat. TODO: Improve?
        nmat = NumericMatrix (Dimension (lon.size (), 2));
        for (int i=0; i<lon.size (); i++)
        {
            nmat (i, 0) = lon [i];
            nmat (i, 1) = lat [i];
        }
        // name can be stored for each list element, but this is slower:
        //nmat.attr ("name") = std::to_string ((*wi).id);
        nmat.attr ("dimnames") = dimnames;

        line = line_call.eval ();
        line.slot ("coords") = nmat;
        dummy_list.push_back (line);
        lines = lines_call.eval ();
        lines.slot ("Lines") = dummy_list;
        lines.slot ("ID") = std::to_string ((*wi).id);
        result [count++] = lines;
        
        dummy_list.erase (0);
    }
    result.attr ("names") = waynames;

    lon.resize (0);
    lat.resize (0);
    waynames.resize (0);
    colnames.resize (0);

    return result;
}
