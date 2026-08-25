# nocov start
.onLoad <- function (libname, pkgname) { # nolint

    op <- options ()

    ## Added and edited code here by JimShady to use random API each time.
    available_apis <- list_overpass_urls ()

    base_url <- sample (available_apis, 1)

    if (interactive ()) {
        statuses <- lapply (available_apis, check_status)
        ok <- vapply (
            statuses,
            function (s) isTRUE (s$status == 200L),
            logical (1)
        )
        if (any (ok)) {
            base_url <- sample (available_apis [ok], 1)
        }
    }

    op.osmdata <- list (osmdata.base_url = base_url)

    ## End of code edited by JimShady

    toset <- !(names (op.osmdata) %in% names (op))
    if (any (toset)) {
        options (op.osmdata [toset])
    }
    invisible ()
}
# nocov end

.onAttach <- function (libname, pkgname) { # nolint
    msg <- paste0 (
        "Data (c) OpenStreetMap contributors,",
        " ODbL 1.0. https://www.openstreetmap.org/copyright"
    )
    packageStartupMessage (msg)
}

#' list_overpass_urls
#'
#' List public Overpass API URLs. These are mirrors sampled by default
#' when the package loads.
#'
#' For further details, see
#' <https://wiki.openstreetmap.org/wiki/Overpass_API#Public_Overpass_API_instances>
#' and <https://github.com/ropensci/osmdata/pull/149>.
#'
#' @return A character vector of Overpass API interpreter URLs.
#'
#' @seealso [get_overpass_url()], [set_overpass_url()]
#'
#' @family overpass
#' @examples
#' list_overpass_urls ()
#' @export
list_overpass_urls <- function () {
    c (
        "https://overpass-api.de/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    )
}

#' get_overpass_url
#'
#' Return the URL of the specified overpass API. Default is
#' `https://overpass-api.de/api/interpreter/`.
#'
#' @return The overpass API URL
#'
#' @seealso [set_overpass_url()], [list_overpass_urls()]
#'
#' @family overpass
#' @examples
#' get_overpass_url ()
#' @export
get_overpass_url <- function () {

    op <- options ()
    if (!"osmdata.base_url" %in% names (op)) {
        stop ("overpass can not be retrieved")
    } # nocov
    options ()$osmdata.base_url
}

# nocov start

#' set_overpass_url
#'
#' Set the URL of the specified overpass API. Possible APIs with global
#' coverage are returned by [list_overpass_urls()].
#'
#' For further details, see
#' <https://wiki.openstreetmap.org/wiki/Overpass_API>
#'
#' @param overpass_url The desired overpass API URL
#'
#' @return The overpass API URL
#'
#' @seealso [get_overpass_url()], [list_overpass_urls()]
#'
#' @family overpass
#' @examples
#' \dontrun{
#' set_overpass_url (list_overpass_urls () [1])
#' }
#' @export
set_overpass_url <- function (overpass_url) {

    # check URL first
    if (!grepl ("interpreter", overpass_url)) {
        stop ("overpass_url not valid - must end with /interpreter")
    }

    old_url <- get_overpass_url ()
    op <- options () # nolint
    op.osmdata <- list (osmdata.base_url = overpass_url) # nolint
    options (op.osmdata)

    st <- overpass_status (quiet = TRUE)
    if (!"available" %in% names (st)) {
        set_overpass_url (old_url)
        stop ("overpass_url not valid")
    }

    invisible ()
}
# nocov end
