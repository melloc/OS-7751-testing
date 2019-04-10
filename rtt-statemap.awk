function dump(arr) {
    print "array contains:" > "/dev/stderr";
    for (key in arr) {
        printf("\t%s = %s\n", key, arr[key]) > "/dev/stderr";
    }
}

function min(a, b) {
    if (a < b) {
        return a;
    } else {
        return b;
    }
}

function max(a, b) {
    if (a > b) {
        return a;
    } else {
        return b;
    }
}

function ceil(a) {
    b = int(a);

    return a + 1 - (a == b);
}

function rgbstr(r, g, b) {
    return sprintf("#%.2x%.2x%.2x", int(r * 255), int(g * 255), int(b * 255));
}

function hsv2rgbstr(hsv) {
    h = hsv["h"];
    s = hsv["s"];
    v = hsv["v"];

    if (s == 0) {
        return rgbstr(v, v, v);
    }

    h /= 60;
    i = int(h);
    f = h - i;
    p = v * (1 - s);
    q = v * (1 - s * f);
    t = v * (1 - s * (1 - f));

    if (i == 0) {
        return rgbstr(v, t, p);
    } else if (i == 1) {
        return rgbstr(q, v, p);
    } else if (i == 2) {
        return rgbstr(p, v, t);
    } else if (i == 3) {
        return rgbstr(p, q, v);
    } else if (i == 4) {
        return rgbstr(t, p, v);
    } else {
        return rgbstr(v, p, q);
    }
}

function rgb2hsv(arr) {
    r = arr["r"];
    g = arr["g"];
    b = arr["b"];

    delete arr["r"];
    delete arr["g"];
    delete arr["b"];

    r /= 255;
    g /= 255;
    b /= 255;

    mini = min(r, min(g, b));
    maxi = max(r, max(g, b));
    v = maxi;

    delta = maxi - mini;

    if (maxi == 0) {
        s = 0;
        h = 0;
    } else {
        s = delta / maxi;

        if (r == maxi) {
            h = (g - b) / delta;
        } else if (g == maxi) {
            h = 2 + (b - r) / delta;
        } else {
            h = 4 + (r - g) / delta;
        }

        h *= 60;

        if (h < 0) {
            h += 360;
        }
    }

    arr["h"] = h;
    arr["s"] = s;
    arr["v"] = v;
}

function defstate(name, lvl, color, final) {
    printf("\t\t\"%s\": {\"value\": %d, \"color\": \"%s\" }%s\n",
        name, lvl, color, final ? "" : ",");
}

function eventpr(time, entity, state) {
    printf("{\"time\":\"%d\",\"entity\":\"%s\",\"state\":%d}\n",
        time, entity, state);
}

function rttrec(time, entity, rtt) {
    if (last[entity] > 0 && time - last[entity] > idletime) {
        # Retroactively reset the entity to an RTT of 0 after a gap
        # of at least idletime length so that we can observe when an
        # entity is doing nothing.
        eventpr(last[entity] + idletime, entity, 0);
    }

    eventpr(time, entity, min(maxrtt, ceil(rtt / rttprec)));

    last[entity] = time;
}

function stackid(s) {
    if (sids[s] == 0) {
        sids[s] = nxtsid++;
    }

    return sids[s];
}

function pickfilter(name, curr, possible) {
    if (curr != "") {
        return curr;
    }

    printf("Possible \"%s\" values:\n", name) > "/dev/stderr";

    maxfilter = "";
    maxvalue = 0;

    for (p in possible) {
        printf("\t- %s (appears in %d traces)\n", p, possible[p]) > "/dev/stderr";

        if (possible[p] > maxvalue) {
            maxfilter = p;
            maxvalue = possible[p];
        }
    }

    if (maxvalue == 0) {
        printf("No possible \"%s\" values found.\n", name) > "/dev/stderr";
        exit(2);
    }
    
    while (1) {
        printf("\nSelect a \"%s\" value [%s]:", name, maxfilter) > "/dev/stderr";

        getline < "/dev/stdin";

        if (NF == 0) {
            return maxfilter;
        } else if (NF > 1) {
            continue;
        } else if (possible[$1] > 0) {
            return $1;
        }
    }
}

function checkfilter(file) {
    while ((getline < file) > 0) {
        if ($1 == "mac_hwring_enable_intr" ||
            $1 == "mac_hwring_disable_intr" ||
            $1 == "sr_poll_pkt_cnt") {
            srsfilters[$3] += 1;
        } else if ($1 == "tcp_set_rto") {
            tcpfilters[$4] += 1;
        }
    }

    tcpfilter = pickfilter("tcpfilter", tcpfilter, tcpfilters);
    srsfilter = pickfilter("srsfilter", srsfilter, srsfilters);

    close(file);
}

function cacheload() {
    printf("Loading any previous stacks from %s\n", CACHEFILE) > \
        "/dev/stderr";

    while ((getline < CACHEFILE) > 0) {
        if ($1 == "stack") {
            sids[$3] = $2;
            nxtsid = max(nxtsid, $2 + 1);
        }
    }

    close(CACHEFILE);
}

function cachedump() {
    for (stack in sids) {
        printf("stack\t%d\t%s\n", sids[stack], stack) > CACHEFILE;
    }

    printf("Stack information written to %s\n", CACHEFILE) > "/dev/stderr";
}

BEGIN {
    # bucket by 100's of microseconds
    rttprec = 1e5; 
    # 2,500 microseconds
    maxrtt = 2500000 / rttprec; 
    # reset after idle for a fifth of a second
    idletime = 200000000;

    # Constants for hwring interrupts enabled/disabled state.
    HWRING_ENABLED = maxrtt + 1;
    HWRING_DISABLED = maxrtt + 2;

    POLLCNT_ZERO = HWRING_DISABLED + 1;
    maxpollcnt = 10;

    CACHEFILE = "rtt-statemap.cache";

    metadata = "";

    instart = 1;
    instack = 0;
    stack = "";
    nxtsid = 1;

    if (ARGC != 2) {
        print "Please specify an input file." > "/dev/stderr";
        exit(2);
    }

    if (entity == "") {
        print "Please specify an \"entity\"." > "/dev/stderr";
        exit(2);
    }

    cacheload();

    checkfilter(ARGV[1]);
}

#
# Process opening metadata block.
#

instart {
    print;
}

instart && /"states"/ {
    green["r"] = 0;
    green["g"] = 255;
    green["b"] = 0;
    rgb2hsv(green);

    red["r"] = 255;
    red["g"] = 0;
    red["b"] = 0;
    rgb2hsv(red);

    blue["r"] = 0;
    blue["g"] = 160;
    blue["b"] = 160;
    rgb2hsv(blue);

    purple["r"] = 128;
    purple["g"] = 0;
    purple["b"] = 128;
    rgb2hsv(purple);

    # Set up RTT states.
    hd = (red["h"] - green["h"]) / maxrtt;

    defstate("rtt-0", 0, "#e0e0e0", 0);

    for (step = 1; step <= maxrtt; step++) {
        defstate("rtt-" step, step, hsv2rgbstr(green), 0);
        green["h"] += hd;
    }

    # Set up interrupt enabled/disabled states.
    defstate("enabled", HWRING_ENABLED, "#ff55ff", 0);
    defstate("disabled", HWRING_DISABLED, "#55ffff", 0);

    # Set up interrupt enabled/disabled states.
    hd = (purple["h"] - blue["h"]) / maxpollcnt;

    defstate("poll-cnt-0", POLLCNT_ZERO, "#e6e6fa", 0);

    for (step = 1; step <= maxpollcnt; step++) {
        defstate("poll-cnt-" step, POLLCNT_ZERO + step, hsv2rgbstr(blue), step == maxpollcnt);
        blue["h"] += hd;
    }
}

instart && $0 == "}" {
    instart = 0;
    next;
}

#
# Process each interrupt disable/enable trace, collapsing the multiline stack.
#

$1 == "mac_hwring_enable_intr" {
    if ($3 == srsfilter) {
        eventpr($2, "interrupts", HWRING_ENABLED);
        srscnt += 1;
    }
    next;
}

$1 == "mac_hwring_disable_intr" {
    if ($3 == srsfilter) {
        eventpr($2, "interrupts", HWRING_DISABLED);
        srscnt += 1;
    }
    next;
}

#
# Process each trace of the "sr_poll_pkt_cnt" fields.
#

$1 == "sr_poll_pkt_cnt" {
    if ($3 == srsfilter) {
        eventpr($2, "sr_poll_pkt_cnt", POLLCNT_ZERO + min($4, maxpollcnt));
        srscnt += 1;
    }
    next;
}

#
# Process each RTT trace, collapsing the multiline stack.
#

!instart && !instack && length > 0 {
    if ($1 != "tcp_set_rto") {
        printf("Expected tcp_set_rto line at %s:%d\n", FILENAME, FNR) > "/dev/stderr";
        exit(2);
    }

    delete props;
    props["cpu"] = $2;
    props["time"] = $3;
    props["tcp"] = $4;
    props["nrtt"] = $5;
    props["srtt"] = $6;

    if ($7 != "|") {
        printf("Missing beginning of stack at %s:%d\n", FILENAME, FNR) > "/dev/stderr";
        exit(2);
    }

    instack = 1;
    stack = "";
}

instack && length($1) > 1 {
    stack = stack $1 "\\n";
}

instack && $0 == "|" {
    instack = 0;

    props["stack"] = stack;
    props["stackid"] = stackid(stack);

    if (tcpfilter != props["tcp"]) {
        next;
    }

    tcpcnt += 1;

    rttrec(props["time"], entity "-" props[entity], props["nrtt"]);
    rttrec(props["time"], "SRTT", props["srtt"]);
}

END {
    if (tcpcnt == 0) {
        printf("No RTT updates processed; is \"tcpfilter\" right?\n") > \
           "/dev/stderr";
        exit(2);
    }

    if (srscnt == 0) {
        printf("No SRS traces processed; is \"srsfilter\" right?\n") > \
            "/dev/stderr";
        exit(2);
    }

    cachedump();
}
