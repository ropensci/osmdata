# find all the nodes and store them in a data frame
process_osm_nodes <- function(doc) {

  # efficiently find all node attributes (lat/lon)
  # and get them into a data frame
  tmp <- xml_attrs(xml_find_all(doc, "//node"))
  nodes <- as.data.frame(t(do.call(cbind, tmp)), stringsAsFactors=FALSE)
  nodes <- nodes[, c("id", "lon", "lat")]

  # find all the nodes with tags
  nodes_with_tags <- tryCatch(xml_find_all(doc, "//node[child::tag]"),
                              errror=function(err){ return(list(0)) })

  # if there are any, add the tag key/value to make a wide data frame
  if (length(nodes_with_tags) > 0) {
    bind_rows(lapply(nodes_with_tags, function(x) {
      v <- xml_attr(xml_find_all(x, "tag"), "v")
      names(v) <- xml_attr(xml_find_all(x, "tag"), "k")
      pts <- cbind.data.frame(id=xml_attr(x, "id"), t(v),
                              stringsAsFactors=FALSE)
    })) -> node_attrs
    nodes <- left_join(nodes, node_attrs, by="id")
  }

  # need numeric lon/lat
  mutate(nodes, lon=as.numeric(lon), lat=as.numeric(lat))

}

# take a data frame of osm nodes and return a SpatialPointsDataFrame
osm_nodes_to_sptsdf <- function(osm_nodes) {
  df <- data.frame(filter(osm_nodes, -lon, -lat))
  spdf <- SpatialPointsDataFrame(as.matrix(osm_nodes[, c("lon", "lat")]), df)
  spdf
}
