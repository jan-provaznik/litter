DEPS = glib-2.0 gee-0.8 posix gtk4 vte-2.91-gtk4 libadwaita-1
build/litter: main.vala Makefile | build
	valac $(addprefix --pkg , $(DEPS)) main.vala -o $@
build:
	mkdir -p build
clean:
	rm -rf build
