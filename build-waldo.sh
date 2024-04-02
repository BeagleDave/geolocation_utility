#!/bin/sh
# waldo-install.sh
# Author:	DS Crawford
# Date:		25 Aug 2022
# Purpose:	To install the Wheres Waldo geolocation application in WSL

# build the environment required to run Wheres Waldo

# - install SQLite3
sudo apt install sqlite3

# - install Perl SQLite libraries
sudo apt-get install libdbi-perl
sudo apt-get install libdbd-sqlite3-perl

# install the Wheres Waldo script in the local code directory
sudo cp whereswaldo /usr/local/bin
sudo chmod 755 /usr/local/bin/whereswaldo

# make the local directory for Wheres Waldo and copy files

mkdir /$HOME/geolocation
cp * $HOME/geolocation

# build the Maxmind database
cd /$HOME/geolocation
./update-geolocation-db.sh
