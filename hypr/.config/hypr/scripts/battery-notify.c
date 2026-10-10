#include <fcntl.h>
#include <gio/gio.h>
#include <glib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <time.h>
#include <unistd.h>

// Global State Variables
GDBusConnection *session_bus = NULL;
GDBusConnection *system_bus = NULL;
char *battery_path = NULL;

double percentage = 100.0;
gboolean on_battery = TRUE;

// Low-battery warnings: exactly one notification per threshold per discharge.
// A threshold re-arms once the battery goes back above it.
static const int LOW_THRESHOLDS[] = {25, 15, 10, 5};
#define NUM_LOW_THRESHOLDS                                                     \
  (int)(sizeof(LOW_THRESHOLDS) / sizeof(LOW_THRESHOLDS[0]))
gboolean low_notified[sizeof(LOW_THRESHOLDS) / sizeof(LOW_THRESHOLDS[0])] = {
    FALSE};

// "You may unplug" notice: exactly one notification per charging session.
static const double HIGH_THRESHOLD = 95.0;
gboolean high_notified = FALSE;

void log_msg(const char *message) {
  time_t rawtime;
  struct tm *timeinfo;
  char buffer[80];

  time(&rawtime);
  timeinfo = localtime(&rawtime);

  strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", timeinfo);
  printf("[%s] battery-notify: %s\n", buffer, message);
  fflush(stdout);
}

// Helper: discover battery path
char *find_battery_path(GDBusConnection *conn) {
  GError *error = NULL;
  GVariant *result = g_dbus_connection_call_sync(
      conn, "org.freedesktop.UPower", "/org/freedesktop/UPower",
      "org.freedesktop.UPower", "EnumerateDevices", NULL,
      G_VARIANT_TYPE("(ao)"), G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);

  if (error) {
    g_printerr("Error enumerating UPower devices: %s\n", error->message);
    g_error_free(error);
    return NULL;
  }

  GVariantIter *iter;
  g_variant_get(result, "(ao)", &iter);
  char *path = NULL;
  char *discovered_path = NULL;
  while (g_variant_iter_loop(iter, "o", &path)) {
    if (strstr(path, "battery_") != NULL) {
      discovered_path = g_strdup(path);
      break;
    }
  }
  g_variant_iter_free(iter);
  g_variant_unref(result);
  return discovered_path;
}

// Helper: get a D-Bus property value
GVariant *get_property(GDBusConnection *conn, const char *dest,
                       const char *path, const char *interface,
                       const char *prop_name) {
  GError *error = NULL;
  GVariant *result = g_dbus_connection_call_sync(
      conn, dest, path, "org.freedesktop.DBus.Properties", "Get",
      g_variant_new("(ss)", interface, prop_name), G_VARIANT_TYPE("(v)"),
      G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);

  if (error) {
    g_printerr("Error getting property %s on %s: %s\n", prop_name, path,
               error->message);
    g_error_free(error);
    return NULL;
  }

  GVariant *inner_variant;
  g_variant_get(result, "(v)", &inner_variant);
  g_variant_unref(result);
  return inner_variant;
}

// Helper: send desktop notification via D-Bus Notify
guint32 send_notification(const char *summary, const char *body,
                          guint8 urgency_level) {
  GError *error = NULL;

  // Create urgency hint
  GVariantBuilder hints_builder;
  g_variant_builder_init(&hints_builder, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&hints_builder, "{sv}", "urgency",
                        g_variant_new_byte(urgency_level));
  GVariant *hints = g_variant_builder_end(&hints_builder);

  // Create empty actions array
  GVariantBuilder actions_builder;
  g_variant_builder_init(&actions_builder, G_VARIANT_TYPE("as"));
  GVariant *actions = g_variant_builder_end(&actions_builder);

  GVariant *params = g_variant_new("(susss@as@a{sv}i)",
                                   "Battery Monitor", // app_name
                                   (guint32)0,        // replaces_id
                                   "",                // app_icon
                                   summary, body, actions, hints,
                                   (gint32)20000 // expire_timeout (20 seconds)
  );

  GVariant *result = g_dbus_connection_call_sync(
      session_bus, "org.freedesktop.Notifications",
      "/org/freedesktop/Notifications", "org.freedesktop.Notifications",
      "Notify", params, G_VARIANT_TYPE("(u)"), G_DBUS_CALL_FLAGS_NONE, -1, NULL,
      &error);

  if (error) {
    g_printerr("Error sending notification: %s\n", error->message);
    g_error_free(error);
    return 0;
  }

  guint32 notif_id = 0;
  g_variant_get(result, "(u)", &notif_id);
  g_variant_unref(result);
  return notif_id;
}

// Send the one low-battery warning for the threshold we just crossed
void notify_low(void) {
  char summary[128];
  char log_buf[256];

  snprintf(summary, sizeof(summary), "Low Battery (%d%%)", (int)percentage);
  snprintf(log_buf, sizeof(log_buf), "Sending low battery notification: %s",
           summary);
  log_msg(log_buf);

  send_notification(summary, "Please plug in your charger.", 1);
}

// Send the one "charged" notice of this charging session
void notify_high(void) {
  char summary[128];
  char log_buf[256];

  snprintf(summary, sizeof(summary), "Battery Charged (%d%%)", (int)percentage);
  snprintf(log_buf, sizeof(log_buf), "Sending charged battery notification: %s",
           summary);
  log_msg(log_buf);

  send_notification(
      summary, "You may unplug the charger to preserve battery health.", 1);
}

// Decide whether the new battery state warrants a notification
void update_cycle(void) {
  int i, j;

  if (on_battery) {
    // Unplugged: the 95% notice may fire once again on the next charge
    high_notified = FALSE;

    for (i = 0; i < NUM_LOW_THRESHOLDS; i++) {
      int threshold = LOW_THRESHOLDS[i];

      if (percentage > threshold) {
        // Back above the threshold: re-arm it
        low_notified[i] = FALSE;
      } else if (!low_notified[i]) {
        low_notified[i] = TRUE;
        notify_low();

        // The level jumped several thresholds at once (e.g. at startup):
        // skip the ones just passed instead of firing several notifications.
        for (j = i + 1; j < NUM_LOW_THRESHOLDS; j++) {
          if (percentage <= LOW_THRESHOLDS[j]) {
            low_notified[j] = TRUE;
          }
        }
        break;
      }
    }
  } else if (percentage >= HIGH_THRESHOLD && !high_notified) {
    // Plugged in and at 95%: notify once per charging session
    high_notified = TRUE;
    notify_high();
  }
}

// D-Bus Signal Callback for UPower properties changed
void on_properties_changed(GDBusConnection *connection, const char *sender_name,
                           const char *object_path, const char *interface_name,
                           const char *signal_name, GVariant *parameters,
                           gpointer user_data) {
  const char *iface;
  GVariant *changed_properties = NULL;
  GVariant *invalidated_properties = NULL;

  g_variant_get(parameters, "(&s@a{sv}@as)", &iface, &changed_properties,
                &invalidated_properties);

  gboolean state_changed = FALSE;

  GVariantIter iter;
  g_variant_iter_init(&iter, changed_properties);
  const char *key;
  GVariant *value;
  while (g_variant_iter_next(&iter, "{&sv}", &key, &value)) {
    if (strcmp(object_path, "/org/freedesktop/UPower") == 0 &&
        strcmp(iface, "org.freedesktop.UPower") == 0) {
      if (strcmp(key, "OnBattery") == 0) {
        on_battery = g_variant_get_boolean(value);
        state_changed = TRUE;
      }
    } else if (strcmp(object_path, battery_path) == 0 &&
               strcmp(iface, "org.freedesktop.UPower.Device") == 0) {
      if (strcmp(key, "Percentage") == 0) {
        percentage = g_variant_get_double(value);
        state_changed = TRUE;
      }
    }
    g_variant_unref(value);
  }

  g_variant_unref(changed_properties);
  g_variant_unref(invalidated_properties);

  if (state_changed) {
    update_cycle();
  }
}

// Acquire single instance lock
gboolean acquire_lock(void) {
  const char *lock_dir = g_get_user_runtime_dir();
  if (lock_dir == NULL || access(lock_dir, F_OK) != 0) {
    lock_dir = "/tmp";
  }

  char lock_path[512];
  snprintf(lock_path, sizeof(lock_path), "%s/battery-notify.lock", lock_dir);

  int fd = open(lock_path, O_WRONLY | O_CREAT, 0600);
  if (fd < 0) {
    return FALSE;
  }

  struct flock fl;
  fl.l_type = F_WRLCK;
  fl.l_whence = SEEK_SET;
  fl.l_start = 0;
  fl.l_len = 0;

  if (fcntl(fd, F_SETLK, &fl) < 0) {
    close(fd);
    return FALSE;
  }

  return TRUE;
}

int main(int argc, char *argv[]) {
  // 1. Single Instance Lock
  if (!acquire_lock()) {
    return 0; // Exit silently
  }

  log_msg("Initializing battery notification daemon (C version)");

  GError *error = NULL;

  // 2. Connect to D-Bus
  session_bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
  if (error) {
    g_printerr("Failed to connect to Session Bus: %s\n", error->message);
    g_error_free(error);
    return 1;
  }

  system_bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, &error);
  if (error) {
    g_printerr("Failed to connect to System Bus: %s\n", error->message);
    g_error_free(error);
    return 1;
  }

  // 3. Discover battery device
  battery_path = find_battery_path(system_bus);
  if (!battery_path) {
    g_printerr("battery-notify: no battery detected\n");
    return 1;
  }

  char log_buf[256];
  snprintf(log_buf, sizeof(log_buf), "Discovered battery device: %s",
           battery_path);
  log_msg(log_buf);

  // Get initial values
  GVariant *on_bat_var = get_property(system_bus, "org.freedesktop.UPower",
                                      "/org/freedesktop/UPower",
                                      "org.freedesktop.UPower", "OnBattery");
  if (on_bat_var) {
    on_battery = g_variant_get_boolean(on_bat_var);
    g_variant_unref(on_bat_var);
  }

  GVariant *perc_var =
      get_property(system_bus, "org.freedesktop.UPower", battery_path,
                   "org.freedesktop.UPower.Device", "Percentage");
  if (perc_var) {
    percentage = g_variant_get_double(perc_var);
    g_variant_unref(perc_var);
  }

  snprintf(log_buf, sizeof(log_buf),
           "Initial State: Percentage=%.1f%%, OnBattery=%s", percentage,
           on_battery ? "True" : "False");
  log_msg(log_buf);

  // If we start up plugged in and already at/above 95%, don't announce it:
  // the notice is for the moment the battery crosses 95.
  if (!on_battery && percentage >= HIGH_THRESHOLD) {
    high_notified = TRUE;
  }

  // 4. Subscribe to UPower property changes
  g_dbus_connection_signal_subscribe(
      system_bus, "org.freedesktop.UPower", "org.freedesktop.DBus.Properties",
      "PropertiesChanged", NULL, NULL, G_DBUS_SIGNAL_FLAGS_NONE,
      on_properties_changed, NULL, NULL);

  // Initial state update
  update_cycle();

  // 5. Run GLib Main Loop
  GMainLoop *loop = g_main_loop_new(NULL, FALSE);
  g_main_loop_run(loop);

  // Cleanup
  g_free(battery_path);
  g_main_loop_unref(loop);

  return 0;
}
