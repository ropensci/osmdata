#' get_xml2_doc
#'
#' Adapted from 'https://github.com/hrbrmstr/overpass/' to extract an overpass
#' API query using 'xml2'.  Only implemented here for highways.
#'
#' @param bbox the bounding box within which highways should be downloaded.  A
#' 2-by-2 matrix of 4 elements with columns of min and max values, and rows of x
#' and y values.
#'
#' @return An xml2 'xml_document'
#' @export

get_xml2_doc <- function (bbox=NULL)
{
    stopifnot (is.numeric (bbox))
    stopifnot (length (bbox) == 4)
    bbox <- paste0 ('(', bbox [2,1], ',', bbox [1,1], ',',
                    bbox [2,2], ',', bbox [1,2], ')')

    key <- "['highway']"
    query <- paste0 ('(node', key, bbox,
                    ';way', key, bbox,
                    ';rel', key, bbox, ';')
    url_base <- 'http://overpass-api.de/api/interpreter'
    query <- paste0 ('?data=', query, ');(._;>;);out;')

    # from hrbrmstr/overpass/overpass_query.r
    res <- httr::POST (url_base, body=query)
    httr::stop_for_status (res) 
    xml2::read_xml (httr::content (res, as='text'))
}

#' process_xml2_doc
#'
#' Implements code from 'https://github.com/hrbrmstr/overpass/' to extract
#' highways from an XML doc extracted with 'get_xml_doc'
#'
#' @param doc An XML document extracted with 'get_xml_doc'
#'
#' @return A SpatialLinesDataFrame
#' @export
#' 
#' @examples
#' bbox <- matrix (c (-0.13, 51.5, -0.11, 51.52), nrow=2, ncol=2)
#' doc <- get_xml2_doc (bbox=bbox)
#' obj <- process_xml2_doc (doc)

process_xml2_doc <- function (doc)
{
    osm_nodes <- process_osm_nodes(doc)
    osm_ways <- process_osm_ways(doc, osm_nodes)
    osm_ways_to_spldf(doc, osm_ways)
}

# These lines are from 'overpass/node_utils.r'
process_osm_nodes <- function(doc) {
    # efficiently find all node attributes (lat/lon)
    # and get them into a data frame
    tmp <- xml2::xml_attrs(xml2::xml_find_all(doc, "//node"))
    nodes <- as.data.frame(t(do.call(cbind, tmp)), stringsAsFactors=FALSE)
    nodes <- nodes[, c("id", "lon", "lat")]

    # find all the nodes with tags
    nodes_with_tags <- tryCatch(xml2::xml_find_all(doc, "//node[child::tag]"),
                                errror=function(err){
                                    return(list(0))
                                })

    # if there are any, add the tag key/value to make a wide data frame
    if (length(nodes_with_tags) > 0) {
        dplyr::bind_rows(lapply(nodes_with_tags, function(x) {
                                v <- xml2::xml_attr(xml2::xml_find_all(x, "tag"), "v")
                                names(v) <- xml2::xml_attr(xml2::xml_find_all(x, "tag"), "k")
                                pts <- cbind.data.frame(id=xml2::xml_attr(x, "id"),
                                                        t(v), stringsAsFactors=FALSE)
                         })) -> node_attrs
        nodes <- dplyr::left_join(nodes, node_attrs, by="id")
    }

    # need numeric lon/lat
    dplyr::mutate(nodes, lon=as.numeric(lon), lat=as.numeric(lat))
}

# These lines are from 'hrbrmstr/overpass/way_utils.r'
process_osm_ways <- function(doc, osm_nodes) {
    # get all the way ids
    ways <- xml2::xml_find_all(doc, "//way")
    way_ids <- xml2::xml_attr(ways, "id")

    # see if any are duplicated (they shouldn't be but it happens)
    idxs <- which(!duplicated(way_ids))
    dup <- way_ids[which(duplicated(way_ids))]

    # setup the way->node query
    if (length(dup) > 0) 
        ways_not_nd <- sprintf("//way[%s]/nd",
                               paste0(sprintf("@id != %s", dup), collapse=" and "))
    else 
        ways_not_nd <- "//way/nd"

    # get all the nodes for the ways. this is a list of
    # named vectors
    tmp <- lapply(xml2::xml_find_all(doc, ways_not_nd), function(x) 
                  c(way_id=xml2::xml_attr(xml2::xml_find_one(x, ".."), "id"),
                    id=xml2::xml_attr(x, "ref"))  )
    # we can quickly and memory efficiently turn that into a matrix
    # then data frame, then merge in the coordinates
    filtered_ways <- as.data.frame(t(do.call(cbind, tmp)),
                                   stringsAsFactors=FALSE)
    filtered_ways <- dplyr::left_join(filtered_ways, 
                                      dplyr::select(osm_nodes, id, lon, lat), by="id")

    # for the 'do' below. this just keeps the code neater
    make_lines <- function(grp) 
        sp::Lines(list(sp::Line(as.matrix(grp[, c("lon", "lat")]))),
                  ID=unique(grp$way_id))
    # makes Lines, grouping by way id
    osm_ways <- dplyr::do(dplyr::group_by(filtered_ways, way_id),
                          lines=make_lines(.))$lines
    names(osm_ways) <- dplyr::distinct(filtered_ways, way_id)$way_id

    osm_ways
}

# Also from 'hrbrmstr/overpass/way_utils.r'
osm_ways_to_spldf <- function(doc, osm_ways) {
    # see process_osm_ways() for most of the logic
    ways <- xml2::xml_find_all(doc, "//way")
    way_ids <- xml2::xml_attr(ways, "id")

    idxs <- which(!duplicated(way_ids))
    dup <- way_ids[which(duplicated(way_ids))]

    if (length(dup) > 0) 
        ways_not_tag <- sprintf("//way[%s]/tag",
                                paste0(sprintf("@id != %s", dup), collapse=" and "))
    else 
        ways_not_tag <- sprintf("//way/tag")

    tmp <- lapply(xml2::xml_find_all(doc, ways_not_tag), function(x) 
                  c(way_id=xml2::xml_attr(xml2::xml_find_one(x, ".."), "id"),
                    k=xml2::xml_attr(x, "k"),
                    v=xml2::xml_attr(x, "v")))
    kvs <- as.data.frame(t(do.call(cbind, tmp)), stringsAsFactors=FALSE)

    # some ways may not have had tags, but we need the data.frame to
    # be complete, so we have to merge what we did find with all of
    # the ways to be safe
    ways_dat <- data.frame(dplyr::left_join(dplyr::data_frame(way_id=names(osm_ways)),
                                            tidyr::spread(kvs, k, v), by="way_id"),
                           stringsAsFactors=FALSE)
    rownames(ways_dat) <- ways_dat$way_id

    sldf <- sp::SpatialLinesDataFrame(sp::SpatialLines(osm_ways),
                                      data.frame(ways_dat))
    sldf
}
