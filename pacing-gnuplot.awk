BEGIN {
	OFS = "\t";

	if (ARGC != 2) {
		print "Please supply an input file." > "/dev/stderr";
		exit(2);
	}

	# Print out the leading gnuplot stanza.
	print "set title 'Pacing info for \"" ARGV[1] "\"'";
	print "set key off";
	print "set xlabel 'time (seconds)'";
	#print "set xtics 0.25";
	#print "set yrange [0:75]";
	print "set ylabel 'time since last measurement (us)'";
	print "set mytics 4";
	print "set terminal png";
	print "set grid ytics mytics xtics";
	print "plot '-' using 1:2 with dots title 'SRTT'";
}

/^tcp_set_rto/ {
	time = $3;
	if (last > 0) {
		print "", $3 / 1e9, (time - last) / 1e3;
	}
	last = $3;
}

END {
	print "", "e";
}
