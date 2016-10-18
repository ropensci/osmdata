context ('test-get_polygons-perf')

test_that ('get_polygons', {
  bbox <- matrix (c (-0.10, 51.50, -0.08, 51.52), nrow=2, ncol=2)
  print(system.time ( dat_H <- get_polygons (bbox=bbox, key='highway')))
  class(dat_H)
  print(system.time ( dat_HP <- get_polygons (bbox=bbox, key='highway', value='primary')))
  print(system.time ( dat_HNP <- get_polygons (bbox=bbox, key='highway', value='!primary')))
  print(length (dat_HP))
  print(length (dat_HNP))
  print(length (dat_H))
})

