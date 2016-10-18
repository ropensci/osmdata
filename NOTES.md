## Ways

Via: https://wiki.openstreetmap.org/wiki/Overpass_turbo/Polygon_Features

### A way is considered a Polygon if

- it forms a closed loop
- and is not tagged area=no
- and at least one of the following conditions is true:
    - there is a building=* tag and its value is not building=no
    - there is a highway=* tag and its value is not highway=no and its value is either highway=services, highway=rest_area or highway=escape
    - there is a natural=* tag and its value is not natural=no and its value is neither natural=coastline, natural=cliff, natural=ridge, natural=arete nor natural=tree_row
    - there is a landuse=* tag and its value is not landuse=no
    - there is a waterway=* tag and its value is not waterway=no and its value is either waterway=riverbank, waterway=dock, waterway=boatyard or waterway=dam
    - there is a amenity=* tag and its value is not amenity=no
    - there is a leisure=* tag and its value is not leisure=no
    - there is a barrier=* tag and its value is not barrier=no and its value is either barrier=city_wall, barrier=ditch, barrier=hedge, barrier=retaining_wall, barrier=wall or barrier=spikes
    - there is a railway=* tag and its value is not railway=no and its value is either railway=station, railway=turntable, railway=roundhouse or railway=platform
    - there is a area=* tag
    - there is a boundary=* tag and its value is not boundary=no
    - there is a man_made=* tag and its value is not man_made=no and its value is neither man_made=cutline, man_made=embankment nor man_made=pipeline
    - there is a power=* tag and its value is not power=no and its value is either power=plant, power=substation, power=generator or power=transformer
    - there is a place=* tag and its value is not place=no
    - there is a shop=* tag and its value is not shop=no
    - there is a aeroway=* tag and its value is not aeroway=no and its value is not aeroway=taxiway
    - there is a tourism=* tag and its value is not tourism=no
    - there is a historic=* tag and its value is not historic=no
    - there is a public_transport=* tag and its value is not public_transport=no
    - there is a office=* tag and its value is not office=no
    - there is a building:part=* tag and its value is not building:part=no
    - there is a ruins=* tag and its value is not ruins=no
    - there is a area:highway=* tag and its value is not area:highway=no
    - there is a craft=* tag and its value is not craft=no
    - there is a golf=* tag and its value is not golf=no


-------

## Relations

https://wiki.openstreetmap.org/wiki/Relation:boundary
