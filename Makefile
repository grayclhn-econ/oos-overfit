# I use makefiles to control the execution of monte-carlo and
# empirical code, and to make sure that my LaTeX files are generated
# correctly.  You can run 
#
# make -n
#
# to generate a list the order of commands to run.  Running
#
# make
#
# should run the analysis and generate the final pdf file: paper.pdf

SHELL        := /bin/bash
R            := R
RFLAGS       := --vanilla
Rscript      := Rscript
sqlite       := sqlite3
sqliteFLAGS  := $(empty)
LATEXMKFLAGS := -pdf
latexmk  := latexmk

## define some convenience functions
object = $(notdir $(basename $(1)))
addboth = $(addprefix $(1),$(addsuffix $(2),$(3)))

# variables for the first monte carlo; this is a little complciated
# because I'm using the makefile to split the simulations into several
# different jobs (I'm using a computer with mutliple processors).  Be
# aware that the results reported in the paper will change slightly if
# you change the number of jobs, because of the seeding for the random
# number generators.
mcSQL   := $(call addboth,data/,.done,nobs coefficients)
mcP     := data/oosstats.done 
mcDB    := $(mcSQL) $(mcP)
mcRnw   := $(wildcard data/*.Rnw)

.PHONY: all mc clean dist burn zip
.DELETE_ON_ERROR: $(mcDB) 
.IGNORE: paper.pdf

# Basic execution of the makefile will run all of the tests, then
# build the final version of the paper.
all: paper.pdf
mc: $(mcDB) $(mcRnw:.Rnw=.pdf) # for convenience -- allows 'make mc'

empfloats:=  floats/empirics-oos-mse-1.tex \
  floats/empirics-oos-mse-1b.tex floats/empirics-oos-mse-2.tex \
  floats/empirics-oos-mse-2b.tex floats/empirics-waldtest.tex \
  floats/empirics-coeftest.tex floats/empirics-oos-ind-ks.tex \
  floats/empirics-oos-ind-pm.tex
mcfloats := floats/mc-dmwsize.tex floats/mc-clarkwestsize.tex floats/mc-dmwpower.tex \
  floats/mc-mccrackensize.tex floats/mc-interval-testerror1.tex \
  floats/mc-interval-generror1.tex floats/mc-ftest.tex
floats := $(mcfloats) $(empfloats)

floats: $(floats)
$(empfloats): floats/%.tex: R/%.R data/empirical-results.RData | floatsdir
$(mcfloats): floats/%.tex: R/%.R data/simulations.done | floatsdir
data/empirical-results.RData: R/empirics.R data/goyalwelch2009.csv

$(floats) data/empirical-results.RData:
	$(Rscript) $(RFLAGS) $<

floatsdir:
	mkdir -p floats

paper.pdf: paper.tex setup.tex $(floats)
	$(latexmk) $(LATEXMKFLAGS) $<

# These are the dependencies for the database.  Since all of the
# tables are stored inside the same file, we can't use the filenames
# directly to control execution order.  Instead, we're using empty
# files as dummy variables that indicate when the table was built.
# This is facilitated by our naming scheme: the SQL commands to create
# the table or view 'xxx' are contained in the file 'xxx.sql'.  The R
# commands to create the table 'xxx' are contained in 'xxx.R'.  The
# dummy file 'xxx.done' indicates when the table was first created
# and filled with data.  So we can represent the entire database
# creation by using two static rules (one for the R files and one for
# the SQL files) and a bunch of dependencies.
$(mcSQL): %.done: %.sql
	$(sqlite) $(sqliteFLAGS) data/simulations.db < $<
	touch $@
# The order of this dependency is abitrary; we want to prevent these
# two commands from being run simultaneously during a parallel make.
data/coefficients.done: data/nobs.done
# I use the makefile to parallelize the simulations (this is kind of
# ghetto, but effective and easy).  Basically, I create several
# different temporary databases and store simulation results in each
# one, then insert the values into a table in the main database -- the
# reason is to get around problems that SQLite has with concurrent
# write access (in the future, I'll probably use a different DBM).
# All of the dependencies that manage that process are contained in
# mc-setup.mk, which is automatically generated by mc-setup.py.
# mc-setup.py has the parameters that control the number of
# simulations, number of jobs to use, etc.
mc-setup.mk: mc-setup.py
	python $< > $@
include mc-setup.mk

localpackages := package/fwPackage package/pgfSweave
.SECONDARY: fwPackage_1.0.tar.gz pgfSweave_1.3.0.tar.gz $(tikz)
pgfSweave_1.3.0.tar.gz fwPackage_1.0.tar.gz: %.tar.gz: package/%_source
	$(R) CMD build $<
package/fwPackage: fwPackage_1.0.tar.gz
package/pgfSweave: pgfSweave_1.3.0.tar.gz
$(localpackages):
#IDGAF	$(R) CMD check -o $(@D) $<
	$(R) CMD INSTALL --byte-compile --library=$(@D) $<

# There are a few other standard targets that remove unnecessary
# left-over files.
clean:
	$(RM) -rf $(foreach d,. mc data,$(addprefix $d/,*.prv *.log *.bbl *.aux *.toc *~ *.Rout *.blg *.Rnwout .Rhistory))
distclean: clean
	$(RM) -rf mc-setup.mk data/*.done data/*.db floats
burn: distclean
	$(RM) -rf *.pdf
