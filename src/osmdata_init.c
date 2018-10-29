#include <R.h>
#include <Rinternals.h>
#include <stdlib.h> // for NULL
#include <R_ext/Rdynload.h>

/* FIXME: 
   Check these declarations against the C/Fortran source code.
*/

/* .Call calls */
extern SEXP _osmdata_rcpp_osmdata_sc(SEXP);
extern SEXP _osmdata_rcpp_osmdata_sf(SEXP);
extern SEXP _osmdata_rcpp_osmdata_sp(SEXP);

static const R_CallMethodDef CallEntries[] = {
    {"_osmdata_rcpp_osmdata_sc", (DL_FUNC) &_osmdata_rcpp_osmdata_sc, 1},
    {"_osmdata_rcpp_osmdata_sf", (DL_FUNC) &_osmdata_rcpp_osmdata_sf, 1},
    {"_osmdata_rcpp_osmdata_sp", (DL_FUNC) &_osmdata_rcpp_osmdata_sp, 1},
    {NULL, NULL, 0}
};

void R_init_osmdata(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
