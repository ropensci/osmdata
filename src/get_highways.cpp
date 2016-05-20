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
    std::vector <std::string> names;
    List result (xml.ways.size ());
    NumericMatrix nmat (Dimension (0, 0));

    names.resize (0);

    for (Ways_Itr wi = xml.ways.begin(); wi != xml.ways.end(); ++wi)
    {
        names.push_back (std::to_string ((*wi).id));
        // Set up first origin node
        ni = (*wi).nodes.front ();
        // TODO: Not much point having assert in an Rcpp file!
        assert ((umapitr = xml.nodes.find (ni)) != xml.nodes.end ());

        lon.resize (0);
        lat.resize (0);
        // TODO: Find out why the following pointer lines do not work here
        //lon.push_back ((*umapitr).second.first);
        //lat.push_back ((*umapitr).second.second);
        lon.push_back (xml.nodes [ni].first);
        lat.push_back (xml.nodes [ni].second);

        // Then iterate over the remaining nodes of that way
        for (ll_Itr it = std::next ((*wi).nodes.begin ());
                it != (*wi).nodes.end (); it++)
        {
            assert ((umapitr = nodes.find (*it)) != nodes.end ());
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
        result [count++] = nmat;
    }
    result.attr ("names") = names;

    lon.resize (0);
    lat.resize (0);
    names.resize (0);

    return result;
}

