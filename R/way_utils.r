process_osm_ways <- function(doc, osm_nodes) {
  pblapply(xml_find_all(doc, "//way"), function(x) {
    way_id <- xml_attr(x, "id")
    nds_df <- filter(osm_nodes, id %fmin% xml_attr(xml_find_all(x, "./nd"), "ref"))
    Lines(list(Line(as.matrix(nds_df[, c("lon", "lat")]))), ID=way_id)
  }) -> osm_ways
  names(osm_ways) <- xml_attr(xml_find_all(doc, "//way"), "id")
  osm_ways
}

osm_ways_to_spldf <- function(doc, osm_ways) {

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

  SpatialLinesDataFrame(SpatialLines(osm_ways), data.frame(ways_dat))

}


#
# if (has_ways) {
#
#   pblapply(xml_find_all(doc, "//way"), function(x) {
#
#     way_id <- xml_attr(x, "id")
#     nds_df <- filter(osm_nodes, id %fmin% xml_attr(xml_find_all(x, "./nd"), "ref"))
#     Lines(list(Line(as.matrix(nds_df[, c("lon", "lat")]))), ID=way_id)
#
#   }) -> osm_ways
#   names(osm_ways) <- xml_attr(xml_find_all(doc, "//way"), "id")
#
#   bind_rows(pblapply(xml_find_all(doc, "//way"), function(x) {
#     tag_path <- sprintf("//way[@id='%s']/tag", xml_attr(x, "id"))
#     if (has_xpath(doc, tag_path)) {
#       v <- xml_attr(xml_find_all(doc, tag_path), "v")
#       names(v) <- xml_attr(xml_find_all(doc, tag_path), "k")
#       cbind.data.frame(id=xml_attr(x, "id"), t(v), stringsAsFactors=FALSE)
#     } else {
#       data.frame(id=xml_attr(x, "id"), stringsAsFactors=FALSE)
#     }
#   })) -> ways_dat
#   rownames(ways_dat) <- names(osm_ways)
#
#   SpatialLinesDataFrame(SpatialLines(osm_ways), data.frame(ways_dat)) -> osm_ways
#
# }
