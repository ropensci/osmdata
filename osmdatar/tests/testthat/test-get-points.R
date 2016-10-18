context ('test-get_points-perf')

test_that ('get_points', {
  bbox <- matrix (c (-0.11, 51.51, -0.10, 51.52), nrow=2, ncol=2)
  print(system.time ( dat_H <- get_points (bbox=bbox, key='highway')))
  class(dat_H)
  print(system.time ( dat_HP <- get_points (bbox=bbox, key='highway', value='primary')))
  print(system.time ( dat_HNP <- get_points (bbox=bbox, key='highway', value='!primary')))
  print(length (dat_HP))
  print(length (dat_HNP))
  print(length (dat_H))
})

