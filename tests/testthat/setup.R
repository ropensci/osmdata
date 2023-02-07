library(httptest2)

set_overpass_url ("https://overpass-api.de/api/interpreter")

test_all <- Sys.getenv ("GITHUB_WORKFLOW") != "R-CMD-check"
