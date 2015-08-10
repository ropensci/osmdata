# handles making of a Lines list from the way elements
# NOTE: ways can be polygons; need to figure that out
process_osm_ways <- function(doc, osm_nodes) {

  # for each way
  #   - connect all the nodes
  #   - ensure the way id is in the rowname since that's how Spatial* stuff
  #     works best in R

  pblapply(xml_find_all(doc, "//way"), function(x) {
    way_id <- xml_attr(x, "id")

    # initially tried this
    nds <- data_frame(id=xml_attr(xml_find_all(x, "./nd"), "ref"))
    # convert to lat/lon
    nds_df <- left_join(nds, osm_nodes, by="id")
    #     nds_df <- filter(osm_nodes, id %fmin% xml_attr(xml_find_all(x, "./nd"), "ref")),
    Lines(list(Line(as.matrix(nds_df[, c("lon", "lat")]))), ID=way_id)
  }) -> osm_ways
  names(osm_ways) <- xml_attr(xml_find_all(doc, "//way"), "id")
  osm_ways
}

# make a SpatialLinesDataFrame from the ways
# NOTE: ways can be polygons; need to figure that out
osm_ways_to_spldf <- function(doc, osm_ways) {

  # for each way:
  #   - grab any tags to use in @data
  #   - ensure @data at least has an id column data frame

  bind_rows(pblapply(xml_find_all(doc, "//way"), function(x) {
    tag_path <- sprintf("//way[@id='%s']/tag", xml_attr(x, "id"))
    if (has_xpath(doc, tag_path)) {
      v <- xml_attr(xml_find_all(doc, tag_path), "v")
      names(v) <- xml_attr(xml_find_all(doc, tag_path), "k")
      cbind.data.frame(id=xml_attr(x, "id"), t(v), stringsAsFactors=FALSE)
    } else {
      data.frame(id=xml_attr(x, "id"), stringsAsFactors=FALSE)
    }
  })) -> ways_dat
  rownames(ways_dat) <- names(osm_ways)

  sldf <- SpatialLinesDataFrame(SpatialLines(osm_ways), data.frame(ways_dat))
  sldf

}
