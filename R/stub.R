# Only used for test/testthat
# https://github.com/n-s-f/mockery/blob/master/R/stub.R
# COPYRIGHT HOLDER: Noam Finkelstein, Lukasz Bartnik

#' Replace a function with a stub.
#'
#' The result of calling \code{stub} is that, when \code{where}
#' is invoked and when it internally makes a call to \code{what},
#' \code{how} is going to be called instead.
#' 
#' This is much more limited in scope in comparison to
#' \code{\link[testthat]{with_mock}} which effectively replaces
#' \code{what} everywhere. In other words, when using \code{with_mock}
#' and regardless of the number of intermediate calls, \code{how} is
#' always called instead of \code{what}. However, using this API,
#' the replacement takes place only for a single function \code{where}
#' and only for calls originating in that function.
#' 
#' 
#' @name stub
#' @rdname stub
NULL

# \code{remote_stub} reverses the effect of \code{stub}.


#' @param where Function to be called that will in turn call
#'        \code{what}.
#' @param what Name of the function you want to stub out (a
#'        \code{character} string).
#' @param how Replacement function (also a \code{mock} function)
#'        or a return value for which a function will be created
#'        automatically.
#' 
#' @export
#' @rdname stub
#' 
#' @examples
#' f <- function() TRUE
#' g <- function() f()
#' stub(g, 'f', FALSE)
#' 
#' # now g() returns FALSE because f() has been stubbed out
#' g()
#' 
`stub` <- function (where, what, how)
{
    # `where` needs to be a function
    where_name <- deparse(substitute(where))
    stopifnot(is.function(where))
  
    # `what` needs to be a character value
    stopifnot(is.character(what), length(what) == 1)

    # this is where a stub is going to be assigned in
    env <- new.env(parent = environment(where))

    if (grepl('::', what)) {
        elements  <- strsplit(what, '::')
        what <- paste(elements[[1]][1], elements[[1]][2], sep='XXX')

        stub_list <- c(what)
        if ("stub_list" %in% names(attributes(get('::', env)))) {
            stub_list <- c(stub_list, attributes(get('::', env))[['stub_list']])
        }

        create_new_name <- create_create_new_name_function(stub_list, env)
        assign('::', create_new_name, env)
    }

    if (!is.function(how)) {
        assign(what, function(...) how, env)
    } else {
        assign(what, how, env)
    }

    environment(where) <- env
    assign(where_name, where, parent.frame())
}


create_create_new_name_function <- function(stub_list, env)
{
    create_new_name <- function(pkg, func)
    {
        pkg_name  <- deparse(substitute(pkg))
        func_name <- deparse(substitute(func))
        for(stub in stub_list) {
            if (paste(pkg_name, func_name, sep='XXX') == stub) {
                return(eval(parse(text = stub), env))
            }
        }
        return(eval(parse(text=paste(pkg_name, func_name, sep='::'))))
    }
    attributes(create_new_name) <- list(stub_list=stub_list)
    return(create_new_name)
}

