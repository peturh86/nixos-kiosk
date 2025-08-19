{ pkgs, ... }:
let
  # For now, use system icons. You can update these paths later when you add custom icons
  sap = pkgs.makeDesktopItem {
    name = "web";
    desktopName = "Web";
    exec = "firefox --new-window https://www.ja.is";
    icon = "firefox";  # Will use custom icon once you add web.png to assets/icons/
    categories = [ "Network" ];
  };

  ips = pkgs.makeDesktopItem {
    name = "ips";
    desktopName = "IPS";
    exec = "ips";
    icon = "wine";     # Will use custom icon once you add ips.png to assets/icons/
    categories = [ "Utility" ];
  };

  intranet = pkgs.makeDesktopItem {
    name = "sap";
    desktopName = "SAP (Web)";
    exec = "chromium --app=https://sapapp-p1.postur.is/sap/bc/gui/sap/its/webgui";
    icon = "chromium"; # Will use custom icon once you add sap.png to assets/icons/
    categories = [ "Network" ];
  };
in
{
  environment.etc."xdg/tint2/tint2rc".text = ''
    panel_items = LTSC
    panel_position = bottom center horizontal
    panel_size = 100% 48
    panel_background_id = 1
    panel_border_width = 0
    panel_margin = 0 0
    panel_padding = 2 0 2
    panel_dock = 0
    wm_menu = 0
    panel_layer = top
    panel_monitor = all

    # Background definitions
    background_color = #2C2C2C 60
    border_width = 1
    border_sides = TBLR
    border_color = #000000 30
    background_color_hover = #3C3C3C 60
    border_color_hover = #EAEAEA 44
    background_color_pressed = #4C4C4C 60
    border_color_pressed = #EAEAEA 44

    # Taskbar
    taskbar_mode = single_desktop
    taskbar_hide_if_empty = 0
    taskbar_padding = 0 0 2
    taskbar_background_id = 0
    taskbar_active_background_id = 0
    taskbar_name = 0
    taskbar_hide_inactive_tasks = 0
    taskbar_hide_different_monitor = 0
    taskbar_always_show_all_desktop_tasks = 0
    taskbar_name_padding = 4 2
    taskbar_name_background_id = 0
    taskbar_name_active_background_id = 0
    taskbar_name_font_color = #e3e3e3 100
    taskbar_name_active_font_color = #ffffff 100
    taskbar_distribute_size = 0
    taskbar_sort_order = none
    task_align = left

    # Task
    task_text = 1
    task_icon = 1
    task_centered = 1
    urgent_nb_of_blink = 100000
    task_maximum_size = 150 35
    task_padding = 2 2 4
    task_tooltip = 1
    task_thumbnail = 0
    task_thumbnail_size = 210
    task_font_color = #ffffff 100
    task_background_id = 0
    task_active_background_id = 2
    task_urgent_background_id = 2
    task_iconified_background_id = 0
    mouse_left = toggle_iconify
    mouse_middle = none
    mouse_right = close
    mouse_scroll_up = prev_task
    mouse_scroll_down = next_task

    # System tray (Systray)
    systray_padding = 0 4 2
    systray_background_id = 0
    systray_sort = ascending
    systray_icon_size = 24
    systray_icon_asb = 100 0 0
    systray_monitor = 1
    systray_name_filter = 

    # Launcher
    launcher_padding = 8 12 8
    launcher_background_id = 0
    launcher_icon_background_id = 0
    launcher_icon_size = 40
    launcher_icon_asb = 100 0 0
    launcher_icon_theme_override = 0
    startup_notifications = 1
    launcher_tooltip = 1
    launcher_item_app = ${sap}/share/applications/web.desktop
    launcher_item_app = ${ips}/share/applications/ips.desktop
    launcher_item_app = ${intranet}/share/applications/sap.desktop

    # Clock
    time1_format = %H:%M
    time2_format = %A %d %B
    time1_timezone = 
    time2_timezone = 
    time1_font = sans 10
    time2_font = sans 8
    clock_font_color = #ffffff 100
    clock_padding = 8 4
    clock_background_id = 0
    clock_tooltip = %A %d %B %Y
    clock_tooltip_timezone = 
    clock_lclick_command = 
    clock_rclick_command = 
    clock_mclick_command = 
    clock_uwheel_command = 
    clock_dwheel_command = 

    # Battery
    battery_tooltip = 1
    battery_low_status = 10
    battery_low_cmd = 
    battery_full_cmd = 
    bat1_font_color = #ffffff 100
    bat2_font_color = #ffffff 100
    battery_padding = 1 0
    battery_background_id = 0
    battery_hide = 101

    # Tooltip
    tooltip_show_timeout = 0.5
    tooltip_hide_timeout = 0.1
    tooltip_padding = 4 4
    tooltip_background_id = 1
    tooltip_font_color = #222222 100
  '';
}
