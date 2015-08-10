process_osm_nodes <- function(doc) {

  bind_rows(pblapply(xml_attrs(xml_find_all(doc, "//node")), function(x) {

    pts <- data_frame(id=x["id"], lon=as.numeric(x["lon"]), lat=as.numeric(x["lat"]))

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

  SpatialPointsDataFrame(as.matrix(osm_nodes[, c("lon", "lat")]), df)

}
