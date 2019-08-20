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
	#print "set yrange [0:10]";
	print "set ylabel 'time since last measurement (us)'";
	print "set mytics 4";
	print "set terminal png";
	print "set grid ytics mytics xtics";
	print "plot '-' using 1:2 pt 6 ps 0.5 title 'SRTT'";

	npkts = 0;
	lowest = 0;
	last = 0;

	MILLISECOND = 1000000;
}

/^tcp_set_rto/ {
	time = int($3 / 1e6);
	pkts[time] += 1;
	if (last != time) {
		# New time increment.
		nxt[last] = time;
		last = time;
	}
}

END {

	while (nxt[lowest] > 0) {
		time = nxt[lowest];
		lowest = time;
		npkts = pkts[time];
		print "", time / 1e3, npkts;
	}

	print "", "e";
}
