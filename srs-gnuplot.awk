BEGIN {
	OFS = "\t";

	if (ARGC != 2) {
		print "Please supply an input file." > "/dev/stderr";
		exit(2);
	}

	# Print out the leading gnuplot stanza.
	print "set title 'Polling info for \"" ARGV[1] "\"'";
	print "set key outside center bottom horizontal height +1";
	print "set xlabel 'time (seconds)'";
	print "set yrange [0:75]";
	print "set ylabel '% time w/ sr\\_poll\\_pkt\\_cnt > 0'";
	print "set ytics 10";
	print "set mytics 2";
	print "set y2range [0:3000]";
	print "set y2label 'SRTT (us)'";
	print "set y2tics 400";
	print "set my2tics 2";
	print "set terminal png";
	print "set grid ytics mytics xtics";
	print "plot '-' using 1:2 pt 7 ps 0.25 axes x1y2 title 'SRTT', " \
	    "'-' using 1:2 with linespoints title '% time polling'";
}

/^sr_poll_pkt_cnt/ {
	time = int($2 * 2 / 1e9)
	lkey = time;

	if ($4 > 0) {
		nonzero[lkey] += 1;
	}

	times[lkey] = time;
	total[lkey] += 1;
}

/^tcp_set_rto/ {
	if ($6 > 3000000) {
		discarded += 1;
		next;
	}
	print "", $3 / 1e9, $6 / 1e3;
}

END {
	print "", "e";
	for (key = 0; key <= lkey; key++) {
		if (total[key] == 0) {
			continue;
		}

		print "", times[key] / 2, (nonzero[key] / total[key] * 100), total[key];
	}
	print "", "e";

	if (discarded > 0) {
		print "Discarded " discarded " outlying data points." > "/dev/stderr";
	}
}
