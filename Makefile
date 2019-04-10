#
# Tools
#

AWK		:= awk
GNUPLOT		:= gnuplot
GUNZIP		:= gunzip
STATEMAP	:= statemap

#
# Files
#

TRACE_FILES	:= $(shell find . -name '*.out.gz')
STATEMAP_FILES	:= $(TRACE_FILES:%.out.gz=%-stackid.svg) $(TRACE_FILES:%.out.gz=%-cpu.svg)
GNUPLOT_IMGS	:= $(TRACE_FILES:%.out.gz=%-srs.png) $(TRACE_FILES:%.out.gz=%-pacing.png)

.SECONDARY: $(STATEMAP_FILES:%.out.gz=%.out) $(STATEMAP_FILES:%.svg=%.stream) $(GNUPLOT_IMGS:%.png=%.gpi)

#
# Targets
#

.PHONY: all
all: $(STATEMAP_FILES) $(GNUPLOT_IMGS)

%.out: %.out.gz
	$(GUNZIP) -k $<

%.svg: %.stream
	$(STATEMAP) $< > $@

%-cpu.stream: %.out rtt-statemap.awk
	$(AWK) -f rtt-statemap.awk -v entity=cpu $< > $@


%-stackid.stream: %.out rtt-statemap.awk
	$(AWK) -f rtt-statemap.awk -v entity=stackid $< > $@

%-srs.gpi: %.out srs-gnuplot.awk
	$(AWK) -f srs-gnuplot.awk $< > $@

%-srs.png: %-srs.gpi
	$(GNUPLOT) $< > $@

%-pacing.gpi: %.out pacing-gnuplot.awk
	$(AWK) -f pacing-gnuplot.awk $< > $@

%-pacing.png: %-pacing.gpi
	$(GNUPLOT) $< > $@
