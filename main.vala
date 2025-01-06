/* 2025 Jan Provaznik (jan@provaznik.pro)
 */

class Litter.Application : Adw.Application {
  private Adw.ApplicationWindow? window = null;
  private Vte.Terminal? terminal = null;

  public override void activate () {
    this.window = new Adw.ApplicationWindow (this) {
      default_width = 1280,
      default_height = 720
    };
    this.window.set_title("Hello, world?");

    this.terminal = new Vte.Terminal();
    this.terminal.set_color_background(
      rgba_from_string("#00000000"));
    this.terminal.set_color_foreground(
      rgba_from_string("#fff"));
    this.terminal.font_desc = 
      Pango.FontDescription.from_string("Hack Normal 15");

    this.terminal.child_exited.connect(this.on_terminal_child_death);

    terminal.spawn_async(
      Vte.PtyFlags.DEFAULT,
      GLib.Environment.get_home_dir(),
      { "/bin/bash", "--login" },
      null,
      GLib.SpawnFlags.FILE_AND_ARGV_ZERO,
      null,
      -1,
      null,
      this.on_terminal_child_spawn);

    // GLib.Timeout.add(1000, () => {
    //   terminal.set_color_background(rgba_from_string("#000"));
    //   return false;
    // });
    
    set_margin(terminal, 20);


    var saCopy = new GLib.SimpleAction("copy", null);
    saCopy.activate.connect(this.on_clipboard_copy);
    this.add_action(saCopy);
    this.set_accels_for_action("app.copy", { "<Control><Shift>c" });

    var saPaste = new GLib.SimpleAction("paste", null);
    saPaste.activate.connect(this.on_clipboard_paste);
    this.add_action(saPaste);
    this.set_accels_for_action("app.paste", { "<Control><Shift>v" });

    // var tabbed = new Adw.TabBar();
    // var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
    // header.append(tabbed);
    var layout = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
    // layout.append(header);
    layout.append(terminal);

    this.window.set_content(layout);
    this.window.present();

  }

  void on_clipboard_copy () {
    if (this.terminal == null) 
      return;

    this.terminal.copy_clipboard_format(Vte.Format.TEXT);
  }

  void on_clipboard_paste () {
    if (this.terminal == null) 
      return;

    this.terminal.paste_clipboard();
  }

  void on_terminal_child_death (int status) {
    print("Child death with %d code\n", status);
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

