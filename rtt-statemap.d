#!/usr/sbin/dtrace -Cs

#pragma D option quiet
#pragma D option switchrate=100hz

#define SRS_TRACE(_i) 						\
	profile-97 /nsrs > _i/ {				\
		printf("sr_poll_pkt_cnt\t%d\t%p\t%d\n",		\
		    timestamp - start,				\
		    srs[_i], srs[_i]->srs_rx.sr_poll_pkt_cnt);	\
	}

BEGIN {
	wall = walltimestamp;
	printf("{\n\t\"start\": [ %d, %d ],\n",
	    wall / 1000000000, wall % 1000000000);
	printf("\t\"title\": \"RTTs\",\n");
	printf("\t\"host\": \"%s\",\n", `utsname.nodename);
	printf("\t\"states\": {\n");
	/* States will be defined during post-processing */
	printf("\t}\n}\n");
	start = timestamp;
}

fbt::tcp_set_rto:entry
{
	self->tcp = args[0];
	self->rtt = args[1];
}

fbt::tcp_set_rto:return
{
	printf("tcp_set_rto\t%d\t%d\t%p\t%d\t%d\t|\n", cpu, timestamp - start,
	    self->tcp, self->rtt, self->tcp->tcp_rtt_sa >> 3);
	stack();
	printf("|\n");
}

fbt::mac_hwring_enable_intr:entry
{
	self->srs = ((mac_ring_t *)args[0])->mr_srs;
	printf("mac_hwring_enable_intr\t%d\t%p\n", timestamp - start, self->srs);
}

fbt::mac_hwring_disable_intr:entry
{
	printf("mac_hwring_disable_intr\t%d\t%p\n", timestamp - start, ((mac_ring_t *)args[0])->mr_srs);
}

/*
 * Profile the values of the "sr_poll_pkt_cnt" field from the first 10 soft
 * ring sets that we see.
 */
fbt::mac_hwring_enable_intr:entry
/srsp[self->srs] != 1/
{
	srsp[self->srs] = 1;
	srs[nsrs++] = self->srs;
}

SRS_TRACE(0)
SRS_TRACE(1)
SRS_TRACE(2)
SRS_TRACE(3)
SRS_TRACE(4)
SRS_TRACE(5)
SRS_TRACE(6)
SRS_TRACE(7)
SRS_TRACE(8)
SRS_TRACE(9)
