#!/user/bin/perl
# 
# wheres-waldo.pl
#
# Author:	D.S. Crawford
#		California State University, Sacramento / Information Security Office
#
# Date:		11 Nov 2014
#
# Purpose:	Geolocate IP filter
# 		Appends country/region/city to record, based on IP in first column (tab delimited)
#
# Change log:	
#		2015-02-06	change the DB path, SELECT statement to reflect standard
#				location for SQLite3 implementation of MaxMind subscription database
#		2015-11-09	IPv6 detection, decode IPv6 to IPv4 tunnel addresses
#		2016-08-16	full IPv6 geolocation
#		2016-10-07	ISP retrieval
#		2021-04-14	DNS lookup option
#		2021-09-28	Port to WSL
#		2024-04-03	Handle IPv6 link local addresses
#
use DBI;
use Getopt::Long qw(GetOptions);

# Set output format
# 	- location	only location 	country<tab>region<tab>city		(default)
# 	- isp		include ISP	location plus ISP<tab>ISP organization
# 	- dns		include FQDN	location plus FQDN

my $format_value;

GetOptions('format=s' => \$format_value) or die "Usage: $0 --format FORMAT\n";

if ($format_value eq "") {
	$format = "default";
}
else {
	$format = $format_value;
}
	
my $IP;

# Open IP location SQLite database
my $dbh = DBI->connect("dbi:SQLite:dbname=/mnt/c/bin/geolocation/ipdb.sqlite", "", "", { RaiseError => 1 }, ) or die $DBI::errstr;

while (<>) {

	chomp();
	$rec = $_;

	@item = split (/\t/);

	$IP = $item[0];
	
	# obtain the lat/long, country, region/state and city for the IP
	my ($country, $region, $city, $lat, $long, $isp, $organization) = find_waldo ( $IP );

	if ($format_value eq "") {
		# legacy location data
		$out_rec = $rec . "\t" . $country . "\t" . $region . "\t" . $city;
	}
	elsif ($format_value eq "location") {
		# location data
		$out_rec = $rec . "\t" . $country . ":" . $region . ":" . $city;
	}
	elsif ($format_value eq "isp") {
		# location and ISP data
		$out_rec = $rec . "\t" . $country . ":" . $region . ":" . $city . "\t" . $isp . ":" . $organization;
	}
	elsif ($format_value eq "dns") {
		# DNS lookup
		$src_name = IP_to_name ( $IP );
		# location, ISP, DNS data
		$out_rec = $rec . "\t" . $country . ":" . $region . ":" . $city . "\t" . $isp . ":" . $organization . "\t" . $src_name;
	}

	print $out_rec, "\n";

}

$dbh->disconnect;


sub find_waldo {
	#
	# Retrieve the geolocation data for a specified IPv4 or IPv6 address
	#
	my $address = shift;
	#
	# Check if IPv4 or IPv6 address
	#
        if ($address =~ m/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/) {
        	#
		# IPv4 address
		#
        }
        elsif ($address =~ m/^2002\:/) {
		#
                # 6to4 - IPv4 tunneled over IPv6
		# - IPv4 address encapsulated in second/third groups (3rd to 6th octets)
		# - Extract IPv4 address for geolocation as 6to4 IPv6 address is not in Maxmind data service
		#
                ($addr) = $address =~ m/^2002\:([0-9a-f]+\:[0-9a-f]+)/;
                ($aa, $bb, $cc, $dd) = $addr =~ m/([0-9a-f]{2})([0-9a-f]{2})\:([0-9a-f]{2})([0-9a-f]{2})/;
		# rewrite IP address as IPv4 equivalent
	        $IPv4 = hex_to_int($aa) . "." . hex_to_int($bb) . "." . hex_to_int($cc) . "." . hex_to_int($dd);
		# rewrite input record
		$rec =~ s/$address/$IPv4/;
		$address = $IPv4;
		$IP = $IPv4;
	}
        elsif ($address =~ m/^fe80\:/) {
		#
                # IPv6 link local address space: fe80::/10
		# Set location to default location and return
		#
		my ($country, $region, $city, $lat, $long, $isp, $organization) = set_default_location();
		return ($country, $region, $city, $lat, $long, $isp, $organization);
	}
	elsif ($address =~ m/[0-9a-f]{2,4}\:|\:\:/) {
		# 
		# Geolocate IPv6 address
		#
		my ($IPv6_string) = build_IPv6_string ( $address );

		$IP = $IPv6_string;

		my $sql = 'SELECT country_code, subdivision_1_iso_code, city_name, latitude, longitude FROM wheres_ipv6_waldo WHERE ip_start <= "' . $IPv6_string . '" ORDER BY ip_start DESC LIMIT 1';
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while (my @row = $sth->fetchrow_array) {
			$country = $row[0];
			$region = $row[1];
			$city = $row[2];
			$lat = $row[3];
			$long = $row[4];
		}
		# retrieve ISP information
		my $sql = 'SELECT isp, organization FROM IPv6_isp WHERE ip_start <= "' . $IPv6_string . '" ORDER BY ip_start DESC LIMIT 1';
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while (my @row = $sth->fetchrow_array) {
			$isp = $row[0];
			$organization = $row[1];
		}

		return ($country, $region, $city, $lat, $long, $isp, $organization);
	}
	else {
		return ("invalid IP", "", "", 0, 0, "", "");
	}
	# 
	# Geolocate IPv4 address
	#
	if ( reserved_address_check($address) ) {
		my ($country, $region, $city, $lat, $long, $isp, $organization) = set_default_location();
		return ($country, $region, $city, $lat, $long, $isp, $organization);
	} else {
		# 
		# Geolocate IPv4 address
		#
		my $nIP = to_decimal ($address);

		my $sql = 'SELECT country_code, subdivision_1_iso_code, city_name, latitude, longitude FROM wheres_waldo WHERE ip_start <= ' . $nIP . ' ORDER BY ip_start DESC LIMIT 1';
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while (my @row = $sth->fetchrow_array) {
			$country = $row[0];
			$region = $row[1];
			$city = $row[2];
			$lat = $row[3];
			$long = $row[4];
			}
		# retrieve ISP information
		my $sql = 'SELECT isp, organization FROM isp WHERE ip_start <= ' . $nIP . ' ORDER BY ip_start DESC LIMIT 1';
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while (my @row = $sth->fetchrow_array) {
			$isp = $row[0];
			$organization = $row[1];
			}
		return ($country, $region, $city, $lat, $long, $isp, $organization);
	}
}

sub reserved_address_check {
	my $address = shift;
	if ($address =~ m/^0\..*/) {
		# RFC1700 0.0.0.0/8 address
		return 1;
	} elsif  ($address =~ m/^10\..*/) {
		# RFC1918 private 10.0.0.0/8 address
		return 1;
	} elsif  ($address =~ m/^192\.168\..*/) {
		# RFC1918 private 192.168.0.0/16 address
		return 1;
	} elsif ($IP =~ m/^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\./) {
		# RFC1918 private 172.16.0.0/20 address
		return 1;
	} elsif ($IP =~ m/^127\.0\.0\.1/) {
		# localhost (127.0.0.1) address
		return 1;
	}
	else {
		return 0;
	}
}

sub set_default_location {
	# Set the geolocation data for reserved addresses to CSUS
	$country = 'US';
	$region = 'CA';
	$city = 'Sacramento';
	$lat = 38.5689;
	$long = -121.4383;
	$isp = 'California State University, Sacramento';
	$organization = 'California State University, Sacramento';
	return ($country, $region, $city, $lat, $long, $isp, $organization);
}

sub to_decimal {
	# convert an IPv4 dotted quad address into an unsigned 32 bit integer.
	my $address = shift;

	my $dec_addr = 0;
	my $aa, $bb, $cc, $dd = "";

	my ($aa, $bb, $cc, $dd) = $address =~ m/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;

	# ensure that each component is an integer in the range 1..255
	if ( check_dotted_quad_value($aa) 
			&& check_dotted_quad_value($bb) 
			&& check_dotted_quad_value($cc) 
			&& check_dotted_quad_value($dd) ) {
		$dec_addr = $aa * 256**3 + $bb * 256**2 + $cc * 256 + $dd;
	} else {
		printf STDERR ("Bad IP conversion: %s\n", $address);
		$dec_addr = 0;
	}

	return $dec_addr;
}

sub check_dotted_quad_value {
	my ($quad_value) = @_;
	if ( $quad_value =~ /^[0-9]{1,3}\z/ && $quad_value < 256 ) {
		return 1;
	} else {
		return 0;
	}
}

sub hex_to_int {

my $hex_val = shift;

        $dec_val = sprintf("%d", hex($hex_val));

        return $dec_val;
}

sub build_IPv6_string {

	my $address = shift;
	my @item;
	my @addr;
	my $IP_string;
	
	@item = split (/:/, $address);

	my $no_tuples = $address =~ tr/://;

	#
	# Case 1: Full notation (8 tuples)
	#
	if (/[0-9a-f]{1,4}\:[0-9a-f]{1,4}\:[0-9a-f]{1,4}\:[0-9a-f]{1,4}\:[0-9a-f]{1,4}\:[0-9a-f]{1,4}\:[0-9a-f]{1,4}\:[0-9a-f]{1,4}/) {
		for ( my $i = 0; $i <= 7; $i++) {
			$addr[$i] = build_hex_group ($item[$i]);
			$IP_string = $IP_string . ":" . $addr[$i];
		}
		$IP_string =~ s/^\://;
	}
	#
	# Case 2: Implicit trailing zero tuples
	#
	elsif (/\:\:$/) {
		for ( my $i = 0; $i <= 7; $i++) {
			$addr[$i] = build_hex_group ($item[$i]);
			$IP_string = $IP_string . ":" . $addr[$i];
		}
		$IP_string =~ s/^\://;
	}
	#
	# Case 3: Implicit leading zero tuples
	#
	elsif (/^\:\:/) {
		for ( my $i = 7; $i >= 0; $i--) {
			if ($i - (7 - $no_tuples) > 0) {
				$addr[$i] = build_hex_group ($item[$i - (7 - $no_tuples)]);
			}
			else {
				$addr[$i] = build_hex_group (0);
			}
			$IP_string = $addr[$i] . ":" . $IP_string;
		}
		$IP_string =~ s/\:$//;
	}
	#
	# Case 4: implicit zero tuples in middle of IPv6 address (not addressed)
	# 
	else {
		for ( my $i = 0; $i <= $no_tuples; $i++) {
			if ($item[$i] ne "") {
				$addr[$i] = build_hex_group ($item[$i]);
				$IP_string = $IP_string . ":" . $addr[$i];
			} 
			else {
				my $j = $i;
				my $last = $j + (7 - $no_tuples);
				for ( $j; $j <= $last; $j++) {
					$addr[$j] = build_hex_group (0);
					$IP_string = $IP_string . ":" . $addr[$j];
				}
			}
		}
		$IP_string =~ s/^\://;
	}
	
	$IP_string =~ s/ //;

	return $IP_string;
}

sub build_hex_group {

	my $hex_val = shift;

        $hex_group = sprintf("%04s", $hex_val);

        return $hex_group;
}

sub IP_to_name {

	# DNS lookup
	my $ip = shift;

	my ($IP1, $IP2, $IP3, $IP4) = $ip =~ m/^(\d+)\.(\d+)\.(\d+)\.(\d+)/;

	($host, $aliases, $addrtype, $length, @addrs) = gethostbyaddr( pack( 'C4', $IP1, $IP2, $IP3, $IP4 ), AF_INET );

	$host = $ip unless $host;

	return $host;  
}

