/* 2025 Jan Provaznik (jan@provaznik.pro)
 */

class Litter.Application : Adw.Application {
  private Adw.ApplicationWindow? window = null;
  private Adw.TabView? tabview = null;
  private Adw.TabBar? tabhead = null;

  public override void activate () {
    this.window = new Adw.ApplicationWindow (this) {
      default_width = 1280,
      default_height = 720
    };
    this.window.set_title("Hello, world?");

    // GLib.Timeout.add(1000, () => {
    //   terminal.set_color_background(rgba_from_string("#000"));
    //   return false;
    // });

    var saCopy = new GLib.SimpleAction("copy", null);
    saCopy.activate.connect(this.on_clipboard_copy);
    this.add_action(saCopy);
    this.set_accels_for_action("app.copy", { "<Control><Shift>c" });

    var saPaste = new GLib.SimpleAction("paste", null);
    saPaste.activate.connect(this.on_clipboard_paste);
    this.add_action(saPaste);
    this.set_accels_for_action("app.paste", { "<Control><Shift>v" });

    var saTabNew = new GLib.SimpleAction("tab-new", null);
    saTabNew.activate.connect(this.on_tab_create);
    this.add_action(saTabNew);
    this.set_accels_for_action("app.tab-new", { "<Control><Shift>t" });

    // var saTabNext = new GLib.SimpleAction("tab-next", null);
    // saTabNext.activate.connect(this.on_tab_next);
    // this.add_action(saTabNext);
    // this.set_accels_for_action("app.tab-next", { "<Control>tab" });

    // var saTabPrev = new GLib.SimpleAction("tab-prev", null);
    // saTabPrev.activate.connect(this.on_tab_prev);
    // this.add_action(saTabPrev);
    // this.set_accels_for_action("app.tab-prev", { "<Control><Shift>tab" });

    this.tabview = new Adw.TabView() {
      hexpand = true,
      vexpand = true
    };
    this.tabhead = new Adw.TabBar() {
      view = this.tabview,
      autohide = false
    };
    
    set_margin(tabview, 10);
    this.on_tab_create();

    var layout = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
    layout.append(tabhead);
    layout.append(tabview);

    this.window.set_content(layout);
    this.window.present();

  }

  Vte.Terminal? current_terminal () {
    return (this.tabview?.selected_page?.child as Vte.Terminal);
  }

  void on_tab_create () {
    var starting_directory = GLib.Environment.get_home_dir();
    var current = this.current_terminal();
    if (current != null)
      starting_directory = GLib.Filename.from_uri(
        current.current_directory_uri, null);

    print("%s", starting_directory);

    var terminal = new Vte.Terminal();
    var page = this.tabview.append(terminal);
    this.tabview.selected_page = page;

    terminal.set_color_background(
      rgba_from_string("#00000000"));
    terminal.set_color_foreground(
      rgba_from_string("#fff"));
    terminal.font_desc = 
      Pango.FontDescription.from_string("Hack Normal 15");
    terminal.spawn_async(
      Vte.PtyFlags.DEFAULT,
      starting_directory,
      { "/bin/bash", "--login" },
      null,
      GLib.SpawnFlags.FILE_AND_ARGV_ZERO,
      null,
      -1,
      null,
      this.on_terminal_child_spawn);
    terminal.child_exited.connect(this.on_terminal_child_death);
    terminal.window_title_changed.connect(() => {
      page.title = terminal.window_title;
    });

    page.title = "%d".printf(this.tabview.n_pages);
    this.window.set_focus(terminal);
  }

  void on_tab_next () {
    if (! this.tabview.select_next_page())
      this.tabview.selected_page = this.tabview.get_nth_page(0);
  }

  void on_tab_prev () {
    if (! this.tabview.select_previous_page())
      this.tabview.selected_page = this.tabview.get_nth_page(this.tabview.n_pages - 1);
  }

  void on_clipboard_copy () {
    var terminal = current_terminal();
    if (terminal == null) 
      return;
    terminal.copy_clipboard_format(Vte.Format.TEXT);
  }

  void on_clipboard_paste () {
    var terminal = current_terminal();
    if (terminal == null) 
      return;
    terminal.paste_clipboard();
  }

  void on_terminal_child_death (int status) {
    print("Child death with %d code\n", status);

    this.tabview.close_page(this.tabview.selected_page);
    if (0 == this.tabview.n_pages)
      this.quit();
  }

  void on_terminal_child_spawn (Vte.Terminal term, GLib.Pid pid, GLib.Error? err) {
    if (err != null) {
      print("Child spawn ERROR %s\n", err.message);
      return;
    }

    print("Child spawn with %d pid\n", pid);
  }
}

Gdk.RGBA rgba_from_string (string value) {
  var target = Gdk.RGBA();
  target.parse(value);
  return target;
}

void set_margin (Gtk.Widget target, int margin) {
    target.margin_start = margin;
    target.margin_end = margin;
    target.margin_top = margin;
    target.margin_bottom = margin;
}

int main (string[] argv) {
  var app = new Litter.Application();
  return app.run(argv);
}

