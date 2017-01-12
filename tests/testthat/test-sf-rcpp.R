context ("sf-rcpp")

test_that ("sf-rcpp-points", {
               x <- rcpp_test_points ()
               y <- sf::st_sfc (a=sf::st_point (c(1.0,2.0)), b=sf::st_point (c(3.0,4.0)))
               expect_identical (x, y)
})

