### build rules follow... ###

# generate the symlinks (libxbee.so -> libxbee.so.x.x.x)
$(addprefix $(DESTDIR)/$(LIBNAME),.a .so p.a p.so): $(DESTDIR)/$(LIBNAME)%: $(DESTDIR)/$(LIBNAME)%.$(LIBFULLREV)
	$(SYMLINK) -fs `basename $^` $@

# generate the shared object & debug file
$(addsuffix .$(LIBFULLREV).dbg, $(addprefix $(DESTDIR)/$(LIBNAME),.so p.so)): $(DESTDIR)/$(LIBNAME)%.so.$(LIBFULLREV).dbg: $(DESTDIR)/$(LIBNAME)%.so.$(LIBFULLREV)
	$(OBJCOPY) --only-keep-debug $^ $@
	$(OBJCOPY) --add-gnu-debuglink=$@ $^
	$(OBJCOPY) --strip-debug $^
	touch $@

$(addsuffix .$(LIBFULLREV), $(addprefix $(DESTDIR)/$(LIBNAME),.so p.so)): $(DESTDIR)/$(LIBNAME)%.so.$(LIBFULLREV): .$(DESTDIR).dir $(DESTDIR)/$(LIBNAME)%.o
$(addsuffix .so.$(LIBFULLREV), $(DESTDIR)/$(LIBNAME)):
	$(GCC) -shared -Wl,--no-undefined -Wl,-soname,$(LIBNAME)$*.so.$(LIBFULLREV) $(filter %.o,$^) $(CLINKS) -o $@
$(addsuffix p.so.$(LIBFULLREV), $(DESTDIR)/$(LIBNAME)): $(addsuffix .so.$(LIBFULLREV), $(DESTDIR)/$(LIBNAME))
	$(GXX) -shared -Wl,--no-undefined -Wl,-soname,$(LIBNAME)$*.so.$(LIBFULLREV) $(filter %.o,$^) $(CXXLINKS) -o $@

# generate the static library
$(addsuffix .$(LIBFULLREV),$(addprefix $(DESTDIR)/$(LIBNAME),.a p.a)): $(DESTDIR)/$(LIBNAME)%.a.$(LIBFULLREV): .$(DESTDIR).dir $(DESTDIR)/$(LIBNAME)%.o
	$(AR) rcs $@ $(filter %.o,$^)

# generate the 'libxbee' object file
$(DESTDIR)/$(LIBNAME).o: .$(DESTDIR).dir $(addprefix $(BUILDDIR)/,__core.o __mode.o $(foreach mode,$(MODELIST),__mode_$(mode).o))
	$(LD) -r -o $@ $(filter %.o,$^)

$(DESTDIR)/$(LIBNAME)p.o: .$(DESTDIR).dir $(BUILDDIR)/__corep.o
	$(LD) -r -o $@ $(filter %.o,$^)

$(BUILDDIR)/__core.o: $(CORE_OBJS)
$(BUILDDIR)/__corep.o: $(CORE_OBJSP)
$(BUILDDIR)/__mode.o: $(MODE_OBJS)
$(BUILDDIR)/__%.o:
	$(LD) -r -o $@ $(filter %.o,$^)

###
# dynamically generate these rules for each mode
define mode_rule
# build a mode's object & dep file
.PRECIOUS: $$(BUILDDIR)/modes_$1_%.d
$$(BUILDDIR)/__mode_$1.o: $(MODE_$1_OBJS)
$$(MODE_$1_OBJS): $$(BUILDDIR)/modes_$1_%.o: modes/$1/%.c
endef
$(foreach mode,$(MODELIST),$(eval $(call mode_rule,$(mode))))

# static/common rules for the modes
$(BUILDDIR)/__plugin_%.o: .$(BUILDDIR).dir
	$(LD) -r -o $@ $(filter %.o,$^)
$(MODE_MODE_OBJS): $(BUILDDIR)/modes_%.o: .$(BUILDDIR).dir
	$(GCC) $(CFLAGS) -MMD $(filter %.c,$^) -c -o $@
#####

# build the common mode code
$(BUILDDIR)/modes_%.o: .$(BUILDDIR).dir
	$(GCC) $(CFLAGS) -MMD modes/$*.c -c -o $@

###
# these objects require special treatment
$(BUILDDIR)/ver.o: $(BUILDDIR)/%.o: .$(BUILDDIR).dir make/libconfig.mk
	$(GCC) $(CFLAGS) -MMD $(VER_DEFINES) $*.c -c -o $@
#####

# build C++ object & dep files
$(CORE_OBJSP): $(BUILDDIR)/%.o: .$(BUILDDIR).dir
	$(GXX) $(CXXFLAGS) -MMD $*.cpp -c -o $@

# build a core object & dep files
$(BUILDDIR)/%.o: .$(BUILDDIR).dir
	$(GCC) $(CFLAGS) -MMD $*.c -c -o $@

# include all the dep files avaliable
-include $(wildcard $(BUILDDIR)/*.d)

ifneq ($(MAN2HTML),)
# generate HTML from man pages
$(addprefix $(HTMLDIR)/,$(filter-out index.html,$(SYS_HTMLPAGES))): $(HTMLDIR)/%.html: $(MANDIR)/%
	@echo "cat $^ | $(MAN2HTML) -rp | tail -n +3 > $@"
	@mkdir -p `dirname $@`
	@if [ ! -h $^ ]; then                        \
	cat $^ | $(MAN2HTML) -rp | tail -n +3 > $@;  \
  chmod 644 $@;                                \
else                                           \
	$(SYMLINK) -fs $(shell readlink $^).html $@; \
fi
$(HTMLDIR)/index.html: $(filter %libxbee.3.html,$(HTMLDIR)/$(SYS_HTMLPAGES))
	$(SYMLINK) -fs $(subst $(HTMLDIR)/,,$^) $@
endif
