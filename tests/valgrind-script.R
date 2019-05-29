library (osmdata)
q <- opq (c (76.4410201, 15.3158, 76.4810201, 15.3558))
x1 <- osmdata_sf (doc = "hampi.osm") %>%
    osm_poly2line ()
x2 <- osmdata_sc (q, doc = "hampi.osm")
