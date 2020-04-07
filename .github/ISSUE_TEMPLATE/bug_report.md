---
name: Bug report
about: Create a report to help us improve
title: ''
labels: ''
assignees: ''

---

**Steps to follow in reporting a bug with `osmdata`**

Please follow all of the following steps, and only submit once you've checked all boxes (where appropriate).

- [ ] Download data locally via `osmdata_xml(q, filename = "myfile.xml")` (where `q` is your query)
- [ ] Use the [`reprex` package](https://reprex.tidyverse.org/) to reproduce your bug, including a `setwd()` command at the start to ensure you are in the directory where you've downloaded your data
- [ ] Include comparison with equivalent results from the `sf` package using the code shown below
- [ ] Paste the result in the indicated section below
- [ ] Delete the `setwd()` line from the pasted result
- [ ] Include the output of both `packageVersion("osmdata")` and `R.Version()$version.string`
- [ ] Alternatively, include the full output of `sessionInfo()`


### Paste `reprex` output here

Please include the following lines:
``` r
# <your reprex code here>

library(sf)
st_layers("myfile.xml") # give information on available layers
st_read("myfile.xml", layer = <desired_layer>)

packageVersion("osmdata")
R.Version()$version.string
#sessionInfo()
```



***If you are constructing or using a specialized `overpass` query***

- [ ] I have tried my query on [overpass-turbo.eu](https://overpass-turbo.eu), and it works
- [ ] I confirm that the data returned on [overpass-turbo.eu](https://overpass-turbo.eu) are identical to those returned from the equivalent call to `osmdata_xml(q, filename = "myfile.xml`)`.

Thanks! :smile:
