LIBS= glib-2.0 gee-0.8 posix gtk4 libadwaita-1 vte-2.91-gtk4 
CFLAGS = -lm 
VFLAGS =

build/litter: litter.vala build/litter.res.c | build
	valac $(VFLAGS) $(addprefix -X , $(CFLAGS)) $(addprefix --pkg , $(LIBS)) \
		--gresources litter.xml build/litter.res.c $< -o $@
build/litter.res.c: litter.xml resources/* | build
	glib-compile-resources --generate-source --target $@ $<
build:
	mkdir -p build
clean:
	rm -rf build

