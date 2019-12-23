-------------------------------------------------------------------------------
-- gauges, stations => tracts, zones
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- stations: buffered join
-- buffer stations, intersect tracts, find areas of intersection
-------------------------------------------------------------------------------

-- buffer stations by 3000ft
-- could make buffers a function of nearby stations:
-- 1) intersect buffers with station voronoi polys
-- 2) make buffer distance a function of number of nearby stations

-- tract
DROP TABLE IF EXISTS station_buffers;

-- beware literal edge cases => intersect buffers with union of tracts
CREATE TABLE station_buffers AS
WITH nyct_union AS (
    SELECT ST_Union(geom) AS geom
    FROM nyct2010
)
SELECT
    A.remote,
    ST_Intersection(ST_Transform(ST_Buffer(ST_Transform(A.geom, 6539), 3000), 4326), 
        B.geom) AS buffer
FROM remote_station A, nyct_union B;

-- make tract geometries distinct on tract
DROP TABLE IF EXISTS dtracts2010;
CREATE TABLE dtracts2010 AS
SELECT
    ct2010,
    ST_Union(geom) AS geom,
    1000 AS dummy_popn
FROM nyct2010
GROUP BY ct2010;

-- intersect station buffers with dtracts and get areas
DROP TABLE IF EXISTS station_to_tract_buff_3000;
CREATE TABLE station_to_tract_buff_3000 AS
SELECT
    A.remote,
    trunc(random() * 9000 + 1)::int as dummy_entries,
    B.ct2010,
    ST_Area(A.buffer) AS buffer_area,
    ST_Intersection(A.buffer, B.geom) AS inter,
    ST_Area(ST_Intersection(A.buffer, B.geom)) AS inter_area,
    ST_Area(B.geom) AS dtract_area,
    B.dummy_popn
FROM 
    station_buffers A,
    dtracts2010 B
WHERE ST_Intersects(A.buffer, B.geom);

-- get dummy entries by station, tract
ALTER TABLE station_to_tract_buff_3000 DROP COLUMN IF EXISTS tract_share;
ALTER TABLE station_to_tract_buff_3000 ADD tract_share numeric;

UPDATE station_to_tract_buff_3000 SET tract_share = inter_area / buffer_area;

-- check tract_share sums by station
-- TODO: figure out numerical precision issue, e.g., sums to 0.99999999999998805077
SELECT 
    remote,
    SUM(tract_share) AS sum_by_station
FROM station_to_tract_buff_3000
GROUP BY remote;


-- taxi zones
DROP TABLE IF EXISTS station_buffers;

-- beware literal edge cases => intersect buffers with union of tracts
CREATE TABLE station_buffers AS
WITH tz_union AS (
    SELECT ST_Union(geom) AS geom
    FROM taxi_zones
)
SELECT
    A.remote,
    ST_Intersection(ST_Transform(ST_Buffer(ST_Transform(A.geom, 6539), 5280), 4326), 
        B.geom) AS buffer
FROM station_latlong A, tz_union B;

-- make tz geometries distinct on tz
DROP TABLE IF EXISTS dtz;
CREATE TABLE dtz AS
SELECT
    gid,
    ST_Union(geom) AS geom,
    1000 AS dummy_popn
FROM taxi_zones
GROUP BY gid;

-- intersect station buffers with dtracts and get areas
DROP TABLE IF EXISTS station_to_tz_buff_5280;
CREATE TABLE station_to_tz_buff_5280 AS
SELECT
    A.remote,
    B.gid AS tz,
    ST_Area(A.buffer) AS buffer_area,
    ST_Area(ST_Intersection(A.buffer, B.geom)) AS inter_area,
    B.dummy_popn
FROM 
    station_buffers A,
    dtz B
WHERE ST_Intersects(A.buffer, B.geom)
ORDER BY A.remote;

-- get dummy entries by station, tract
ALTER TABLE station_to_tz_buff_5280 DROP COLUMN IF EXISTS tz_share;
ALTER TABLE station_to_tz_buff_5280 ADD tz_share numeric;

UPDATE station_to_tz_buff_5280 SET tz_share = inter_area / buffer_area;

-- check tract_share sums by station
-- TODO: figure out numerical precision issue, e.g., sums to 0.99999999999998805077
SELECT 
    remote,
    SUM(tz_share) AS sum_by_station
FROM station_to_tz_buff_5280
GROUP BY remote;
