.onLoad <- function (libname, pkgname)
{
    op <- options ()
    op.osmdata <- list (osmdata.base_url =
                        'http://overpass-api.de/api/interpreter')
    toset <- !(names (op.osmdata) %in% names (op))
    if (any (toset))
        options (op.osmdata [toset])
    invisible ()
}

.onAttach <- function(libname, pkgname) {
    msg <- paste0 ("Data (c) OpenStreetMap contributors,",
                   " ODbL 1.0. http://www.openstreetmap.org/copyright")
    packageStartupMessage (msg)
}

#' get_overpass_url
#'
#' Return the URL of the specified overpass API. Default is
#' \url{http://overpass-api.de/api/interpreter}.
#'
#' @return The overpass API URL
#'
#' @seealso \code{\link{set_overpass_url}}
#'
#' @export
get_overpass_url <- function ()
{
    op <- options ()
    if (!'osmdata.base_url' %in% names (op))
        stop ('overpass can not be retrieved')
    options ()$osmdata.base_url
}

#' set_overpass_url
#'
#' Set the URL of the specified overpass API. Possible APIs with global coverage
#' are:
#' \itemize{
#' \item 'http://overpass-api.de/api/interpreter' (default)
#' \item 'http://overpass.osm.rambler.ru/cgi/interpreter'
#' \item 'http://api.openstreetmap.fr/oapi/interpreter'
#' \item 'https://overpass.osm.vi-di.fr/api/interpreter'
#' }
#' Additional APIs with limited local coverage include:
#' \itemize{
#' \item 'http://overpass.osm.ch/api/interpreter' (Switzerland)
#' \item 'http://overpass.openstreetmap.ie/api/interpreter' (Ireland)
#' }
#'
#' For further details, see
#' \url{http://wiki.openstreetmap.org/wiki/Overpass_API}
#'
#' @param overpass_url The desired overpass API URL
#'
#' @return The overpass API URL
#'
#' @seealso \code{\link{get_overpass_url}}
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
