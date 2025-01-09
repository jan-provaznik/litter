/* 2025 Jan Provaznik (jan@provaznik.pro)
 */

class Litter.Application : Adw.Application {
  private Adw.ApplicationWindow? window = null;
  private Adw.ViewStack? content = null;

  private Adw.TabView? tabview = null;
  private Adw.TabBar? tabhead = null;
  private Gtk.Box? headbox = null;

  public Application () {
    Object(application_id: "pro.provaznik.Litter", 
      flags: GLib.ApplicationFlags.NON_UNIQUE);
  }

  public override void activate () {
    this.window = new Adw.ApplicationWindow (this) {
      default_width = 1280,
      default_height = 720
    };

    // Action!

    GLib.SimpleAction? action = null;

    action = new GLib.SimpleAction("copy", null);
    action.activate.connect(this.on_action_clipboard_copy);
    this.add_action(action);
    this.set_accels_for_action("app.copy", { "<Control><Shift>c" });

    action = new GLib.SimpleAction("paste", null);
    action.activate.connect(this.on_action_clipboard_paste);
    this.add_action(action);
    this.set_accels_for_action("app.paste", { "<Control><Shift>v" });

    action = new GLib.SimpleAction("font-size-inc", null);
    action.activate.connect(this.on_action_font_size_inc);
    this.add_action(action);
    this.set_accels_for_action("app.font-size-inc", { "<Control>plus" });

    action = new GLib.SimpleAction("font-size-dec", null);
    action.activate.connect(this.on_action_font_size_dec);
    this.add_action(action);
    this.set_accels_for_action("app.font-size-dec", { "<Control>minus" });

    action = new GLib.SimpleAction("tab-create", null);
    action.activate.connect(this.on_action_tab_create);
    this.add_action(action);
    this.set_accels_for_action("app.tab-create", { "<Control><Shift>t" });

    // TabView

    this.tabview = new Adw.TabView() {
      hexpand = true,
      vexpand = true,
      margin_bottom = 8,
      margin_start = 8,
      margin_end = 8,
      margin_top = 8,

      shortcuts = (
        Adw.TabViewShortcuts.CONTROL_TAB | 
        Adw.TabViewShortcuts.CONTROL_SHIFT_TAB
      )
    };
    this.tabhead = new Adw.TabBar() {
      view = this.tabview,
      autohide = false,
      hexpand = true,
      inverted = false
    };
    this.tabhead.set_css_classes({ "inline" });

    this.tabview.close_page.connect(this.on_close_page);
    this.tabview.notify["selected-page"].connect(() => {
      //this.content.set_visible_child_name("workspace");
      //this.do_detect_process();
    });

    // Placeholder

    var placeholder = new Adw.Bin() {
      hexpand = true,
      vexpand = true,
      halign = Gtk.Align.CENTER,
      valign = Gtk.Align.CENTER,
    };
    var placelayout = new Gtk.Box(Gtk.Orientation.VERTICAL, 20);
    var placebutton = new Gtk.Button() {
      label = "Open a new terminal",
      hexpand = false,
      vexpand = false,
      halign = Gtk.Align.CENTER,
      valign = Gtk.Align.CENTER,
      has_frame = true
    };
    placebutton.add_css_class("suggested-action");
    placebutton.add_css_class("pill");
    placelayout.append(new Gtk.Label("There are no open terminals."));
    placelayout.append(placebutton);
    placeholder.set_child(placelayout);
    placebutton.clicked.connect(this.on_action_tab_create);

    // Views

    this.content = new Adw.ViewStack();
    this.content.add_named(this.tabview, "workspace");
    this.content.add_named(placeholder, "placeholder");

    // Header

    this.headbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
    this.headbox.append(this.tabhead);
    this.headbox.append(new Gtk.WindowControls(Gtk.PackType.END) { margin_end = 4 });

    var headerwrap = new Gtk.WindowHandle() {
      child = this.headbox
    };

    var layout = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
    layout.append(headerwrap);
    layout.append(this.content);

    // Window content
  
    this.window.set_content(layout);
    this.window.present();

    // Start with a new terminal

    this.content.set_visible_child_name("workspace");
    this.on_action_tab_create();

    //GLib.Timeout.add(500, this.on_timer_detect_process);
  }

  bool on_timer_detect_process () {
    this.do_detect_process();
    return true;
  }

  void do_detect_process () {
    var? term = get_active_terminal();
    if (term == null)
      return;

    var? pty = term.pty;
    if (pty == null)
      return;

    int tfd = pty.fd;
    if (tfd == 0)
      return;

    // Get foreground process
    int pid = Posix.tcgetpgrp(tfd);

    // Get foreground process owner
    Posix.Stat? buf = null;
    Posix.stat(@"/proc/$pid", out buf);
    int uid = (int) buf.st_uid;

    if (uid == 0) {
      this.headbox_apply_style(true, false);
      return;
    }
    else {
      this.headbox_apply_style(false, false);
    }

    // Get foreground process commandline
    string? cmdline = null;
    FileUtils.get_contents(@"/proc/$pid/cmdline", out cmdline);

    string cmdname = GLib.Path.get_basename(cmdline);
    if (cmdname == "ssh") {
      this.headbox_apply_style(false, true);
    }
    else {
      this.headbox_apply_style(false, false);
    }
  }

  void headbox_apply_style (bool super, bool remote) {
    if (remote)
      this.headbox.add_css_class("hl-cmd-remote");
    else
      this.headbox.remove_css_class("hl-cmd-remote");

    if (super)
      this.headbox.add_css_class("hl-cmd-super");
    else
      this.headbox.remove_css_class("hl-cmd-super");
  }

  Vte.Terminal? get_active_terminal () {
    return (this.tabview.selected_page?.child as Vte.Terminal);
  }

  bool on_close_page (Adw.TabPage page) {
    this.tabview.close_page_finish(page, true);
    if (this.tabview.n_pages == 0)
      this.content.set_visible_child_name("placeholder");
    return true;
  }

  void on_action_tab_create () {
    this.content.set_visible_child_name("workspace");

    var starting_directory = get_starting_directory(
      this.get_active_terminal());

    var term = new Vte.Terminal();
    var page = this.tabview.append(term);
    this.tabview.set_selected_page(page);

    term.set_color_background(
      rgba_from_string("rgba(0, 0, 0, 0)"));
    term.set_color_foreground(
      rgba_from_string("#fff"));
    term.font_desc = 
      Pango.FontDescription.from_string("Hack Normal 15");

    term.spawn_async(
      Vte.PtyFlags.DEFAULT,
      starting_directory,
      { "/bin/bash", "--login" },
      null,
      0,
      null,
      -1,
      null,
      this.on_terminal_child_spawn);
    term.child_exited.connect(this.on_terminal_child_death);
    term.window_title_changed.connect(this.on_terminal_window_title_changed);

    // :)
    this.window.set_focus(term);
  }

  void on_terminal_child_death (Vte.Terminal term, int status) {
    print("Child death with %d status\n", status);

    term.child_exited.disconnect(this.on_terminal_child_death);
    term.window_title_changed.disconnect(this.on_terminal_window_title_changed);

    var? page = this.get_page_by_child(term);
    if (page != null)
      this.tabview.close_page(page);
  }

  void on_terminal_window_title_changed (Vte.Terminal term) {
    var? page = this.tabview.get_page(term);
    if (page != null)
      page.title = term.window_title;
  }

  Adw.TabPage? get_page_by_child (Gtk.Widget child) {
    var model = this.tabview.pages;
    var count = model.get_n_items();
    for (var index = 0; index < count; ++index) {
      var? page = (model.get_item(index) as Adw.TabPage);
      if (page?.child == child)
        return page;
    }
    return null;
  }

  void on_terminal_child_spawn (Vte.Terminal term, GLib.Pid pid, GLib.Error? err) {
    print("Child spawn with %d pid\n", pid);
  }

  // void on_tab_next () {
  //   if (! this.tabview.select_next_page())
  //     this.tabview.selected_page = this.tabview.get_nth_page(0);
  // }

  // void on_tab_prev () {
  //   if (! this.tabview.select_previous_page())
  //     this.tabview.selected_page = this.tabview.get_nth_page(this.tabview.n_pages - 1);
  // }

  void on_action_clipboard_copy () {
    var? term = this.get_active_terminal();
    if (term != null)
      term.copy_clipboard_format(Vte.Format.TEXT);
  }

  void on_action_clipboard_paste () {
    var? term = this.get_active_terminal();
    if (term != null)
      term.paste_clipboard();
  }

  void on_action_font_size_inc () {
    var? term = this.get_active_terminal();
    if (term != null)
      term.font_scale = term.font_scale + 0.1;
  }

  void on_action_font_size_dec () {
    var? term = this.get_active_terminal();
    if (term != null)
      term.font_scale = Math.fmax(0.0, term.font_scale - 0.1);
  }

}

Gdk.RGBA rgba_from_string (string value) {
  var target = Gdk.RGBA();
  target.parse(value);
  return target;
}

string get_starting_directory (Vte.Terminal? term) {
  if (term?.current_directory_uri != null)
    return GLib.Filename.from_uri(term.current_directory_uri, null);
  return GLib.Environment.get_home_dir();
}

int main (string[] argv) {
  var app = new Litter.Application();
  return app.run(argv);
}

