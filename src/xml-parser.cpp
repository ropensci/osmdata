#include <Rcpp.h>
#include <xml-parser.h>

using namespace Rcpp;

// [[Rcpp::export]]
List test (std::string st)
{
    Xml xml (st);

    int count = 0;
    long long ni;
    umapPair_Itr umapitr;
    typedef std::vector <long long>::iterator ll_Itr;

    List result (xml.ways.size ());

    std::vector <float> vec;
    std::vector <std::vector <float> > mat;

    for (Ways_Itr wi = xml.ways.begin(); wi != xml.ways.end(); ++wi)
    {
        // Set up first origin node
        ni = (*wi).nodes.front ();
        // TODO: Not much point having assert in an Rcpp file!
        assert ((umapitr = xml.nodes.find (ni)) != xml.nodes.end ());

        vec.resize (0);
        mat.resize (0);
        // TODO: Find out why the following pointer lines do not work here
        //vec.push_back ((*umapitr).second.first);
        //vec.push_back ((*umapitr).second.second);
        vec.push_back (xml.nodes [ni].first);
        vec.push_back (xml.nodes [ni].second);
        mat.push_back (vec);

        // Then iterate over the remaining nodes of that way
        for (ll_Itr it = std::next ((*wi).nodes.begin ());
                it != (*wi).nodes.end (); it++)
        {
            assert ((umapitr = nodes.find (*it)) != nodes.end ());
            vec.resize (0);
            vec.push_back (xml.nodes [*it].first);
            vec.push_back (xml.nodes [*it].second);
            mat.push_back (vec);
        }
        result [count++] = mat;
    }

    vec.resize (0);
    mat.resize (0);

    return result;
}

