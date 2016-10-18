context("nodes work")
test_that("nodes work", {
  only_nodes <- system.file("osm/only-nodes.osm", package="overpass")
  expect_that(read_osm(only_nodes), is_a("SpatialPointsDataFrame"))
})

context("nodes & ways work")
test_that("nodes & ways work", {
  nodes_and_ways <- system.file("osm/nodes-and-ways.osm", package="overpass")
  expect_that(read_osm(nodes_and_ways), is_a("SpatialLinesDataFrame"))
})

context("xml nodes & ways work")
test_that("xml nodes & ways work", {
  nodes_and_ways <- system.file("osm/actual-ways.osm", package="overpass")
  expect_that(read_osm(nodes_and_ways), is_a("SpatialLinesDataFrame"))
})

context("duplicates (and large XML return) are handled")
test_that("duplicates are handled", {
  mammoth <- system.file("osm/mammoth.osm", package="overpass")
  expect_that(read_osm(mammoth), is_a("SpatialLinesDataFrame"))
})
