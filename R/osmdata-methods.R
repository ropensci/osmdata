#' @export
print.osmdata <- function (x, ...)
{
    msg <- NULL
    # print meta-data
    if (!all (vapply (x, is.null, FUN.VALUE = logical (1))))
        msg <- "Object of class 'osmdata' with:\n"

    msg <- c (msg, c (rep (' ', 17), '$bbox : ', x$bbox, '\n'))

    objs <- c ("overpass_call", "meta")
    prnts <- c ("The call submitted to the overpass API",
                "metadata including timestamp and version numbers")
    for (i in seq (objs))
        if (!is.null (x [objs [i]]))
        {
            nm <- c (rep (" ", 21 - nchar (objs [i])), "$", objs [i])
            msg <- c (msg, nm, ' : ', prnts [i], '\n')
        }

    # print geometry data
    indx <- which (grepl ("osm", names (x)))

    sf <- any (grep ("sf", lapply (x, class)))
    if (sf)
    {
        for (i in names (x) [indx])
        {
            xi <- x [[i]]
            nm <- c (rep (" ", 21 - nchar (i)), "$", i)
            if (is.null (xi))
                msg <- c (msg, nm, ' : NULL\n')
            else if (grepl ("line", i)) # sf "lines" -> "linestrings"
                msg <- c (msg, nm,
                               " : 'sf' Simple Features Collection with ",
                               nrow (xi), ' ', strsplit (i, 'osm_')[[1]][2],
                               'trings\n')
            else
                msg <- c (msg, nm, " : 'sf' Simple Features Collection with ",
                               nrow (xi), ' ',
                               strsplit (i, 'osm_')[[1]][2], '\n')
        }
    } else
    {
        for (i in names (x) [indx])
        {
            xi <- x [[i]]
            nm <- c (rep (" ", 21 - nchar (i)), "$", i)
            if (is.null (xi))
                msg <- c (msg, nm, ' : NULL', '\n')
            else
            {
                type <- strsplit (i, 'osm_') [[1]] [2]
                types <- c ('points', 'lines', 'polygons',
                            'multlines', 'multipolygons')
                sp_types <- c ('Points', 'Lines', 'Polygons',
                               'Lines', 'Polygons')
                types <- sp_types [match (type, types)]
                msg <- c (msg, nm, " : 'sp' Spatial", types, 'DataFrame with ',
                               nrow (xi), ' ', strsplit (i, 'osm_')[[1]][2],
                               '\n')
            }
        }
    }

    message (msg)
    #invisible (x)
}

#' @export
c.osmdata <- function (...)
{
    x <- list (...)
    cl_null <- vapply (x, function (i)
                       is.null (i$osm_points) &
                           is.null (i$osm_lines) &
                           is.null (i$osm_polygons) &
                           is.null (i$osm_multilines) &
                           is.null (i$osm_multipolygons),
                       FUN.VALUE = logical (1))
    x <- x [which (!cl_null)]
    if (length (x) < 1)
        stop ("osmdata object is entirely NULL")
    cl_sf <- vapply (x, function (i)
                     any (grep ('sf', lapply (i, class))),
                     FUN.VALUE = logical (1))
    if (!(all (cl_sf) | all (!cl_sf)))
        stop ('All objects must be either osmdata_sf or osmdata_sp')

    sf <- all (cl_sf)
    res <- osmdata ()
    res$bbox <- x [[1]]$bbox
    res$overpass_call <- x [[1]]$overpass_call
    res$meta <- x [[1]]$meta

    if (sf)
    {
        osm_names <- names (x [[1]]) [which (grepl ('osm_', names (x [[1]])))]
        core_names <- c ('osm_id', 'name', 'geometry')
        for (i in osm_names)
        {
            xi <- lapply (x, function (j) j [[i]])
            nrows <- lapply (xi, function (j) ifelse (is.null (j), 0, nrow (j)))
            indx <- which (unlist (nrows) > 0)
            xi <- xi [indx]
            xi [vapply (xi, is.null, logical (1))] <- NULL
            if (length (xi) > 0)
            {
                ids <- cnames <- NULL
                for (j in xi)
                {
                    ids <- c (ids, rownames (j))
                    cnames <- c (cnames, colnames (j))
                }
                ids <- sort (unique (ids))
                cnames <- cnames [!cnames %in% core_names]
                cnames <- sort (unique (cnames))
                cnames <- c ('osm_id', 'name', cnames, 'geometry')
                resi <- xi [[1]]
                # then expand resi to final number of columns keeping sf
                # integrity
                cnames_new <- cnames [which (!cnames %in% names (resi))]
                for (j in cnames_new)
                    resi [j] <- rep (NA, nrow (resi))
                # and re-order columns again
                indx1 <- which (names (resi) %in% core_names)
                indx2 <- which (!seq (ncol (resi)) %in% indx1)
                indx <- c (which (names (resi) == 'osm_id'),
                           which (names (resi) == 'name'),
                           indx2 [order (names (resi) [indx2])],
                           which (names (resi) == 'geometry'))
                att <- attributes (resi)
                resi <- resi [, indx, drop = FALSE]
                nms <- names (resi)
                attributes (resi) <- att # restored sf_column and agr attributes
                names (resi) <- nms
                # Then we're finally ready to pack in the remaining bits
                xi [[1]] <- NULL
                for (j in xi)
                {
                    rindx <- which (!rownames (j) %in% rownames (resi))
                    # cindx <- which (names (j) %in% names (resi))
                    resj <- j [rindx, , drop = FALSE] #nolint
                    # then expand resj as for resi above
                    cnames_new <- cnames [which (!cnames %in% names (resj))]
                    for (k in cnames_new)
                        resj [k] <- rep (NA, nrow (resj))
                    indx1 <- which (names (resj) %in% core_names)
                    indx2 <- which (!seq (ncol (resj)) %in% indx1)
                    indx <- c (which (names (resj) == 'osm_id'),
                               which (names (resj) == 'name'),
                               indx2 [order (names (resj) [indx2])],
                               which (names (resj) == 'geometry'))
                    resj <- resj [, indx]
                    resi <- rbind (resi, resj)
                } # end for j in x
                res [[i]] <- resi
                attr (res [[i]], "sf_column") <- attr (resi, "sf_column")
                attr (res [[i]], "agr") <- attr (resi, "agr")
            } # end if length (xi) > 0
        } # end for i in osm_names
        class (res) <- c (class (res), "osmdata_sf")
    } else
    {
        # TODO: implement sp version
        stop ("'c' method currently implemented only for osmdata_sf. ",
              "You could use\n'osmdata_sf()', and convert with ",
              "'as(x,'Spatial')' from package 'sf'.")
    }
    return (res)
}
