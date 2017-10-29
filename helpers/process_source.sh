#!/bin/bash

cd /usr/local/src/grb

# This script has been converted from the beta development site

# We need to keep track of the ogr2osm id as it allows us to incrementally process files instead of making a huge one while still keeping osm id unique across files
# default value is zero but the file does need to exists if you use the option
#echo "15715818" > ogr2osm.id
echo "Reset counter $file"
echo "0" > ogr2osm.id

# If you are low on diskspace, you can use fuse to mount the zips as device in user space
# fuse-zip -o ro ../php/files/GRBgis_40000.zip GRBgis_40000
# fusermount -u GRBgis_40000

#fuse-zip -o ro files/GRBgis_10000.zip GRBgis_10000
#fuse-zip -o ro files/GRBgis_20001.zip GRBgis_20001
#fuse-zip -o ro files/GRBgis_30000.zip GRBgis_30000
#fuse-zip -o ro files/GRBgis_40000.zip GRBgis_40000
#fuse-zip -o ro files/GRBgis_70000.zip GRBgis_70000
#fuse-zip -o ro files/GRBgis_04000.zip GRBgis_04000

# First we need all the source data, it's hard to download these automaticall from the source place, so where needed we will use some of our own storage to download the files to so we can curl them.

for file in WR/Wegenregister_SHAPE_20170921/Shapefile/Wegsegment.shp CRAB/Shapefile/*.shp 

do
 echo "Processing $file"
 dirname=$(dirname "$file")
 filename=$(basename "$file")
 extension="${filename##*.}"
 filename="${filename%.*}"
 entity=${filename:0:3} # Gba/Gbg

 echo $dirname
 echo "Cleanup parsed"
 echo "=============="
 rm -Rf "${filename}_parsed"
 echo "OGR FILE INFO"
 echo "============="
 /usr/local/bin/ogrinfo -al -so ${dirname}/${filename}.shp
 echo ""

 echo "OGR2OGR"
 echo "======="
 # https://confluence.qps.nl/pages/viewpage.action?pageId=29855173
 #echo /usr/local/bin/ogr2ogr -s_srs "EPSG:31370" -t_srs "EPSG:4326" "${filename}_parsed" ${dirname}/${filename}.shp -overwrite
 echo /usr/local/bin/ogr2ogr -s_srs "ESRI::${dirname}/${filename}.prj" -t_srs WGS84 "${filename}_parsed" ${dirname}/${filename}.shp -overwrite
 /usr/local/bin/ogr2ogr -s_srs "ESRI::${dirname}/${filename}.prj" -t_srs WGS84 "${filename}_parsed" ${dirname}/${filename}.shp -overwrite

 # /usr/local/bin/ogr2ogr -s_srs "EPSG:31370" -t_srs "EPSG:4326" "${filename}_parsed" ${dirname}/${filename}.shp -overwrite

 echo "\n"
 echo "OGR2OSM"
 echo "======="
 rm -f "${filename}.osm"
 echo /usr/local/bin/ogr2osm/ogr2osm.py --encoding=latin1 --idfile=ogr2osm.id --positive-id --saveid=ogr2osm.id "${filename}_parsed/${filename}.shp"
 /usr/local/bin/ogr2osm/ogr2osm.py --encoding=latin1 --idfile=ogr2osm.id --positive-id --saveid=ogr2osm.id "${filename}_parsed/${filename}.shp"
 echo ""

# echo "OSM convert as we seem to be missing version information after ogr2osm according to osmosis"
 echo "\n"
 echo "OSMCONVERT"
 echo "=========="
 echo "statistics:"
 /usr/bin/osmconvert ${filename}.osm --out-statistics
 echo "converting to compatible format for OSM:"
 /usr/bin/osmconvert ${filename}.osm --fake-author -o=${filename}_converted.osm
 echo ""
# --emulate-osmosis option ?
# --out-statistics
done

echo "OSMOSIS MERGE"
echo "============="

osmosis  \
--rx CrabAdr_converted.osm  \
--rx Wegsegment_converted.osm  \
--merge  \
--wx /datadisk2/out/all_merged.osm

# postgresql work

 echo ""
 echo "IMPORT the merged file:"
 echo "======================="

/usr/bin/osm2pgsql --slim --create --cache 4000 --number-processes 4 --hstore --prefix belgium_osm --style /usr/local/src/openstreetmap-carto/openstreetmap-carto.style --multi-geometry -d grb_api -U grb-data /datadisk2/out/all_merged.osm -H grb-db-0

echo "Creating additional indexes..."

#echo 'CREATE INDEX belgium_osm_source_index_p ON belgium_osm_polygon USING btree ("source:geometry:oidn" COLLATE pg_catalog."default");' | psql -U grb-data grb_api -h grb-db-0
#echo 'CREATE INDEX belgium_osm_source_ent_p ON belgium_osm_polygon USING btree ("source:geometry:entity" COLLATE pg_catalog."default");' | psql -U grb-data grb_api -h grb-db-0
#echo 'CREATE INDEX belgium_osm_source_index_o ON belgium_osm_point USING btree ("source:geometry:oidn" COLLATE pg_catalog."default");' | psql -U grb-data grb
#echo 'CREATE INDEX belgium_osm_source_index_n ON belgium_osm_nodes USING btree ("source:geometry:oidn" COLLATE pg_catalog."default");' | psql -U grb-data grb
#echo 'CREATE INDEX belgium_osm_source_index_l ON belgium_osm_line USING btree ("source:geometry:oidn" COLLATE pg_catalog."default");' | psql -U grb-data grb
#echo 'CREATE INDEX belgium_osm_source_index_r ON belgium_osm_rels USING btree ("source:geometry:oidn" COLLATE pg_catalog."default");' | psql -U grb-data grb
#echo 'CREATE INDEX belgium_osm_source_index_w ON belgium_osm_ways USING btree ("source:geometry:oidn" COLLATE pg_catalog."default");' | psql -U grb-data grb

# setup source tag for all objects imported
# echo "UPDATE belgium_osm_polygon SET "source" = 'GRB';" | psql -U grb-data grb_api -h grb-db-0
#echo "UPDATE belgium_osm_line SET "source" = 'GRB';" | psql -U grb-data grb_api -h grb-db-0

# more indexes
#echo 'CREATE INDEX belgium_osm_src_index_p ON belgium_osm_polygon USING btree ("source" COLLATE pg_catalog."default");' | psql -U grb-data grb_api -h grb-db-0

# use a query to update 'trap' as this word is a bit too generic and short to do with sed tricks
#echo "UPDATE belgium_osm_polygon set highway='steps', building='' where building='trap';" | psql -U grb-data grb_api -h grb-db-0


#cat > /tmp/create.indexes.sql << EOF
#CREATE INDEX idx_belgium_osm_line_nobridge ON belgium_osm_polygon USING gist (way) WHERE ((man_made <> ALL (ARRAY[''::text, '0'::text, 'no'::text])) OR man_made IS NOT NULL);
#CREATE INDEX idx_pop_mm_null ON belgium_osm_polygon USING gist (way) WHERE (man_made IS NOT NULL);
#CREATE INDEX idx_pop_no_bridge ON belgium_osm_polygon USING gist (way) WHERE (bridge <> ALL (ARRAY[''::text, '0'::text, 'no'::text]));
#CREATE INDEX idx_pop_hw_null ON belgium_osm_polygon USING gist (way) WHERE (highway IS NOT NULL);
#CREATE INDEX idx_pop_no_hw ON belgium_osm_polygon USING gist (way) WHERE (highway <> ALL (ARRAY[''::text, '0'::text, 'no'::text]));
#CREATE INDEX idx_pop_no_b ON belgium_osm_polygon USING gist (way) WHERE (building <> ALL (ARRAY[''::text, '0'::text, 'no'::text]));
#CREATE INDEX idx_pop_b_null ON belgium_osm_polygon USING gist (way) WHERE (building IS NOT NULL);
#EOF

# These are primarily if you hook up a bbox client script to it, not really interesting when all you want to do is export the built database to a file
#cat /tmp/create.indexes.sql | psql -U grb-data grb_api -h grb-db-0

# quick fix
cd ~

# address directly in the database using DBF database file, the tool will take care of all anomalities encountered (knw/Gbg)
#grb2osm/grb2osm.php -f /usr/local/src/grb/GRBgis_20001/Shapefile/TblGbgAdr20001B500.dbf,/usr/local/src/grb/GRBgis_10000/Shapefile/TblGbgAdr10000B500.dbf,/usr/local/src/grb/GRBgis_30000/Shapefile/TblGbgAdr30000B500.dbf,/usr/local/src/grb/GRBgis_40000/Shapefile/TblGbgAdr40000B500.dbf,/usr/local/src/grb/GRBgis_70000/Shapefile/TblGbgAdr70000B500.dbf,/usr/local/src/grb/GRBgis_30000/Shapefile/TblKnwAdr30000B500.dbf,/usr/local/src/grb/GRBgis_70000/Shapefile/TblKnwAdr70000B500.dbf,/usr/local/src/grb/GRBgis_20001/Shapefile/TblKnwAdr20001B500.dbf,/usr/local/src/grb/GRBgis_40000/Shapefile/TblKnwAdr40000B500.dbf

echo ""
echo "Flush cache"
echo "==========="
 # flush redis cache
echo "flushall" | redis-cli 

