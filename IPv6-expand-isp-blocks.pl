#!/user/bin/perl
# 
# IPv6-expand-isp-blocks.pl
#
# Author:	D.S. Crawford
#		Sacramento State University / Information Security Office
# Date:		24 Oct 2016
#
# Purpose:	Expand IPv6 addresses in ISP IPv6 data to include blocks of zeros
#
# Change log:	
#

while (<>) {

	chomp();
	$rec = $_;

	@item = split (/,/);

	$start_IP = $item[0];
#	$end_IP = $item[1];
#	$isp = $item[2];
#	$organization = $item[3];
#	$asn = $item[4];
#	$asn_organization = $item[5];
	
	my ($start_IP_string) = build_IPv6_string ( $start_IP );
#	my ($end_IP_string) = build_IPv6_string ( $end_IP );
	
	$out_rec = $start_IP_string . "," . $rec;
#	$out_rec = $start_IP_string . "," . $end_IP_string . "," . $isp . "," 
#		. $organization . "," . $asn . "," . $asn_organization;
	
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
