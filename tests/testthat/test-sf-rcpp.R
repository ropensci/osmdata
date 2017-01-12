context ("sf-rcpp")

test_that ("sf-rcpp-points", {
               x <- rcpp_test_points ()
               y <- sf::st_sfc (a=sf::st_point (c(1.0,2.0)), b=sf::st_point (c(3.0,4.0)))
               expect_identical (x, y)
})

test_that ("sf-rcpp-lines", {
               x <- rcpp_test_lines ()
               l1 <- sf::st_linestring (cbind (c(1.0,2.0,3.0,4.0), c(5.0,6.0,7.0,8.0)))
               l2 <- sf::st_linestring (cbind (c(11.0,12.0,13.0), c(14.0,15.0,16.0)))
               y <- sf::st_sfc (a=l1, b=l2)
               expect_identical (x, y)
})

test_that ("sf-rcpp-polygons", {
               x <- rcpp_test_polygons ()
               l1 <- cbind (c(1.0,2.0,3.0,4.0,1.0), c(5.0,6.0,7.0,8.0,5.0))
               l2 <- cbind (c(11.0,12.0,13.0,11.0), c(14.0,15.0,16.0,14.0))
               l1 <- sf::st_multipolygon (list (list (l1)))
               l2 <- sf::st_multipolygon (list (list (l2)))
               y <- sf::st_sfc (a=l1, b=l2)
               expect_identical (x, y)
})
