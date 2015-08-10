# find all the nodes and store them in a data frame
process_osm_nodes <- function(doc) {

  bind_rows(pblapply(xml_attrs(xml_find_all(doc, "//node")), function(x) {

    # easy to make the lon/lat entries
    pts <- data_frame(id=x["id"], lon=as.numeric(x["lon"]), lat=as.numeric(x["lat"]))

    # find any tags and make them columns. bind_rows will be nice and fill in NAs
    tag_path <- sprintf("//node[@id='%s']/tag", x["id"])

    if (has_xpath(doc, tag_path)) {
      v <- xml_attr(xml_find_all(doc, tag_path), "v")
      names(v) <- xml_attr(xml_find_all(doc, tag_path), "k")
      pts <- cbind.data.frame(pts, t(v), stringsAsFactors=FALSE)
    }

    pts

  }))

}

# take a data frame of osm nodes and return a SpatialPointsDataFrame
osm_nodes_to_sptsdf <- function(osm_nodes) {
  df <- data.frame(filter(osm_nodes, -lon, -lat))
  spdf <- SpatialPointsDataFrame(as.matrix(osm_nodes[, c("lon", "lat")]), df)
  class(spdf) <- c("overnode", class(spdf))
  spdf
}
