#!/user/bin/perl
# 
# IPv6-expand-city-blocks
#
# Author:	D.S. Crawford
#		Sacramento State University / Information Security Office
# Date:		21 Apr 2016
#
# Purpose:	Expand IPv6 addresses in City Blocks file 
# 		to include blocks of zeros
#
# Change log:	
#

while (<>) {

	chomp();
	$rec = $_;

	@item = split (/,/);

	$start_IP = $item[0];
	$end_IP = $item[1];
	$geoname_id = $item[2];
	$country_geoname_id = $item[3];
	$represented_country_geoname_id = $item[4];
	$anon_proxy = $item[5];
	$satellite = $item[6];
	$postal_code = $item[7];
	$lat = $item[8];
	$long = $item[9];
	$accuracy = $item[10];
	
	my ($start_IP_string) = build_IPv6_string ( $start_IP );
	my ($end_IP_string) = build_IPv6_string ( $end_IP );
	
	$out_rec = $start_IP_string . "," . $end_IP_string . "," . $geoname_id . "," . $country_geoname_id
       		. "," . $represented_country_geoname_id . "," . $anon_proxy . "," . $satellite
		. "," . $postal_code . "," . $lat . "," . $long . "," . $accuracy;
	
	print $out_rec, "\n";
}


sub build_IPv6_string {

	my $address = shift;
	my @item;
	my @addr;
	my $IP_string;
	
	@item = split (/:/, $address);

	my $no_tuples = $address =~ tr/://;

	#
	# Case 1: Full notation (8 tuples) and implicit trailing zero tuples
	#
	if (/\:\:$|^\d+/) {
		for ( my $i = 0; $i <= 7; $i++) {
			$addr[$i] = build_hex_group ($item[$i]);
			$IP_string = $IP_string . ":" . $addr[$i];
		}
		$IP_string =~ s/^\://;
	}
	#
	# Case 2: Implicit leading zero tuples
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
	# Case 3: implicit zero tuples in middle of IPv6 address
	else {
		$IP_string = "exception - " . $address;
	}

	return $IP_string;
}

sub build_hex_group {

my $hex_val = shift;

        $hex_group = sprintf("%04s", $hex_val);

        return $hex_group;
}
