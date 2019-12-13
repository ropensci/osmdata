# nocov start
.onLoad <- function (libname, pkgname)
{
    op <- options ()
	
    ## https://wiki.openstreetmap.org/wiki/Overpass_API#Public_Overpass_API_instances
    ## see https://github.com/ropensci/osmdata/pull/149
    ## Added and edited code here by JimShady to use random API each time.
	available_apis <- c('https://overpass-api.de/api/interpreter',
						'https://overpass.kumi.systems/api/interpreter')
	
    op.osmdata <- list (osmdata.base_url =
                        sample(available_apis, 1))
	
	## End of code edited by JimShady
	
    toset <- !(names (op.osmdata) %in% names (op))
    if (any (toset))
        options (op.osmdata [toset])
    invisible ()
}
# nocov end

.onAttach <- function(libname, pkgname) {
    msg <- paste0 ("Data (c) OpenStreetMap contributors,",
                   " ODbL 1.0. https://www.openstreetmap.org/copyright")
    packageStartupMessage (msg)
}

#' get_overpass_url
#'
#' Return the URL of the specified overpass API. Default is
#' <https://overpass-api.de/api/interpreter>.
#'
#' @return The overpass API URL
#'
#' @seealso [set_overpass_url()]
#'
#' @export
get_overpass_url <- function ()
{
    op <- options ()
    if (!'osmdata.base_url' %in% names (op))
        stop ('overpass can not be retrieved') # nocov
    options ()$osmdata.base_url
}

# nocov start

#' set_overpass_url
#'
#' Set the URL of the specified overpass API. Possible APIs with global coverage
#' are:
#' \itemize{
#' \item 'https://overpass-api.de/api/interpreter' (default)
#' \item 'https://overpass.kumi.systems/api/interpreter'
#' \item 'https://overpass.osm.rambler.ru/cgi/interpreter'
#' \item 'https://api.openstreetmap.fr/oapi/interpreter'
#' \item 'https://overpass.osm.vi-di.fr/api/interpreter'
#' }
#' Additional APIs with limited local coverage include:
#' \itemize{
#' \item 'https://overpass.osm.ch/api/interpreter' (Switzerland)
#' \item 'https://overpass.openstreetmap.ie/api/interpreter' (Ireland)
#' }
#'
#' For further details, see
#' <https://wiki.openstreetmap.org/wiki/Overpass_API>
#'
#' @param overpass_url The desired overpass API URL
#'
#' @return The overpass API URL
#'
#' @seealso [get_overpass_url()]
#'
#' @export
set_overpass_url <- function (overpass_url)
{
    # check URL first
    if (!grepl ('interpreter', overpass_url))
        stop ('overpass_url not valid - must end with /interpreter')

    old_url <- get_overpass_url ()
    op <- options () #nolint
    op.osmdata <- list (osmdata.base_url = overpass_url)
    options (op.osmdata)

    st <- overpass_status (quiet = TRUE)
    if (!'available' %in% names (st))
    {
        set_overpass_url (old_url)
        stop ('overpass_url not valid')
    }

    invisible ()
}
# nocov end
