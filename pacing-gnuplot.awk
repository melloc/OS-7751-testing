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
	print "set xrange [10.00:16.455]";
	print "set yrange [0:600]";
	print "set y2range [0:2500]";
	#print "set xtics 0.25";
	#print "set yrange [0:75]";
	print "set ylabel 'avg. time since last RTT measurement (us)'";
	print "set mytics 4";
	print "set y2tics";
	print "set terminal png";
	print "set grid ytics mytics xtics";
	print "plot '-' using 1:2 pt 7 ps 0.25, '-' using 1:2 pt 7 ps 0.25 axes x1y2 title 'SRTT'";

	alpha = 1/8;
	beta = 1/4;
}

function square(n) {
	return n * n;
}

function abs(n) {
	if (n < 0) {
		return -n;
	} else {
		return n;
	}
}

/^tcp_set_rto/ {
	time = $3 / 1e3;
	if (last > 0) {
		diff = time - last;
		if (avg == 0) {
			avg = diff;
			var = diff / 2;
		} else {
			var = (1 - beta) * (var) + beta * abs(avg - diff);
			avg = (1 - alpha) * avg + alpha * diff;
		}
		if (var > 2000) {
			printf("time = %f, last = %f, avg = %f, var = %f, diff = %f\n", time, last, avg, var, diff) > "/dev/stderr";
		}
		print "", $3 / 1e9, var;
	}
	last = time;

	if ($6 > 3000000) {
		discarded += 1;
		next;
	}

	srtts[count++] = "\t" ($3 / 1e9) "\t" ($6 / 1e3);
}

END {
	print "", "e";
	for (i = 0; i < count; i++) {
		print srtts[i];
	}
	print "", "e";
}
