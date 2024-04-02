-- DDL for MaxMind geolocation database
--
--	Author:		DS Crawford
--			Information Security Office
--			Sacramento State University
--
--	Date:		09 Feb 2015
--
--	Change log:	26 Apr 2016	add IPv6 support
--			11 May 2016	add accuracy field in blocks tables
--			05 Oct 2016	add ISP table

CREATE TABLE city_blocks (
        ip_start int,
        ip_end int,
        loc_id int,
        registered_country_geoname_id text,
        represented_country_geoname_id text,
        is_anonymous_proxy text,
        is_satellite_provider text,
        postal_code text,
        latitude real,
        longitude real,
	accuracy_radius int,
        primary key(ip_start));

CREATE TABLE IPv6_city_blocks (
        ip_start text,
        ip_end text,
        loc_id int,
        registered_country_geoname_id text,
        represented_country_geoname_id text,
        is_anonymous_proxy text,
        is_satellite_provider text,
        postal_code text,
        latitude real,
        longitude real,
	accuracy_radius int,
        primary key(ip_start));

CREATE TABLE city_location (
        loc_id int,
        locale_code text,
        continent_code text,
        continent_name text,
        country_code text,
        country_name text,
        subdivision_1_iso_code text,
        subdivision_1_name text,
        subdivision_2_iso_code text,
        subdivision_2_name text,
        city_name text,
        metro_code text,
        time_zone text,
        primary key(loc_id));

CREATE TABLE isp (
        ip_start int,
        ip_end int,
        isp text,
        organization text,
        asn text,
        asn_organization text,
        primary key(ip_start));

CREATE TABLE IPv6_isp (
        ip_start text,
        ip_start_abbrev text,
        ip_end text,
        isp text,
        organization text,
        asn text,
        asn_organization text,
        primary key(ip_start));

CREATE VIEW "wheres_waldo" AS select * from city_blocks, city_location WHERE city_blocks.loc_id = city_location.loc_id;

CREATE VIEW "wheres_ipv6_waldo" AS select * from IPv6_city_blocks, city_location WHERE IPv6_city_blocks.loc_id = city_location.loc_id;

.mode csv

.import ./blocks.csv city_blocks

.import ./ipv6-blocks.csv IPv6_city_blocks

.import ./locations.csv city_location

.import ./isp_IPv4.csv isp

.import ./isp_IPv6.csv IPv6_isp

.exit
