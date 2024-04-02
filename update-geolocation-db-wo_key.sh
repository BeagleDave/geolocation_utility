#!/bin/sh
#
# update-geolocation-db.sh
#
# Author:	D.S. Crawford
# Date:		09 Feb 2015
#
# Purpose:	Update the local copy of the MaxMind geolocation
#		database with the most recent version 
#		(weekly updates on Tue)
#
# Change log:	26 Apr 2016 - add IPv6 support
#		26 May 2016 - changed MaxMind data service / add accuracy field in Blocks file
#		27 Sep 2016 - add binary database (.mmdb) refresh
#		06 Oct 2016 - add ISP database refresh
#		14 Oct 2016 - add MaxMind public data files
#		14 Jun 2017 - bug fix - hard code paths, remove test comments
#		09 May 2018 - error handling email address corrupted/failing. Changed gzip to --force, fixed mail addresses
#		22 Aug 2022 - WSL port
#
# Sac State MaxMind license: 	City, ISP databases
#				Sac State license_key=[redacted]
# 
# LICENSEKEY=[redacted]

# Uncomment the appropriate version: 
# 	- Licensed version: GeoIP2
#	- Free version: GeoLite2
# VERSION=Geolite2
VERSION=GeoIP2

cd $HOME/geolocation

echo "*** `date` ***"

# Download the weekly updated geolocation file

if [[ -z $LICENSEKEY ]]; then
	# Free version of Maxmind data
	curl "http://geolite.maxmind.com/download/geoip/database/GeoLite2-City-CSV.zip" > geoip.zip
	curl "http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz" > GeoLite2-City.mmdb.gz
	gunzip GeoLite2-City.mmdb.gz
else
	# Licensed version of Maxmind data
	# .csv files
	curl "https://download.maxmind.com/app/geoip_download?edition_id=GeoIP2-City-CSV&suffix=zip&license_key=$LICENSEKEY" > geoip.zip
	# binary database
	curl "https://download.maxmind.com/app/geoip_download?edition_id=GeoIP2-City&suffix=tar.gz&license_key=$LICENSEKEY" > mmdb.tar.gz
	# ISP data service
	curl "https://download.maxmind.com/app/geoip_download?edition_id=GeoIP2-ISP-CSV&suffix=zip&license_key=$LICENSEKEY" > isp.zip
	# binary ISP database 
	curl "https://download.maxmind.com/app/geoip_download?edition_id=GeoIP2-ISP&suffix=tar.gz&license_key=$LICENSEKEY" > isp_mmdb.tar.gz
fi
#
#
# .csv files
#
if [ -s geoip.zip ]; then
	#	Uncompress
	./7za.exe e -y geoip.zip
	rm LICENSE* COPYRIGHT* README*
	./7za.exe e -y isp.zip
	rm LICENSE* COPYRIGHT* README*

	#	Use the MaxMind utility to convert the downloaded .csv IPv4 and IPv6 files
	#	to change IP address block to start and end IP

	./geoip2-csv-converter.exe \
		-block-file=$VERSION-City-Blocks-IPv4.csv \
		-output-file=city-blocks.csv \
		-include-integer-range

	./geoip2-csv-converter.exe \
		-block-file=$VERSION-City-Blocks-IPv6.csv \
		-output-file=ipv6-city-blocks-abbrev.csv \
		-include-range

	./geoip2-csv-converter.exe \
		-block-file=$VERSION-ISP-Blocks-IPv4.csv \
		-output-file=isp_v4.csv \
		-include-integer-range

	./geoip2-csv-converter.exe \
		-block-file=$VERSION-ISP-Blocks-IPv6.csv \
		-output-file=isp_v6-abbrev.csv \
		-include-range

	# Delete first record (field names) in .csv files
	
	cat city-blocks.csv | sed '1d' > blocks.csv
	# expand IPv6 shorthand notation to zero fill missing octets
	cat ipv6-city-blocks-abbrev.csv | sed '1d' | perl ./IPv6-expand-city-blocks.pl > ipv6-blocks.csv

	cat $VERSION-City-Locations-en.csv | sed '1d' > locations.csv

	cat isp_v4.csv | sed '1d' > isp_IPv4.csv
	# expand IPv6 shorthand notation to zero fill missing octets
	cat isp_v6-abbrev.csv | sed '1d' | perl ./IPv6-expand-isp-blocks.pl > isp_IPv6.csv

# Recreate geolocation database, load records and rename as production database

	sqlite3 new-ipdb.sqlite < ipdb.ddl 2> /dev/null

	mv ipdb.sqlite ipdb.sqlite.old
	mv new-ipdb.sqlite ipdb.sqlite
	touch -m ipdb.sqlite
	# clean up
	rm ipdb.sqlite.old
	rm geoip.zip isp.zip *.csv 
fi

#
# Binary database
#
if [ -s mmdb.tar.gz ]; then
	# Uncompress
	gunzip -f mmdb.tar.gz
	gunzip -f isp_mmdb.tar.gz
	tar -xf mmdb.tar
	tar -xf isp_mmdb.tar
	# Replace database files
	cd $HOME/geolocation/GeoIP2-City_*
	rm -f $HOME/geolocation/GeoIP2-City.mmdb
	mv ./GeoIP2-City.mmdb ../GeoIP2-City.mmdb
	cd $HOME/geolocation/GeoIP2-ISP_*
	rm -f $HOME/geolocation/GeoIP2-ISP.mmdb
	mv ./GeoIP2-ISP.mmdb ../GeoIP2-ISP.mmdb
	# clean up 
	cd $HOME/geolocation
	rm -f *.csv
	rm -f mmdb.tar isp_mmdb.tar
	rm -rf ./GeoIP2-City_*
	rm -rf ./GeoIP2-ISP_*
fi
	
