DEPS = glib-2.0 gee-0.8 posix gtk4 vte-2.91-gtk4 libadwaita-1
build/litter: litter.vala build/litter.res.c | build
	valac -X -lm $(addprefix --pkg , $(DEPS)) --gresources litter.xml build/litter.res.c $< -o $@
build/litter.res.c: litter.xml resources/* | build
	glib-compile-resources --generate-source --target $@ $<
build:
	mkdir -p build
clean:
	rm -rf build
