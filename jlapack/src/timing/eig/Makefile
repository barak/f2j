.PHONY:	DUMMY util
.SUFFIXES: .f .java

ROOT=../../..

include $(ROOT)/make.def

BLAS=$(ROOT)/$(BLAS_IDX)
LAPACK=$(ROOT)/$(LAPACK_IDX)
MATGEN=$(ROOT)/$(MATGEN_IDX)

XERBLAFLAGS= -c .:$(ROOT)/$(BLAS_OBJ) -p $(ERR_PACKAGE)
F2JFLAGS=-c .:eigsrc/$(OUTDIR):$(ROOT)/$(BLAS_OBJ):$(ROOT)/$(LAPACK_OBJ):$(ROOT)/$(MATGEN_OBJ) -p $(EIGTIME_PACKAGE) -o $(OUTDIR)

timer: $(BLAS) $(LAPACK) $(MATGEN) eigsrc/$(OUTDIR)/Eigsrc.f2j $(OUTDIR)/Eigtime.f2j util

eigsrc/$(OUTDIR)/Eigsrc.f2j:
	cd eigsrc;$(MAKE)

$(OUTDIR)/Eigtime.f2j:	$(OUTDIR)/Lsamen.f2j eigtime.f
	$(F2J) $(F2JFLAGS) eigtime.f > /dev/null

$(OUTDIR)/Lsamen.f2j:   lsamen.f
	$(F2J) $(F2JFLAGS) $< > /dev/null

$(BLAS):
	cd $(ROOT)/$(BLAS_DIR); $(MAKE)

$(LAPACK):
	cd $(ROOT)/$(LAPACK_DIR); $(MAKE)

$(MATGEN):
	cd $(ROOT)/$(MATGEN_DIR); $(MAKE)

util:
	cd $(ROOT)/$(UTIL_DIR); $(MAKE)

runtimer:	timer *.in

*.in:	DUMMY
	java -cp .:./obj:eigsrc/$(OUTDIR):$(ROOT)/$(MATGEN_OBJ):$(ROOT)/$(BLAS_OBJ):$(ROOT)/$(LAPACK_OBJ):$(ROOT)/$(UTIL_OBJ) $(EIGTIME_PACKAGE).Dtimee < $@

clean:
	cd eigsrc;$(MAKE) clean
	/bin/rm -rf *.java *.class *.f2j $(OUTDIR)