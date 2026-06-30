#!/usr/bin/env python3
import os
import sys
import time
import subprocess
import threading
import json
import math

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, Gdk, Gio, GLib, Pango, Gtk4LayerShell
import cairo

# Import collectors
from collectors import (
    SystemCollector,
    CPUCollector,
    MemoryCollector,
    GPUCollector,
    StorageCollector,
    NetworkCollector,
    BatteryCollector,
    ProcessCollector,
    ServiceCollector,
    LogCollector,
    UpdateCollector,
    PortsCollector
)

# Initialize collectors
system_coll = SystemCollector()
cpu_coll = CPUCollector()
mem_coll = MemoryCollector()
gpu_coll = GPUCollector()
storage_coll = StorageCollector()
net_coll = NetworkCollector()
battery_coll = BatteryCollector()
proc_coll = ProcessCollector()
service_coll = ServiceCollector()
log_coll = LogCollector()
update_coll = UpdateCollector()
ports_coll = PortsCollector()

# Custom CSS for the premium warm yellow/sand theme
CSS_DATA = """
window {
    background-color: transparent;
}

.main-card {
    background-color: #121214;
    color: #e2e8f0;
    border-radius: 16px;
    border: 1px solid rgba(255, 255, 255, 0.03);
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25);
}

/* Explicitly style all labels to ensure they are visible on dark background */
label {
    color: #e2e8f0;
    font-size: 11px;
}

label.sub-text {
    color: #a0aec0;
    font-size: 10px;
}

label.bold-text {
    color: #ffffff;
    font-weight: 700;
    font-size: 11px;
}

label.card-title {
    color: #a0aec0;
    font-size: 10px;
}

.card {
    background-color: #1e1e24;
    border-radius: 12px;
    padding: 10px 12px;
    margin: 4px 8px;
    border: 1px solid rgba(255, 255, 255, 0.03);
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25);
}

.warning-card {
    background-color: #2d1f1f;
    border: 1px solid #78281f;
    padding: 8px 12px;
}

.warning-card label {
    color: #f1948a;
}

.card-title {
    font-size: 10px;
    font-weight: 800;
    color: #a0aec0;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    margin-bottom: 2px;
}

.clock-time {
    font-size: 30px;
    font-weight: 800;
    color: #ffffff;
    letter-spacing: -1px;
}

.clock-date {
    font-size: 11px;
    font-weight: 500;
    color: #a0aec0;
}

scale trough {
    min-height: 4px;
    border-radius: 2px;
    background-color: rgba(255, 255, 255, 0.1);
}

scale highlight {
    border-radius: 2px;
    background-color: #f5b041;
}

scale slider {
    min-width: 10px;
    min-height: 10px;
    margin: -3px 0;
    border-radius: 50%;
    background-color: #ffffff;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.4);
    transition: transform 0.1s ease;
}

scale slider:hover {
    transform: scale(1.2);
}

levelbar trough {
    min-height: 4px;
    border-radius: 2px;
    background-color: rgba(255, 255, 255, 0.1);
}

levelbar block {
    border-radius: 2px;
    background-color: #f5b041;
}

button {
    background-color: rgba(255, 255, 255, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.02);
    border-radius: 8px;
    padding: 4px 8px;
    color: #e2e8f0;
    font-weight: 600;
    font-size: 11px;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}

button:hover {
    background-color: rgba(255, 255, 255, 0.12);
    color: #ffffff;
    transform: translateY(-1px);
}

button:active {
    transform: translateY(0);
}

button.close-btn {
    background-image: none;
    background-color: rgba(255, 255, 255, 0.08);
    color: #a0aec0;
    border: none;
    border-radius: 9999px;
    min-width: 22px;
    min-height: 22px;
    padding: 0;
    font-size: 13px;
    font-weight: 700;
    transition: all 0.2s ease;
}

button.close-btn:hover {
    background-color: rgba(255, 255, 255, 0.15);
    color: #ffffff;
    transform: scale(1.1);
}

button.profile-btn {
    background-image: none;
    background-color: rgba(255, 255, 255, 0.06);
    color: #a0aec0;
    border: none;
    border-radius: 8px;
    padding: 6px 4px;
    font-weight: 700;
    font-size: 9.5px;
}

button.profile-btn:hover {
    background-image: none;
    background-color: rgba(255, 255, 255, 0.12);
    color: #ffffff;
}

button.profile-btn.active {
    background-image: none;
    background-color: #f5b041;
    color: #121214;
    box-shadow: 0 2px 6px rgba(245, 176, 65, 0.3);
}

/* Custom styling for SpinButton in dark mode */
spinbutton {
    background-color: rgba(255, 255, 255, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    padding: 1px 4px;
}

spinbutton, spinbutton text, spinbutton entry {
    color: #ffffff !important;
    background-color: transparent;
}

spinbutton button {
    background-color: transparent;
    border: none;
    color: #a0aec0;
    padding: 1px 4px;
}

spinbutton button:hover {
    background-color: rgba(255, 255, 255, 0.1);
    color: #ffffff;
}

.nav-bar {
    background-color: #18181c;
    border-top: 1px solid rgba(255, 255, 255, 0.03);
    padding: 6px 12px;
}

.nav-btn {
    background-color: transparent;
    background-image: none;
    border: none;
    box-shadow: none;
    color: #a0aec0;
    font-size: 11px;
    font-weight: 700;
    padding: 6px 12px;
    border-radius: 8px;
}

.nav-btn:hover {
    background-color: rgba(255, 255, 255, 0.06);
    color: #ffffff;
}

.nav-btn.active {
    background-color: #f5b041;
    background-image: none;
    color: #121214;
    border: none;
    box-shadow: 0 2px 6px rgba(245, 176, 65, 0.2);
}

.list-item {
    padding: 4px 6px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
}

.mono-text {
    font-family: 'JetBrainsMono Nerd Font', monospace;
    font-size: 9.5px;
}

.bold-text {
    font-weight: 700;
}

.sub-text {
    font-size: 9.5px;
    color: #a0aec0;
}

scrollbar trough {
    background-color: transparent;
}
scrollbar slider {
    background-color: rgba(255, 255, 255, 0.1);
    border-radius: 3px;
}

.compact-card {
    background-color: #1e1e24;
    border-radius: 12px;
    padding: 8px 12px;
    margin: 0;
    border: 1px solid rgba(255, 255, 255, 0.03);
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25);
}

label.arch-logo {
    font-size: 28px;
    color: #1793d1;
    margin-left: 4px;
    font-weight: bold;
}
"""


class CircularProgress(Gtk.DrawingArea):
    def __init__(self, label_text):
        super().__init__()
        self.label_text = label_text
        self.value = 0.0
        self.charging = False
        self.set_draw_func(self.draw)
        self.set_size_request(42, 55)

    def set_value(self, value):
        self.value = max(0.0, min(1.0, value))
        self.queue_draw()

    def set_charging(self, charging):
        if self.charging != charging:
            self.charging = charging
            self.queue_draw()

    def draw(self, drawing_area, cr, width, height):
        cx = width / 2.0
        cy = 22.0
        radius = 15.0
        thickness = 3.0

        # Draw background track
        cr.set_source_rgba(255/255, 255/255, 255/255, 0.08)
        cr.set_line_width(thickness)
        cr.arc(cx, cy, radius, 0, 2 * math.pi)
        cr.stroke()

        # Draw active progress arc
        if self.value > 0:
            if self.label_text == "BAT" and self.value <= 0.20:
                cr.set_source_rgb(231/255, 76/255, 60/255) # Soft Red when battery <= 20%
            elif self.label_text == "BAT" and self.charging:
                cr.set_source_rgb(46/255, 204/255, 113/255) # Emerald Green when charging
            else:
                cr.set_source_rgb(245/255, 176/255, 65/255) # Amber Yellow otherwise
            cr.set_line_width(thickness)
            cr.set_line_cap(cairo.LINE_CAP_ROUND)
            start_angle = -math.pi / 2.0
            end_angle = start_angle + (2 * math.pi * self.value)
            cr.arc(cx, cy, radius, start_angle, end_angle)
            cr.stroke()

        # Center percentage value
        pct_text = f"{int(self.value * 100)}"
        cr.select_font_face("JetBrainsMono Nerd Font", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        cr.set_font_size(8)
        cr.set_source_rgb(255/255, 255/255, 255/255)
        
        te = cr.text_extents(pct_text)
        tx = cx - (te.x_bearing + te.width / 2.0)
        ty = cy - (te.y_bearing + te.height / 2.0)
        cr.move_to(tx, ty)
        cr.show_text(pct_text)

        # Center label below circle
        lbl = self.label_text + "⚡" if (self.label_text == "BAT" and self.charging) else self.label_text
        cr.select_font_face("JetBrainsMono Nerd Font", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        cr.set_font_size(7.5)
        cr.set_source_rgb(160/255, 174/255, 192/255)
        
        te_lbl = cr.text_extents(lbl)
        lx = cx - (te_lbl.x_bearing + te_lbl.width / 2.0)
        ly = 45.0 - (te_lbl.y_bearing + te_lbl.height / 2.0)
        cr.move_to(lx, ly)
        cr.show_text(lbl)


class HeightAnimator:
    def __init__(self, window, start_h, end_h, duration_ms, on_step, on_complete):
        self.window = window
        self.start_h = start_h
        self.end_h = end_h
        self.duration = duration_ms / 1000.0
        self.on_step = on_step
        self.on_complete = on_complete
        self.start_time = time.time()
        self.timer_id = GLib.timeout_add(10, self.step)

    def step(self):
        elapsed = time.time() - self.start_time
        if elapsed >= self.duration:
            self.on_step(self.end_h, 1.0)
            self.on_complete()
            self.timer_id = None
            return False
            
        t = elapsed / self.duration
        # cubic ease-out
        t_eased = 1.0 - (1.0 - t) ** 3
        current_h = int(self.start_h + (self.end_h - self.start_h) * t_eased)
        self.on_step(current_h, t_eased)
        return True

    def cancel(self):
        if self.timer_id:
            GLib.source_remove(self.timer_id)
            self.timer_id = None


class DashboardWindow(Gtk.Window):
    def __init__(self, app):
        super().__init__()
        self.set_application(app)
        self.set_title("System Dashboard")
        
        # Force native Dark Mode
        settings = Gtk.Settings.get_default()
        settings.set_property("gtk-application-prefer-dark-theme", True)
        
        # Initialize Layer Shell
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        
        # KeyboardMode.NONE prevents the window from ever taking keyboard focus.
        # This makes it completely immune to SUPER+Q.
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.NONE)
        
        # Anchor to Top and Left to allow precise positioning under Waybar
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
        
        # Spacing from top (Waybar is typically ~30px height, so 38px puts it right below)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, 38)
        
        # Set initial size request
        self.set_default_size(380, 75)
        self.set_size_request(380, 75)

        self.vol_handler_id = None
        self.bright_handler_id = None
        self.is_updating_sliders = False
        
        # Interactive Lockouts for Sliders
        self.last_user_vol_change = 0
        self.last_user_bright_change = 0
        
        # Thread tracking
        self._metrics_thread_active = False
        self.slider_poll_interval = 0.15
        self.slider_thread_running = True

        # Timer IDs for dynamic polling
        self.metrics_timer_id = None
        self.clock_timer_id = None

        # Focus Mode Timer Variables
        self.focus_duration = 25 * 60
        self.focus_time_left = 25 * 60
        self.focus_active = False
        self.focus_timer_id = None

        # Adaptive CPU Polling Variables
        self.high_cpu_ticks = 0
        self.low_cpu_ticks = 0
        self.cpu_warning_active = False
        self.cpu_warning_time = ""
        self.cpu_warning_val = 0.0
        self.cpu_warning_reason = ""
        self._last_proc_time = 0
        self._last_proc_time_sec = 0.0

        # Memory Cache for metrics
        self.cached_data = None

        # Hover-to-expand state
        self.is_expanded = False
        self.is_expanding = False
        self.animator = None
        self.collapse_timer_id = None
        self.is_active_mode = False

        self._build_ui()
        
        self.connect("close-request", self._on_close_request)
        
        # Setup Hover Event Controller on the Window
        motion_controller = Gtk.EventControllerMotion()
        motion_controller.connect("enter", self._on_mouse_enter)
        motion_controller.connect("leave", self._on_mouse_leave)
        self.add_controller(motion_controller)

        # Start background slider thread
        threading.Thread(target=self._slider_polling_worker, daemon=True).start()
        
        # Start CPU usage monitoring every 5 seconds
        GLib.timeout_add(5000, self._check_cpu_usage)
        
        # Start initial updates (active state)
        self._setup_polling(active=True)
        
        # Setup initial position
        self.update_position()

    def _build_ui(self):
        # Create a Gtk.Overlay as the root child
        overlay = Gtk.Overlay()
        # CRITICAL: Prevent the overlay container from expanding to fill the screen
        overlay.set_valign(Gtk.Align.START)
        overlay.set_halign(Gtk.Align.START)
        self.set_child(overlay)

        # 1. MAIN BOX (Full Dashboard)
        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.main_box.add_css_class("main-card")
        self.main_box.set_visible(False) # Hidden initially
        self.main_box.set_valign(Gtk.Align.START)
        overlay.set_child(self.main_box)

        # Build full dashboard elements inside main_box
        # Header
        header_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        header_card.add_css_class("card")
        
        clock_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        self.time_label = Gtk.Label(label="00:00")
        self.time_label.add_css_class("clock-time")
        self.time_label.set_halign(Gtk.Align.START)
        
        self.date_label = Gtk.Label(label="Monday, Jan 1")
        self.date_label.add_css_class("clock-date")
        self.date_label.set_halign(Gtk.Align.START)
        
        clock_box.append(self.time_label)
        clock_box.append(self.date_label)
        header_card.append(clock_box)
        
        right_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        right_box.set_hexpand(True)
        right_box.set_halign(Gtk.Align.END)
        right_box.set_valign(Gtk.Align.CENTER)
        
        meta_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        user_lbl = Gtk.Label(label="User: Aditya")
        user_lbl.add_css_class("bold-text")
        user_lbl.set_halign(Gtk.Align.END)
        
        self.meta_label = Gtk.Label(label="Kernel: ...\nUptime: ...")
        self.meta_label.add_css_class("sub-text")
        self.meta_label.set_halign(Gtk.Align.END)
        
        meta_box.append(user_lbl)
        meta_box.append(self.meta_label)
        right_box.append(meta_box)
        
        btn_close = Gtk.Button(label="×")
        btn_close.add_css_class("close-btn")
        btn_close.set_valign(Gtk.Align.CENTER)
        btn_close.set_halign(Gtk.Align.CENTER)
        btn_close.connect("clicked", lambda x: self.hide_popup())
        right_box.append(btn_close)
        
        header_card.append(right_box)
        self.main_box.append(header_card)

        # CPU Warning Card
        self.warning_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.warning_card.add_css_class("card")
        self.warning_card.add_css_class("warning-card")
        self.warning_card.set_visible(False)
        
        self.warning_title = Gtk.Label(label="⚠️ Background Updates Paused")
        self.warning_title.add_css_class("bold-text")
        self.warning_title.set_halign(Gtk.Align.START)
        
        self.warning_text = Gtk.Label(label="Reason: High CPU\nPaused at: --")
        self.warning_text.add_css_class("sub-text")
        self.warning_text.set_halign(Gtk.Align.START)
        
        self.warning_card.append(self.warning_title)
        self.warning_card.append(self.warning_text)
        self.main_box.append(self.warning_card)

        # Content Stack
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.stack.set_transition_duration(250)
        self.stack.set_vexpand(True)
        self.main_box.append(self.stack)

        self._build_home_page()
        self._build_stats_page()
        self._build_manage_page()

        self.stack.add_titled(self.home_page, "home", "Home")
        self.stack.add_titled(self.stats_page, "stats", "Stats")
        self.stack.add_titled(self.manage_page, "manage", "Manage")

        # Bottom Nav Bar
        self.nav_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.nav_box.add_css_class("nav-bar")
        self.nav_box.set_homogeneous(True)
        
        self.btn_nav_home = Gtk.Button(label="🏠 Home")
        self.btn_nav_home.add_css_class("nav-btn")
        self.btn_nav_home.add_css_class("active")
        self.btn_nav_home.connect("clicked", lambda x: self._switch_page("home"))
        
        self.btn_nav_stats = Gtk.Button(label="📊 Stats")
        self.btn_nav_stats.add_css_class("nav-btn")
        self.btn_nav_stats.connect("clicked", lambda x: self._switch_page("stats"))
        
        self.btn_nav_manage = Gtk.Button(label="⚙️ Manage")
        self.btn_nav_manage.add_css_class("nav-btn")
        self.btn_nav_manage.connect("clicked", lambda x: self._switch_page("manage"))
        
        self.nav_box.append(self.btn_nav_home)
        self.nav_box.append(self.btn_nav_stats)
        self.nav_box.append(self.btn_nav_manage)
        self.main_box.append(self.nav_box)

        # 2. COMPACT CARD (Overlay Child)
        self.compact_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.compact_card.add_css_class("compact-card")
        self.compact_card.set_size_request(380, 75)
        self.compact_card.set_valign(Gtk.Align.START)
        self.compact_card.set_halign(Gtk.Align.START)
        
        # Left side: Arch Logo
        logo_label = Gtk.Label(label="󰣇")
        logo_label.add_css_class("arch-logo")
        logo_label.set_valign(Gtk.Align.CENTER)
        self.compact_card.append(logo_label)

        # Spacer
        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        self.compact_card.append(spacer)

        # Right side: 3 Circular Progress Indicators
        rings_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        rings_box.set_valign(Gtk.Align.CENTER)
        
        self.ring_cpu = CircularProgress("CPU")
        self.ring_ram = CircularProgress("RAM")
        self.ring_bat = CircularProgress("BAT")
        
        rings_box.append(self.ring_cpu)
        rings_box.append(self.ring_ram)
        rings_box.append(self.ring_bat)
        self.compact_card.append(rings_box)

        # Add compact_card to overlay
        overlay.add_overlay(self.compact_card)

    # PAGE BUILDERS
    def _build_home_page(self):
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_size_request(380, 340)
        self.home_page = scrolled

        home_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        scrolled.set_child(home_box)
        
        # Sliders Card (Volume, Brightness)
        sliders_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        sliders_card.add_css_class("card")
        
        s_title = Gtk.Label(label="System Settings")
        s_title.add_css_class("card-title")
        s_title.set_halign(Gtk.Align.START)
        sliders_card.append(s_title)
        
        # Volume
        vol_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        vol_icon = Gtk.Label(label="󰕾")
        vol_icon.set_size_request(24, -1)
        self.vol_scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=Gtk.Adjustment(value=0, lower=0, upper=100, step_increment=1, page_increment=10))
        self.vol_scale.set_hexpand(True)
        self.vol_scale.set_draw_value(False)
        self.vol_val_label = Gtk.Label(label="0%")
        self.vol_val_label.set_size_request(36, -1)
        
        vol_box.append(vol_icon)
        vol_box.append(self.vol_scale)
        vol_box.append(self.vol_val_label)
        sliders_card.append(vol_box)
        
        # Brightness
        bright_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        bright_icon = Gtk.Label(label="󰃠")
        bright_icon.set_size_request(24, -1)
        self.bright_scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=Gtk.Adjustment(value=0, lower=0, upper=100, step_increment=1, page_increment=10))
        self.bright_scale.set_hexpand(True)
        self.bright_scale.set_draw_value(False)
        self.bright_val_label = Gtk.Label(label="0%")
        self.bright_val_label.set_size_request(36, -1)
        
        bright_box.append(bright_icon)
        bright_box.append(self.bright_scale)
        bright_box.append(self.bright_val_label)
        sliders_card.append(bright_box)
        
        home_box.append(sliders_card)
        
        # Bind Slider Events
        self.vol_handler_id = self.vol_scale.connect("value-changed", self._on_volume_changed)
        self.bright_handler_id = self.bright_scale.connect("value-changed", self._on_brightness_changed)
        
        # Dedicated Battery Card
        bat_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        bat_card.add_css_class("card")
        self.bat_lbl = Gtk.Label(label="🔋 --%")
        self.bat_lbl.add_css_class("bold-text")
        self.bat_lbl.set_halign(Gtk.Align.START)
        self.bat_sub_lbl = Gtk.Label(label="--")
        self.bat_sub_lbl.add_css_class("sub-text")
        self.bat_sub_lbl.set_halign(Gtk.Align.START)
        
        bat_card.append(self.bat_lbl)
        bat_card.append(self.bat_sub_lbl)
        home_box.append(bat_card)
        
        # Dedicated Power Mode Card
        power_mode_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        power_mode_card.add_css_class("card")
        
        p_title = Gtk.Label(label="Power Mode")
        p_title.add_css_class("card-title")
        p_title.set_halign(Gtk.Align.START)
        power_mode_card.append(p_title)
        
        profile_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        profile_box.set_homogeneous(True)
        
        self.btn_profile_saver = Gtk.Button(label="Power Saver")
        self.btn_profile_saver.add_css_class("profile-btn")
        self.btn_profile_saver.connect("clicked", lambda x: self._set_power_profile("power-saver"))
        
        self.btn_profile_balanced = Gtk.Button(label="Balanced")
        self.btn_profile_balanced.add_css_class("profile-btn")
        self.btn_profile_balanced.connect("clicked", lambda x: self._set_power_profile("balanced"))
        
        self.btn_profile_perf = Gtk.Button(label="Performance")
        self.btn_profile_perf.add_css_class("profile-btn")
        self.btn_profile_perf.connect("clicked", lambda x: self._set_power_profile("performance"))
        
        profile_box.append(self.btn_profile_saver)
        profile_box.append(self.btn_profile_balanced)
        profile_box.append(self.btn_profile_perf)
        power_mode_card.append(profile_box)
        
        home_box.append(power_mode_card)
        
        # Focus Mode Card
        focus_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        focus_card.add_css_class("card")
        
        focus_title = Gtk.Label(label="󰈈 Focus Mode")
        focus_title.add_css_class("card-title")
        focus_title.set_halign(Gtk.Align.START)
        focus_card.append(focus_title)
        
        timer_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        
        self.focus_time_label = Gtk.Label(label="25:00")
        self.focus_time_label.set_markup("<span size='xx-large' weight='bold' foreground='#ffffff'>25:00</span>")
        self.focus_time_label.set_halign(Gtk.Align.START)
        
        adj = Gtk.Adjustment(value=25, lower=1, upper=180, step_increment=1, page_increment=5)
        self.focus_spin = Gtk.SpinButton(adjustment=adj, climb_rate=1, digits=0)
        self.focus_spin.set_valign(Gtk.Align.CENTER)
        self.focus_spin.set_halign(Gtk.Align.END)
        self.focus_spin.set_hexpand(True)
        self.focus_spin.connect("value-changed", self._on_focus_spin_changed)
        
        timer_row.append(self.focus_time_label)
        timer_row.append(self.focus_spin)
        focus_card.append(timer_row)
        
        controls_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.btn_focus_start = Gtk.Button(label="Start")
        self.btn_focus_start.set_hexpand(True)
        self.btn_focus_start.connect("clicked", self._on_focus_start_clicked)
        
        self.btn_focus_reset = Gtk.Button(label="Reset")
        self.btn_focus_reset.connect("clicked", self._on_focus_reset_clicked)
        
        controls_row.append(self.btn_focus_start)
        controls_row.append(self.btn_focus_reset)
        focus_card.append(controls_row)
        
        home_box.append(focus_card)

    def _build_stats_page(self):
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_size_request(380, 340)
        self.stats_page = scrolled
        
        stats_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        scrolled.set_child(stats_box)
        
        # Hardware Card
        hw_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        hw_card.add_css_class("card")
        
        # CPU
        cpu_title_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        cpu_lbl = Gtk.Label(label="CPU Utilization")
        cpu_lbl.add_css_class("bold-text")
        self.cpu_val = Gtk.Label(label="0%")
        self.cpu_val.set_hexpand(True)
        self.cpu_val.set_halign(Gtk.Align.END)
        cpu_title_box.append(cpu_lbl)
        cpu_title_box.append(self.cpu_val)
        self.cpu_bar = Gtk.LevelBar()
        hw_card.append(cpu_title_box)
        hw_card.append(self.cpu_bar)
        
        # Memory
        mem_title_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        mem_lbl = Gtk.Label(label="Memory Usage")
        mem_lbl.add_css_class("bold-text")
        self.mem_val = Gtk.Label(label="0%")
        self.mem_val.set_hexpand(True)
        self.mem_val.set_halign(Gtk.Align.END)
        mem_title_box.append(mem_lbl)
        mem_title_box.append(self.mem_val)
        self.mem_bar = Gtk.LevelBar()
        hw_card.append(mem_title_box)
        hw_card.append(self.mem_bar)
        
        # GPU
        gpu_title_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        gpu_lbl = Gtk.Label(label="GPU Utilization")
        gpu_lbl.add_css_class("bold-text")
        self.gpu_val = Gtk.Label(label="0%")
        self.gpu_val.set_hexpand(True)
        self.gpu_val.set_halign(Gtk.Align.END)
        gpu_title_box.append(gpu_lbl)
        gpu_title_box.append(self.gpu_val)
        self.gpu_bar = Gtk.LevelBar()
        self.gpu_sub_label = Gtk.Label(label="Intel Iris Graphics")
        self.gpu_sub_label.add_css_class("sub-text")
        self.gpu_sub_label.set_halign(Gtk.Align.START)
        hw_card.append(gpu_title_box)
        hw_card.append(self.gpu_bar)
        hw_card.append(self.gpu_sub_label)
        
        stats_box.append(hw_card)
        
        # Storage Card
        storage_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        storage_card.add_css_class("card")
        s_title = Gtk.Label(label="Storage Drives")
        s_title.add_css_class("card-title")
        s_title.set_halign(Gtk.Align.START)
        storage_card.append(s_title)
        
        self.storage_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.storage_box.set_size_request(-1, 80)
        storage_card.append(self.storage_box)
        stats_box.append(storage_card)
        
        # Network Card
        net_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        net_card.add_css_class("card")
        n_title = Gtk.Label(label="Network Info")
        n_title.add_css_class("card-title")
        n_title.set_halign(Gtk.Align.START)
        net_card.append(n_title)
        
        net_grid = Gtk.Grid()
        net_grid.set_column_spacing(12)
        net_grid.set_row_spacing(6)
        
        self.net_iface_val = Gtk.Label(label="--")
        self.net_iface_val.set_halign(Gtk.Align.START)
        self.net_iface_val.set_ellipsize(Pango.EllipsizeMode.END)
        self.net_iface_val.set_max_width_chars(10)
        
        self.net_ssid_val = Gtk.Label(label="--")
        self.net_ssid_val.set_halign(Gtk.Align.START)
        self.net_ssid_val.set_ellipsize(Pango.EllipsizeMode.END)
        self.net_ssid_val.set_max_width_chars(12)
        
        net_grid.attach(Gtk.Label(label="Iface:", xalign=0.0), 0, 0, 1, 1)
        net_grid.attach(self.net_iface_val, 1, 0, 1, 1)
        net_grid.attach(Gtk.Label(label="SSID:", xalign=0.0), 2, 0, 1, 1)
        net_grid.attach(self.net_ssid_val, 3, 0, 1, 1)
        
        self.net_ip_val = Gtk.Label(label="--")
        self.net_ip_val.set_halign(Gtk.Align.START)
        self.net_ip_val.set_ellipsize(Pango.EllipsizeMode.END)
        self.net_ip_val.set_max_width_chars(14)
        
        self.net_mac_val = Gtk.Label(label="--")
        self.net_mac_val.set_halign(Gtk.Align.START)
        self.net_mac_val.set_ellipsize(Pango.EllipsizeMode.END)
        self.net_mac_val.set_max_width_chars(17)
        self.net_mac_val.add_css_class("mono-text")
        
        net_grid.attach(Gtk.Label(label="IP:", xalign=0.0), 0, 1, 1, 1)
        net_grid.attach(self.net_ip_val, 1, 1, 1, 1)
        net_grid.attach(Gtk.Label(label="MAC:", xalign=0.0), 2, 1, 1, 1)
        net_grid.attach(self.net_mac_val, 3, 1, 1, 1)
        
        self.net_gw_val = Gtk.Label(label="--")
        self.net_gw_val.set_halign(Gtk.Align.START)
        self.net_gw_val.set_ellipsize(Pango.EllipsizeMode.END)
        self.net_gw_val.set_max_width_chars(14)
        
        self.net_dns_val = Gtk.Label(label="--")
        self.net_dns_val.set_halign(Gtk.Align.START)
        self.net_dns_val.set_ellipsize(Pango.EllipsizeMode.END)
        self.net_dns_val.set_max_width_chars(14)
        
        net_grid.attach(Gtk.Label(label="Gateway:", xalign=0.0), 0, 2, 1, 1)
        net_grid.attach(self.net_gw_val, 1, 2, 1, 1)
        net_grid.attach(Gtk.Label(label="DNS:", xalign=0.0), 2, 2, 1, 1)
        net_grid.attach(self.net_dns_val, 3, 2, 1, 1)
        
        self.net_ping_val = Gtk.Label(label="--")
        self.net_ping_val.set_halign(Gtk.Align.START)
        self.net_ping_val.set_ellipsize(Pango.EllipsizeMode.END)
        self.net_ping_val.set_max_width_chars(10)
        
        net_grid.attach(Gtk.Label(label="Ping:", xalign=0.0), 0, 3, 1, 1)
        net_grid.attach(self.net_ping_val, 1, 3, 1, 1)
        
        net_card.append(net_grid)
        stats_box.append(net_card)

    def _build_manage_page(self):
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_size_request(380, 340)
        self.manage_page = scrolled
        
        manage_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        scrolled.set_child(manage_box)
        
        # Processes Card
        proc_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        proc_card.add_css_class("card")
        proc_title = Gtk.Label(label="Top Processes")
        proc_title.add_css_class("card-title")
        proc_title.set_halign(Gtk.Align.START)
        proc_card.append(proc_title)
        
        self.proc_list_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.proc_list_box.set_size_request(-1, 130)
        proc_card.append(self.proc_list_box)
        manage_box.append(proc_card)
        
        # Logs Card
        logs_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        logs_card.add_css_class("card")
        logs_title = Gtk.Label(label="System Logs")
        logs_title.add_css_class("card-title")
        logs_title.set_halign(Gtk.Align.START)
        logs_card.append(logs_title)
        
        self.logs_list_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.logs_list_box.set_size_request(-1, 200)
        logs_card.append(self.logs_list_box)
        manage_box.append(logs_card)

    # DYNAMIC POLLING & FOCUS HANDLERS
    def _setup_polling(self, active=True, paused=False):
        if self.metrics_timer_id:
            GLib.source_remove(self.metrics_timer_id)
            self.metrics_timer_id = None
        if self.clock_timer_id:
            GLib.source_remove(self.clock_timer_id)
            self.clock_timer_id = None

        self.clock_timer_id = GLib.timeout_add(1000, self._update_clock_callback)
        self._update_clock()

        if paused:
            return

        if active or self.is_active_mode:
            self.metrics_timer_id = GLib.timeout_add(500, self._update_metrics_callback)
            self._trigger_async_metrics()
        else:
            self.metrics_timer_id = GLib.timeout_add(3000, self._update_metrics_callback)

    def _update_clock_callback(self):
        self._update_clock()
        return True

    def _update_metrics_callback(self):
        self._trigger_async_metrics()
        return True

    def _update_clock(self):
        now = time.localtime()
        self.time_label.set_label(time.strftime("%H:%M", now))
        self.date_label.set_label(time.strftime("%A, %B %d", now))

    def _trigger_async_metrics(self):
        if not self._metrics_thread_active:
            self._metrics_thread_active = True
            threading.Thread(target=self._metrics_worker, daemon=True).start()

    def _metrics_worker(self):
        try:
            data = {
                "system": system_coll.get_data(),
                "cpu": cpu_coll.get_data(),
                "memory": mem_coll.get_data(),
                "gpu": gpu_coll.get_data(),
                "storage": storage_coll.get_data(),
                "network": net_coll.get_data(),
                "battery": battery_coll.get_data(),
                "processes": proc_coll.get_data(),
                "logs": log_coll.get_data(),
            }
            self.cached_data = data
            GLib.idle_add(self._apply_metrics, data)
        except Exception as e:
            print(f"Error collecting metrics in thread: {e}", file=sys.stderr)
        finally:
            self._metrics_thread_active = False

    def _apply_metrics(self, data):
        if not data:
            return
            
        # System
        sys_data = data["system"]
        self.meta_label.set_label(f"Kernel: {sys_data.get('kernel')}\nUptime: {sys_data.get('uptime')}")
        
        # CPU
        cpu_data = data["cpu"]
        self.cpu_val.set_label(f"{cpu_data.get('utilization')}%  ({cpu_data.get('frequency')} MHz)")
        self.cpu_bar.set_value(cpu_data.get('utilization') / 100.0)
        self.ring_cpu.set_value(cpu_data.get('utilization') / 100.0)
        
        # Memory
        mem_data = data["memory"]
        to_gb = lambda b: b / (1024 * 1024 * 1024)
        self.mem_val.set_label(f"{mem_data.get('utilization')}%  ({to_gb(mem_data.get('used')):.1f}/{to_gb(mem_data.get('total')):.1f} GB)")
        self.mem_bar.set_value(mem_data.get('utilization') / 100.0)
        self.ring_ram.set_value(mem_data.get('utilization') / 100.0)
        
        # Battery Ring
        bat_data = data["battery"]
        if bat_data.get("present"):
            pct = bat_data.get('percentage', 0)
            status = bat_data.get('status', '')
            is_charging = "charging" in status.lower()
            self.ring_bat.set_value(pct / 100.0)
            self.ring_bat.set_charging(is_charging)
        else:
            self.ring_bat.set_value(0.0)
            self.ring_bat.set_charging(False)
        
        # GPU
        gpu_data = data["gpu"]
        self.gpu_val.set_label(f"{gpu_data.get('utilization')}%")
        self.gpu_bar.set_value(gpu_data.get('utilization') / 100.0)
        self.gpu_sub_label.set_label(f"{gpu_data.get('model')}  |  {gpu_data.get('frequency', '')}")
        
        # Battery
        bat_data = data["battery"]
        if bat_data.get("present"):
            self.bat_lbl.set_label(f"🔋 {bat_data.get('percentage')}% ({bat_data.get('status')})")
            self.bat_sub_lbl.set_label(bat_data.get('remaining', '--'))
        else:
            self.bat_lbl.set_label("🔋 N/A")
            self.bat_sub_lbl.set_label("No battery detected")
            
        # Power Profile
        profile = bat_data.get('profile', 'balanced')
        self._update_profile_buttons_ui(profile)
        
        # Storage
        self._update_storage_ui(data["storage"].get('drives', []))
        
        # Network
        net_data = data["network"]
        self.net_iface_val.set_label(net_data.get('interface', '--'))
        self.net_ssid_val.set_label(net_data.get('wifi_ssid', '--'))
        self.net_ip_val.set_label(net_data.get('local_ip', '--'))
        self.net_mac_val.set_label(net_data.get('mac', '--'))
        self.net_gw_val.set_label(net_data.get('gateway', '--'))
        
        dns_list = net_data.get('dns', [])
        self.net_dns_val.set_label(dns_list[0] if dns_list else '--')
        self.net_ping_val.set_label(net_data.get('ping', 'N/A'))
        
        # Processes
        self._update_processes_ui(data["processes"].get('processes', []))
        
        # Logs
        self._update_logs_ui(data["logs"].get('logs', []))

    def _update_storage_ui(self, drives):
        while child := self.storage_box.get_first_child():
            self.storage_box.remove(child)
            
        for d in drives[:2]:
            row = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            row.add_css_class("list-item")
            
            lbl_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
            lbl_mnt = Gtk.Label(label=d['mount_point'])
            lbl_mnt.add_css_class("bold-text")
            lbl_stats = Gtk.Label(label=f"{d['utilization']}% ({d['used']}/{d['size']})")
            lbl_stats.set_hexpand(True)
            lbl_stats.set_halign(Gtk.Align.END)
            
            lbl_box.append(lbl_mnt)
            lbl_box.append(lbl_stats)
            
            bar = Gtk.LevelBar()
            bar.set_value(d['utilization'] / 100.0)
            
            row.append(lbl_box)
            row.append(bar)
            self.storage_box.append(row)

    def _update_processes_ui(self, processes):
        while child := self.proc_list_box.get_first_child():
            self.proc_list_box.remove(child)
            
        top_procs = sorted(processes, key=lambda p: p['cpu'], reverse=True)[:4]
        
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        header.add_css_class("list-item")
        
        lbl_pid = Gtk.Label(label="PID")
        lbl_pid.set_size_request(50, -1)
        lbl_pid.set_halign(Gtk.Align.START)
        lbl_pid.add_css_class("sub-text")
        
        lbl_name = Gtk.Label(label="Process")
        lbl_name.set_hexpand(True)
        lbl_name.set_halign(Gtk.Align.START)
        lbl_name.add_css_class("sub-text")
        
        lbl_cpu = Gtk.Label(label="CPU%")
        lbl_cpu.set_size_request(40, -1)
        lbl_cpu.set_halign(Gtk.Align.END)
        lbl_cpu.add_css_class("sub-text")
        
        header.append(lbl_pid)
        header.append(lbl_name)
        header.append(lbl_cpu)
        self.proc_list_box.append(header)
        
        for p in top_procs:
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            row.add_css_class("list-item")
            
            pid_lbl = Gtk.Label(label=str(p['pid']))
            pid_lbl.set_size_request(50, -1)
            pid_lbl.set_halign(Gtk.Align.START)
            pid_lbl.add_css_class("mono-text")
            
            name_lbl = Gtk.Label(label=p['name'])
            name_lbl.set_hexpand(True)
            name_lbl.set_halign(Gtk.Align.START)
            name_lbl.set_ellipsize(Pango.EllipsizeMode.END)
            
            cpu_lbl = Gtk.Label(label=f"{p['cpu']:.1f}%")
            cpu_lbl.set_size_request(40, -1)
            cpu_lbl.set_halign(Gtk.Align.END)
            cpu_lbl.add_css_class("bold-text")
            
            row.append(pid_lbl)
            row.append(name_lbl)
            row.append(cpu_lbl)
            self.proc_list_box.append(row)

    def _update_logs_ui(self, logs):
        while child := self.logs_list_box.get_first_child():
            self.logs_list_box.remove(child)
            
        for log in logs[:4]:
            row = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
            row.add_css_class("list-item")
            
            lbl_meta = Gtk.Label(label=f"[{log['time']}] {log['process']}:")
            lbl_meta.add_css_class("bold-text")
            lbl_meta.add_css_class("mono-text")
            lbl_meta.set_halign(Gtk.Align.START)
            
            lbl_msg = Gtk.Label(label=log['message'])
            lbl_msg.set_halign(Gtk.Align.START)
            lbl_msg.set_wrap(True)
            lbl_msg.set_max_width_chars(45)
            lbl_msg.add_css_class("mono-text")
            
            if log['priority'] <= 3:
                lbl_meta.set_markup(f"<span foreground='#e74c3c'>[{log['time']}] {log['process']}:</span>")
            elif log['priority'] == 4:
                lbl_meta.set_markup(f"<span foreground='#f39c12'>[{log['time']}] {log['process']}:</span>")
            
            row.append(lbl_meta)
            row.append(lbl_msg)
            self.logs_list_box.append(row)

    # BACKGROUND SLIDER POLLING & APPLY VALUES
    def _slider_polling_worker(self):
        while self.slider_thread_running:
            vol = self._get_system_volume()
            bright = self._get_system_brightness()
            GLib.idle_add(self._apply_slider_values, vol, bright)
            time.sleep(self.slider_poll_interval)

    def _get_system_volume(self):
        try:
            res = subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], capture_output=True, text=True)
            out = res.stdout.strip()
            if "MUTED" in out:
                return 0
            else:
                parts = out.split()
                return int(float(parts[1]) * 100) if len(parts) >= 2 else 0
        except Exception:
            return 0

    def _get_system_brightness(self):
        try:
            cur = int(subprocess.run(["brightnessctl", "g"], capture_output=True, text=True).stdout.strip())
            mx = int(subprocess.run(["brightnessctl", "m"], capture_output=True, text=True).stdout.strip())
            return int(cur / mx * 100) if mx > 0 else 0
        except Exception:
            return 0

    def _apply_slider_values(self, vol_pct, bright_pct):
        now = time.time()
        if now - self.last_user_vol_change > 1.0:
            self.is_updating_sliders = True
            self.vol_scale.handler_block(self.vol_handler_id)
            self.vol_scale.set_value(vol_pct)
            self.vol_scale.handler_unblock(self.vol_handler_id)
            self.vol_val_label.set_label(f"{vol_pct}%")
            self.is_updating_sliders = False
            
        if now - self.last_user_bright_change > 1.0:
            self.is_updating_sliders = True
            self.bright_scale.handler_block(self.bright_handler_id)
            self.bright_scale.set_value(bright_pct)
            self.bright_scale.handler_unblock(self.bright_handler_id)
            self.bright_val_label.set_label(f"{bright_pct}%")
            self.is_updating_sliders = False

    def _on_volume_changed(self, scale):
        if self.is_updating_sliders:
            return
        val = int(scale.get_value())
        self.vol_val_label.set_label(f"{val}%")
        self.last_user_vol_change = time.time()
        def worker():
            subprocess.run(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", f"{val/100:.2f}"])
        threading.Thread(target=worker, daemon=True).start()

    def _on_brightness_changed(self, scale):
        if self.is_updating_sliders:
            return
        val = int(scale.get_value())
        self.bright_val_label.set_label(f"{val}%")
        self.last_user_bright_change = time.time()
        def worker():
            subprocess.run(["brightnessctl", "set", f"{val}%"])
        threading.Thread(target=worker, daemon=True).start()

    # FOCUS MODE TIMER EVENT HANDLERS
    def _on_focus_spin_changed(self, spin):
        if not self.focus_active:
            mins = int(spin.get_value())
            self.focus_duration = mins * 60
            self.focus_time_left = self.focus_duration
            self._update_focus_display()

    def _update_focus_display(self):
        mins = self.focus_time_left // 60
        secs = self.focus_time_left % 60
        self.focus_time_label.set_markup(f"<span size='xx-large' weight='bold' foreground='#ffffff'>{mins:02d}:{secs:02d}</span>")

    def _on_focus_start_clicked(self, btn):
        if self.focus_active:
            self.focus_active = False
            self.btn_focus_start.set_label("Resume")
            self.focus_spin.set_sensitive(True)
            if self.focus_timer_id:
                GLib.source_remove(self.focus_timer_id)
                self.focus_timer_id = None
        else:
            self.focus_active = True
            self.btn_focus_start.set_label("Pause")
            self.focus_spin.set_sensitive(False)
            self.focus_timer_id = GLib.timeout_add(1000, self._focus_tick)

    def _on_focus_reset_clicked(self, btn):
        self.focus_active = False
        self.btn_focus_start.set_label("Start")
        self.focus_spin.set_sensitive(True)
        if self.focus_timer_id:
            GLib.source_remove(self.focus_timer_id)
            self.focus_timer_id = None
        
        mins = int(self.focus_spin.get_value())
        self.focus_duration = mins * 60
        self.focus_time_left = self.focus_duration
        self._update_focus_display()

    def _focus_tick(self):
        if not self.focus_active:
            return False
            
        if self.focus_time_left > 0:
            self.focus_time_left -= 1
            self._update_focus_display()
            return True
        else:
            self.focus_active = False
            self.btn_focus_start.set_label("Start")
            self.focus_spin.set_sensitive(True)
            self.focus_timer_id = None
            self._update_focus_display()
            subprocess.run(["notify-send", "-u", "critical", "Focus Mode", "Time's up! Your focus session has finished."])
            return False

    # ADAPTIVE CPU POLLING MONITOR
    def _check_cpu_usage(self):
        cpu_usage = self._get_process_cpu_usage()
        
        if cpu_usage > 5.0:
            self.high_cpu_ticks += 1
            self.low_cpu_ticks = 0
        else:
            self.low_cpu_ticks += 1
            self.high_cpu_ticks = 0
            
        if self.high_cpu_ticks >= 3 and not self.cpu_warning_active:
            self.cpu_warning_active = True
            self.cpu_warning_time = time.strftime("%H:%M")
            self.cpu_warning_val = cpu_usage
            self.cpu_warning_reason = f"High CPU utilisation ({cpu_usage:.1f}%)"
            
            self._setup_polling(active=self.is_visible(), paused=True)
            self._update_warning_ui()
            
        elif self.low_cpu_ticks >= 3 and self.cpu_warning_active:
            self.cpu_warning_active = False
            self._setup_polling(active=self.is_visible(), paused=False)
            self._update_warning_ui()
            
        return True

    def _get_process_cpu_usage(self):
        try:
            with open("/proc/self/stat", "r") as f:
                stat = f.readline().split()
            utime = int(stat[13])
            stime = int(stat[14])
            total_time = utime + stime
            
            now = time.time()
            if self._last_proc_time > 0:
                time_diff = now - self._last_proc_time_sec
                ticks_diff = total_time - self._last_proc_time
                ticks_per_sec = os.sysconf(os.sysconf_names['SC_CLK_TCK'])
                num_cpus = os.cpu_count() or 1
                
                if time_diff > 0:
                    cpu_usage = (ticks_diff / ticks_per_sec) / time_diff / num_cpus * 100.0
                    self._last_proc_time = total_time
                    self._last_proc_time_sec = now
                    return cpu_usage
            
            self._last_proc_time = total_time
            self._last_proc_time_sec = now
            return 0.0
        except Exception:
            return 0.0

    def _update_warning_ui(self):
        if self.cpu_warning_active:
            self.warning_text.set_label(
                f"Reason: {self.cpu_warning_reason}\n"
                f"Paused at: {self.cpu_warning_time}"
            )
            self.warning_card.set_visible(True)
        else:
            self.warning_card.set_visible(False)

    # NAVIGATION SWITCHER
    def _switch_page(self, name):
        self.stack.set_visible_child_name(name)
        
        self.btn_nav_home.remove_css_class("active")
        self.btn_nav_stats.remove_css_class("active")
        self.btn_nav_manage.remove_css_class("active")
        
        if name == "home":
            self.btn_nav_home.add_css_class("active")
        elif name == "stats":
            self.btn_nav_stats.add_css_class("active")
        elif name == "manage":
            self.btn_nav_manage.add_css_class("active")

    # ACTIONS
    def _run_action(self, action):
        confirm_actions = ["shutdown", "reboot"]
        if action in confirm_actions:
            dialog = Gtk.MessageDialog(
                transient_for=self,
                modal=True,
                message_type=Gtk.MessageType.WARNING,
                buttons=Gtk.ButtonsType.OK_CANCEL,
                text=f"Are you sure you want to {action}?"
            )
            
            def response_cb(d, response_id):
                d.destroy()
                if response_id == Gtk.ResponseType.OK:
                    self._execute_action_cmd(action)
            
            dialog.connect("response", response_cb)
            dialog.present()
        else:
            self._execute_action_cmd(action)

    def _execute_action_cmd(self, action):
        if action == "lock":
            subprocess.Popen(["hyprlock"])
        elif action == "suspend":
            subprocess.Popen(["systemctl", "suspend"])
        elif action == "reboot":
            subprocess.Popen(["systemctl", "reboot"])
        elif action == "shutdown":
            subprocess.Popen(["systemctl", "poweroff"])

    # POWER PROFILE SWITCHER & SEGMENTED CONTROLS
    def _set_power_profile(self, profile_name):
        def worker():
            subprocess.run(["powerprofilesctl", "set", profile_name])
            GLib.idle_add(self._update_profile_buttons_ui, profile_name)
            
        threading.Thread(target=worker, daemon=True).start()

    def _update_profile_buttons_ui(self, active_profile):
        self.btn_profile_saver.remove_css_class("active")
        self.btn_profile_balanced.remove_css_class("active")
        self.btn_profile_perf.remove_css_class("active")
        
        if active_profile == "power-saver":
            self.btn_profile_saver.add_css_class("active")
        elif active_profile == "balanced":
            self.btn_profile_balanced.add_css_class("active")
        elif active_profile == "performance":
            self.btn_profile_perf.add_css_class("active")

    def _on_destroy(self, window):
        self.slider_thread_running = False

    def _on_close_request(self, window):
        self.hide_popup()
        return True

    # Hover Handlers
    def _on_mouse_enter(self, controller, x, y):
        # Cancel pending collapse
        if self.collapse_timer_id:
            GLib.source_remove(self.collapse_timer_id)
            self.collapse_timer_id = None

        if self.is_expanded or self.is_expanding:
            return

        self.is_expanding = True
        self.is_active_mode = True
        
        if self.animator:
            self.animator.cancel()

        self.main_box.set_visible(True)
        self.main_box.set_opacity(0.0)

        start_h = 75
        end_h = 450

        def on_step(h, t):
            self.set_size_request(380, h)
            self.compact_card.set_opacity(1.0 - t)
            self.main_box.set_opacity(t)

        def on_complete():
            self.compact_card.set_visible(False)
            self.is_expanded = True
            self.is_expanding = False
            self.animator = None

        self.animator = HeightAnimator(self, start_h, end_h, 200, on_step, on_complete)

    def _on_mouse_leave(self, controller):
        if self.collapse_timer_id:
            GLib.source_remove(self.collapse_timer_id)
            
        self.collapse_timer_id = GLib.timeout_add(350, self._trigger_collapse)

    def _trigger_collapse(self):
        self.collapse_timer_id = None

        if not self.is_expanded and not self.is_expanding:
            return

        self.is_expanded = False
        self.is_expanding = False
        self.is_active_mode = False
        
        if self.animator:
            self.animator.cancel()

        self.compact_card.set_visible(True)
        self.compact_card.set_opacity(0.0)

        start_h = 450
        end_h = 75

        def on_step(h, t):
            self.set_size_request(380, h)
            self.compact_card.set_opacity(t)
            self.main_box.set_opacity(1.0 - t)

        def on_complete():
            self.main_box.set_visible(False)
            self.animator = None

        self.animator = HeightAnimator(self, start_h, end_h, 200, on_step, on_complete)
        return False

    # Popup Toggle Interface
    def show_popup(self):
        self.is_expanded = False
        self.is_expanding = False
        self.set_size_request(380, 75)
        self.compact_card.set_visible(True)
        self.compact_card.set_opacity(1.0)
        self.main_box.set_visible(False)
        self.main_box.set_opacity(0.0)
        
        self.present()
        self._setup_polling(active=True)

    def hide_popup(self):
        if self.collapse_timer_id:
            GLib.source_remove(self.collapse_timer_id)
            self.collapse_timer_id = None
        if self.animator:
            self.animator.cancel()
            self.animator = None
            
        self.hide()
        self._setup_polling(active=False)

    # Position Calculator based on Active Monitor & Cursor Position
    def update_position(self):
        try:
            # Get cursor position (Waybar button clicked)
            res = subprocess.run(["hyprctl", "cursorpos"], capture_output=True, text=True)
            cursor_x, cursor_y = map(int, res.stdout.strip().split(","))
            
            # Get monitor info to clamp
            res_mon = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True)
            monitors = json.loads(res_mon.stdout)
            focused_mon = next((m for m in monitors if m.get("focused")), monitors[0])
            mon_width = focused_mon.get("width", 1920)
            mon_x = focused_mon.get("x", 0)
            scale = focused_mon.get("scale", 1.0)
            
            # Calculate target_x relative to the monitor
            local_cursor_x = (cursor_x - mon_x) / scale
            target_x = int(local_cursor_x - 190)
            
            # Clamp target_x so the 380px wide popup stays fully on screen
            max_x = int((mon_width / scale) - 380 - 12)
            target_x = max(12, min(target_x, max_x))
        except Exception as e:
            print(f"Error calculating popup position: {e}", file=sys.stderr)
            target_x = 12 # fallback
            
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, target_x)


class DashboardApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="com.system.dashboard", flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.window = None

    def do_activate(self):
        if not self.window:
            # Apply CSS styling
            css_provider = Gtk.CssProvider()
            css_provider.load_from_string(CSS_DATA)
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

            self.window = DashboardWindow(self)
            self.window.show_popup()
        else:
            if self.window.is_visible():
                self.window.hide_popup()
            else:
                self.window.update_position()
                if self.window.cached_data:
                    self.window._apply_metrics(self.window.cached_data)
                self.window.show_popup()

if __name__ == "__main__":
    app = DashboardApp()
    app.run(sys.argv)
