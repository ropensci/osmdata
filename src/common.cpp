
#include "common.h"

// APS sadly xml_document has no copy constructor, so despite NRVO/copy elision,
// cannot return by value.  This forces us into using a unique_ptr
XmlDocPtr parseXML (const std::string& xmlString)
{
    XmlDocPtr doc (new rapidxml::xml_document<>());
    doc->parse<0> (const_cast<char*> (xmlString.c_str()));
    return doc;
}
