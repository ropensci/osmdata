# handles making of a Lines list from the way elements
# NOTE: ways can be polygons; need to figure that out
process_osm_ways <- function(doc, osm_nodes) {

  ways <- xml_find_all(doc, "//way")
  way_ids <- xml_attr(ways, "id")

  idxs <- which(!duplicated(way_ids))
  dup <- way_ids[which(duplicated(way_ids))]

  if (length(dup) > 0) {
    ways_not_nd <- sprintf("//way[%s]/nd",
                           paste0(sprintf("@id != %s", dup), collapse=" and "))
  } else {
    ways_not_nd <- "//way/nd"
  }

  tmp <- pblapply(xml_find_all(doc, ways_not_nd), function(x) {
    c(way_id=xml_attr(xml_find_one(x, ".."), "id"),
      id=xml_attr(x, "ref"))
  })
  filtered_ways <- as.data.frame(t(do.call(cbind, tmp)), stringsAsFactors=FALSE)
  filtered_ways <- left_join(filtered_ways, select(osm_nodes, id, lon, lat), by="id")

  make_lines <- function(grp) {
    Lines(list(Line(as.matrix(grp[, c("lon", "lat")]))), ID=unique(grp$way_id))
  }

  osm_ways <- do(group_by(filtered_ways, way_id), lines=make_lines(.))$lines
  names(osm_ways) <- distinct(filtered_ways, way_id)$way_id

  osm_ways

}

# make a SpatialLinesDataFrame from the ways
# NOTE: ways can be polygons; need to figure that out
osm_ways_to_spldf <- function(doc, osm_ways) {

  ways <- xml_find_all(doc, "//way")
  way_ids <- xml_attr(ways, "id")

  idxs <- which(!duplicated(way_ids))
  dup <- way_ids[which(duplicated(way_ids))]

  if (length(dup) > 0) {
    ways_not_tag <- sprintf("//way[%s]/tag",
                            paste0(sprintf("@id != %s", dup), collapse=" and "))
  } else {
    ways_not_tag <- sprintf("//way/tag")
  }

  tmp <- pblapply(xml_find_all(doc, ways_not_tag), function(x) {
    c(way_id=xml_attr(xml_find_one(x, ".."), "id"),
      k=xml_attr(x, "k"),
      v=xml_attr(x, "v"))
  })
  kvs <- as.data.frame(t(do.call(cbind, tmp)), stringsAsFactors=FALSE)

  ways_dat <- data.frame(left_join(data_frame(way_id=names(osm_ways)),
                                   spread(kvs, k, v), by="way_id"),
                         stringsAsFactors=FALSE)
  rownames(ways_dat) <- ways_dat$way_id

  sldf <- SpatialLinesDataFrame(SpatialLines(osm_ways), data.frame(ways_dat))
  sldf

}
