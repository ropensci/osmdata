#include <R.h>
#include <Rinternals.h>
#include <stdlib.h> // for NULL
#include <R_ext/Rdynload.h>

/* .Call calls */
extern SEXP osmdata_rcpp_osmdata_sf(SEXP);
extern SEXP osmdata_rcpp_osmdata_sp(SEXP);

static const R_CallMethodDef CallEntries[] = {
    {"osmdata_rcpp_osmdata_sf", (DL_FUNC) &osmdata_rcpp_osmdata_sf, 1},
    {"osmdata_rcpp_osmdata_sp", (DL_FUNC) &osmdata_rcpp_osmdata_sp, 1},
    {NULL, NULL, 0}
};

void R_init_osmdata(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
