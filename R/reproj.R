# sf::st_crs(4326)$proj4string
# testepsg -e "EPSG:4326"
# testepsg -e "EPSG:3857"

.sph_merc <- function() {
  ## https://github.com/ropensci/mapscanner/issues/33
  "+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null +wktext +no_defs"
}

.lonlat <- function() {
  "+proj=longlat +datum=WGS84 +no_defs"

}
