CFLAGS?=-g -ggdb -O0 -Wall -Werror
RUBY?=ruby
NASM?=nasm
AR?=ar
SED?=sed
INSTALL?=install
PREFIX?=/usr/local

DATADIR=$(PREFIX)/share/mlisp
BINDIR=$(PREFIX)/bin
LIBDIR=$(PREFIX)/lib
RUBY_CODE=\
		  compiler.rb\
		  cond_handler.rb \
		  constants.rb \
		  defun_handler.rb \
		  emitter.rb \
		  label_gen.rb \
		  lambda_handler.rb \
		  lexer.rb \
		  log.rb \
		  nodes.rb \
		  parser.rb \
		  quoter.rb \
		  semantic_check.rb \
		  tokens.rb
DATA_FILES=$(RUBY_CODE) libmlisp.a
VERSION=$(shell git describe --tags)

.SUFFIXES: .asm .lisp
.PHONY: clean all install uninstall doc

all: mlispc.rb libmlisp.a
mlispc.rb: mlispc.rb.in
	$(SED) $^ -e 's/PATH/$(subst /,\/,$(DATADIR))/' \
		-e 's/VERSION/$(VERSION)/' > $@
libmlisp.a: stdlib.o funcs.o
	$(AR) crus $@ $^
funcs.o: funcs.asm
	$(SED) $^ -i -e 's/^extern \(and, null.*\)/global \1/' -e 's/^global main//'
	$(NASM) -felf -g $^ -o $@
stdlib.o: stdlib.c constants.h
constants.h: constants.rb
	$(SED) $^ -e 's/^module.*//' -e 's/^end$$//' -e 's/^\s*#.*//' \
		-e 's/^\s*\([A-Z_]\+\)\s*=/#define \1/' > $@
clean:
	rm -rf *.o constants.h libmlisp.a test *.asm mlispc.rb doc
.lisp.asm: mlispc.rb
	$(RUBY) mlispc.rb -E -o $@ $^
install: all
	mkdir -p $(DATADIR) $(BINDIR) $(LIBDIR)
	$(INSTALL) -m 644 $(DATA_FILES) $(DATADIR)
	$(INSTALL) -m 644 libmlisp.a $(LIBDIR)
	$(INSTALL) -m 755 mlispc.rb $(BINDIR)/mlispc
uninstall:
	rm -rf $(DATADIR)
	rm -f $(LIBDIR)/libmlisp.a
	rm -f $(BINDIR)/mlispc
doc:
	rdoc -a -S -N -w 2 -U -o doc README *.rb
