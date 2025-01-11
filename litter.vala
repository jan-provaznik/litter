/* 2025 Jan Provaznik (jan@provaznik.pro)
 */

int main (string[] argv) {
  var app = new Litter.Application();
  return app.run(argv);
}

class Litter.Application : Adw.Application {
  private Adw.ApplicationWindow? window = null;
  private Gtk.Box? headbox = null;

  private Adw.ViewStack? content = null;
  private Adw.TabView? tabview = null;
  private Adw.TabBar? tabhead = null;

  private GLib.SimpleAction? hangman = null;

  //

  public Application () {
    Object(
      flags: GLib.ApplicationFlags.NON_UNIQUE,
      version: "0.2.6",
      application_id: "pro.provaznik.Litter");
  }

  public override void activate () {
    this.window = new Adw.ApplicationWindow (this) {
      title = "Litter Terminal"
    };
    this.window.present();

    // Update default window geometry

    var? geometry = get_screen_geometry(this.window);
    if (geometry != null)
      this.window.set_default_size(
        geometry.width / 2, geometry.height / 2);

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
    this.set_accels_for_action("app.font-size-inc", { "<Control>plus", "<Control>equal" });

    action = new GLib.SimpleAction("font-size-dec", null);
    action.activate.connect(this.on_action_font_size_dec);
    this.add_action(action);
    this.set_accels_for_action("app.font-size-dec", { "<Control>minus" });

    action = new GLib.SimpleAction("font-size-one", null);
    action.activate.connect(this.on_action_font_size_one);
    this.add_action(action);
    this.set_accels_for_action("app.font-size-one", { "<Control>0" });

    action = new GLib.SimpleAction("tab-create", null);
    action.activate.connect(this.on_action_tab_create);
    this.add_action(action);
    this.set_accels_for_action("app.tab-create", { "<Control><Shift>t" });

    this.hangman = new GLib.SimpleAction("control-d", null);
    this.hangman.activate.connect(this.on_action_hangman);
    this.hangman.set_enabled(false);
    this.add_action(this.hangman);
    this.set_accels_for_action("app.control-d", { "<Control>d", "<Control>c" });

    // TabView

    this.tabview = new Adw.TabView() {
      hexpand = true,
      vexpand = true,

      shortcuts = (
        Adw.TabViewShortcuts.CONTROL_TAB | 
        Adw.TabViewShortcuts.CONTROL_SHIFT_TAB
      )
    };
    this.tabhead = new Adw.TabBar() {
      view = this.tabview,
      autohide = false,
      hexpand = true,
      inverted = false,
      can_focus = false,
      // expand_tabs = false,
    };
    this.tabhead.add_css_class("inline");

    this.tabview.close_page.connect(this.on_close_page);
    this.tabview.notify["selected-page"].connect(this.on_select_page);

    // Placeholder

    var placeholder = new Adw.Bin() {
      hexpand = true,
      vexpand = true,
      halign = Gtk.Align.CENTER,
      valign = Gtk.Align.CENTER,
    };

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
    placebutton.clicked.connect(this.on_action_tab_create);

    var placelayout = new Gtk.Box(Gtk.Orientation.VERTICAL, 20);
    placelayout.append(new Gtk.Label("There are no open terminals."));
    placelayout.append(placebutton);

    placeholder.set_child(placelayout);

    // Views

    this.content = new Adw.ViewStack();
    this.content.add_named(this.tabview, "workspace");
    this.content.add_named(placeholder, "placeholder");

    // Header

    var menuitems = new GLib.Menu();
    menuitems.append("New tab", "app.tab-create");
    menuitems.append("Increase font size", "app.font-size-inc");
    menuitems.append("Decrease font size", "app.font-size-dec");
    menuitems.append("Reset font size", "app.font-size-one");

    var menubutton = new Gtk.MenuButton() {
      primary = false,
      menu_model = menuitems,
      icon_name = "open-menu-symbolic",
      can_shrink = false,
      
      can_focus = false,
      hexpand = false,
      vexpand = false,
      valign = Gtk.Align.CENTER
    };
    menubutton.add_css_class("flat");
    menubutton.add_css_class("circular");

    this.headbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0) {
      margin_start = 4,
      margin_end = 4 
    };
    this.headbox.append(this.tabhead);
    this.headbox.append(menubutton);
    this.headbox.append(new Gtk.WindowControls(Gtk.PackType.END));

    var headerwrap = new Gtk.WindowHandle() {
      child = this.headbox
    };

    var layout = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
    layout.append(headerwrap);
    layout.append(this.content);

    // Window content
  
    this.window.set_content(layout);

    // Start with a new terminal

    this.content.set_visible_child_name("workspace");
    this.on_action_tab_create();

    // Pretty lookin', what's cookin'?

    GLib.Timeout.add(100, this.on_timer_update_highlight);
  }

  // Do the thing, do the thing.

  void do_tab_create () {
    this.content.set_visible_child_name("workspace");

    var starting_directory = get_starting_directory(
      this.get_active_terminal());

    var term = new Vte.Terminal();
    var page = this.tabview.append(term);
    this.tabview.set_selected_page(page);

    term.add_css_class("terminal");
    term.set_colors(
      rgba_from_string("#ffffff"),
      rgba_from_string("#242424"), {
        rgba_from_string("#241F31"),
        rgba_from_string("#C01C28"),
        rgba_from_string("#2EC27E"),
        rgba_from_string("#F5C211"),
        rgba_from_string("#1E78E4"),
        rgba_from_string("#9841BB"),
        rgba_from_string("#0AB9DC"),
        rgba_from_string("#C0BFBC"),
        rgba_from_string("#5E5C64"),
        rgba_from_string("#ED333B"),
        rgba_from_string("#57E389"),
        rgba_from_string("#F8E45C"),
        rgba_from_string("#51A1FF"),
        rgba_from_string("#C061CB"),
        rgba_from_string("#4FD2FD"),
        rgba_from_string("#F6F5F4")
      });
    term.set_font(Pango.FontDescription.from_string("hack normal 15"));
    term.set_scrollback_lines(-1);
    term.set_allow_hyperlink(true);

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

    // These have to be disconnected at some point

    term.bell.connect(this.on_terminal_bell);
    term.child_exited.connect(this.on_terminal_child_death);
    term.termprop_changed.connect(this.on_terminal_termprop_changed);

    // :)
    term.grab_focus();
  }

  int? get_set_last_pid (GLib.Object object, int? pid) {
    int? lastpid = object.get_data<int>("litter-last-pid");
    object.set_data<int>("litter-last-pid", pid);
    return lastpid;
  }

  string? get_last_css (GLib.Object object) {
    return object.get_data<string>("litter-last-css");
  }

  void set_last_css (GLib.Object object, string? css) {
    object.set_data<string>("litter-last-css", css);
  }

  void set_last_css_apply (GLib.Object object, string? value) {
    this.set_last_css(object, value);
    if (value != null)
      this.headbox.add_css_class(value);
  }

  void do_update_highlight () {
    var? term = get_active_terminal();
    if (term == null)
      return;

    var? pty = term.pty;
    if (pty == null)
      return;

    int tfd = pty.fd;
    if (tfd == 0)
      return;

    // Remove highlight classes
    this.headbox.remove_css_class("hl-cmd-user-root");
    this.headbox.remove_css_class("hl-cmd-task-remote");

    // Get foreground process
    int pid = Posix.tcgetpgrp(tfd);

    // Slight optimization.
    //
    // This might suffer from race conditions because a released process
    // identifier (pid) may be eventually reused by the system.

    int? lastpid = this.get_set_last_pid(term, pid);
    if (lastpid == pid) {
      string? lastcss = this.get_last_css(term);
      if (lastcss != null)
        this.headbox.add_css_class(lastcss);
      return;
    }

    // Get foreground process owner
    Posix.Stat? buf = null;
    Posix.stat(@"/proc/$pid", out buf);
    int uid = (int) buf.st_uid;

    // (A) Highlight tasks running as root
    if (uid == 0) {
      this.set_last_css_apply(term, "hl-cmd-user-root");
      return;
    }

    // Get foreground process program name (from cmdline)
    string? cmdline = get_pid_cmdline(pid);
    if (cmdline == null) {
      this.set_last_css_apply(term, null);
      return;
    }

    string cmdname = GLib.Path.get_basename(cmdline);

    // (B) Highlight specific tasks, like ssh (and only ssh at this time)
    if (cmdname == "ssh") {
      this.set_last_css_apply(term, "hl-cmd-task-remote");
      return;
    }

    this.set_last_css_apply(term, null);
  }

  // Event handlers

  bool on_close_page (Adw.TabPage page) {
    this.tabview.close_page_finish(page, true);
    if (this.tabview.n_pages == 0) {
      this.content.set_visible_child_name("placeholder");
      this.hangman.set_enabled(true);
    }
    return true;
  }

  void on_select_page () {
    this.do_update_highlight();
    this.tabview.selected_page?.set_needs_attention(false);
    this.content.set_visible_child_name("workspace");
    this.hangman.set_enabled(false);

    var? term = this.get_active_terminal();
    if (term != null)
      term.grab_focus();
  }

  void on_terminal_bell (Vte.Terminal term) {
    var? page = this.tabview.get_page(term);
    if (page != null)
      if (page != this.tabview.selected_page)
        page.set_needs_attention(true);
  }

  void on_terminal_child_death (Vte.Terminal term, int status) {
    print("Child death with %d status\n", status);

    term.bell.disconnect(this.on_terminal_bell);
    term.child_exited.disconnect(this.on_terminal_child_death);
    term.termprop_changed.disconnect(this.on_terminal_termprop_changed);

    var? page = this.get_page_by_child(term);
    if (page != null)
      this.tabview.close_page(page);
  }

  void on_terminal_termprop_changed (Vte.Terminal term, string what) {
    var? page = this.tabview.get_page(term);
    if (page == null)
      return;

    if (what != Vte.TERMPROP_XTERM_TITLE)
      return;

    string? value = term.get_termprop_string(Vte.TERMPROP_XTERM_TITLE, null);
    if (value != null)
      page.title = value;
  }

  void on_terminal_child_spawn (Vte.Terminal term, GLib.Pid pid, GLib.Error? err) {
    print("Child spawn with %d pid\n", pid);
  }

  bool on_timer_update_highlight () {
    this.do_update_highlight ();
    return true;
  }

  // Action handlers

  void on_action_tab_create () {
    this.do_tab_create();
  }

  void on_action_hangman () {
    if (this.tabview.n_pages == 0)
      this.quit();
  }

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

  void on_action_font_size_one () {
    var? term = this.get_active_terminal();
    if (term != null)
      term.font_scale = 1.0;
  }

  // Really useful helpers

  Vte.Terminal? get_active_terminal () {
    return (this.tabview.selected_page?.child as Vte.Terminal);
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

}

// I am positive there must be a better way to do this.

Gdk.RGBA rgba_from_string (string value) {
  var target = Gdk.RGBA();
  target.parse(value);
  return target;
}

string get_starting_directory (Vte.Terminal? term) {
  var? value = term?.ref_termprop_uri(Vte.TERMPROP_CURRENT_DIRECTORY_URI);

  if (value == null)
    return GLib.Environment.get_home_dir();

  try {
    return GLib.Filename.from_uri(value.to_string());
  } 
  catch (GLib.ConvertError err) {
    return GLib.Environment.get_home_dir();
  }
}

string? get_pid_cmdline (int pid) {
  string? cmdline = null;
  try {
    FileUtils.get_contents(@"/proc/$pid/cmdline", out cmdline);
    return cmdline;
  }
  catch (GLib.FileError err) {
    return null;
  }
}

Gdk.Rectangle? get_screen_geometry (Gtk.Window window) {
  var? monitor = window.display.get_monitor_at_surface(window.get_surface());
  if (monitor == null)
    return null;

  return monitor.geometry;
}

