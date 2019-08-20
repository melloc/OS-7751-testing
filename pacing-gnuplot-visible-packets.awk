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
	print "set yrange [0:10]";
	print "set ylabel 'time since last measurement (us)'";
	print "set mytics 4";
	print "set terminal png";
	print "set grid ytics mytics xtics";
	print "plot '-' using 1:2 with dots title 'SRTT'";

	npkts = 0;
	lowest = 0;
	last = 0;

	MILLISECOND = 1000000;
}

function trim() {
	while (lowest < time - 3 * MILLISECOND) {
		npkts -= pkts[lowest];
		lowest = nxt[lowest];
	}
}

/^tcp_set_rto/ {
	time = $3;
	pkts[time] += 1;
	nxt[last] = time;
	npkts += 1;

	trim();

	print "", $3 / 1e9, npkts;

	last = time;
}

END {
	print "", "e";
}
