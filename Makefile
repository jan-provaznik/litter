DEPS = glib-2.0 gee-0.8 posix gtk4 vte-2.91-gtk4 libadwaita-1
build/litter: main.vala build/litter.res.c | build
	valac -X -lm $(addprefix --pkg , $(DEPS)) --gresources main.gresource build/litter.res.c main.vala -o $@
build/litter.res.c: main.gresource resources/* | build
	glib-compile-resources --generate-source --target $@ $<
build:
	mkdir -p build
clean:
	rm -rf build
