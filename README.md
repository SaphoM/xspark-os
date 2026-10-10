# X Spark OS

A Mac-style desktop transformation for [Omarchy](https://github.com/omarchy/omarchy) (Hyprland-based Linux). Replaces the top bar with a macOS-style menu bar, adds an Apple-menu-style dropdown, an App Exposé overview, a Control Center widget, and hairline HiDPI borders.

## What's inside

```
config/shell.json            Omarchy user config: top bar layout, plugin registry (xspark.*)
config/shell.toml            Theme overrides: hairline menu border (0.5), 20% menu translucency
plugins/
  macbar                     macOS-style menu bar (bar plugin)
  macbar.apple               Apple icon widget — toggles the Apple menu dropdown
  macbar.controlcenter       Control Center widget
  menu                       Apple menu clone (menu plugin), anchored top-left under the Apple icon
  overview                   App Exposé (macOS-style card row of an app's windows, drag-free)
  winbuttons                 Traffic-light window controls (minimize / maximize / close) on every window
  agentnotes                 Invisible, draggable menu bar over the agent window (org.omarchy.agent): session title + working project name, + add task, per-project task list
mac-mode/
  hyprland/                  Hyprland config (bindings, windows, gestures, looknfeel, input)
  shell/                     mac-mode shell layout + bar
  scripts/                   install/toggle/backup/restore + mac gestures (app expose, ...)
  theme/                     Color themes (mac-light, mac-dark, xspark-branded)
bin/omarchy-menu             CLI shim for the menu (toggle/summon/close/refresh), resolves to the active menu plugin
bin/sync-version             Set every plugin manifest's version to the repo's commit count
bin/session-restore          Reopen windows after reboot/power loss; snapshots cwd + commands, resumes the agent session
bin/xspark-system-reboot     Apple-menu reboot: save session state, checkpoint opencode, then omarchy-system-reboot
bin/xspark-system-shutdown   Same for shutdown, then omarchy-system-shutdown
```

## Install

1. Copy the plugin dirs into your Omarchy user plugins:

   ```sh
   cp -r plugins/macbar plugins/macbar.apple plugins/macbar.controlcenter plugins/menu plugins/overview plugins/winbuttons plugins/agentnotes \
     ~/.config/omarchy/plugins/
   ```

2. Merge `config/shell.json` into `~/.config/omarchy/shell.json` (that file also references `omadock`, a separate upstream dock — install it from its own repository or drop the entry).

3. Copy `config/shell.toml` to `~/.config/omarchy/shell.toml` (optional: hairline border + translucency).

4. Install the mac-mode layer (Hyprland config + scripts):

   ```sh
   mac-mode/scripts/install.sh
   ```

5. Add the CLI shims to your PATH (or copy `bin/omarchy-menu`, `bin/session-restore`, `bin/xspark-system-reboot`, `bin/xspark-system-shutdown` to `~/.local/bin/`).

6. Restart the shell: `/usr/share/omarchy/bin/omarchy-restart-shell`.

## Versioning

Plugin manifests use the repo's **commit count** as their version (`"version": "21"`), not semver. It is derived, not hand-maintained: `bin/sync-version` writes the count into every `manifest.json`, and the pre-commit hook (`scripts/githooks/pre-commit`, wired with `git config core.hooksPath scripts/githooks`) runs it with `HEAD + 1`, so each commit ships with a version equal to its own number. Fresh clone: the hook is already in-tree, just re-run `git config core.hooksPath scripts/githooks`.

## Session restore & reboot

- `session-restore track` (started from `~/.config/hypr/autostart.lua`) snapshots every open window — class, workspace, cwd and full argv — and reopens them after a restart, hibernate, power cut or reboot. Snapshots are debounced (~3s after the last window event) so the close-all in a graceful reboot can't wipe the saved state before Hyprland exits.
- Each window is reopened in its original cwd. The agent window (`org.omarchy.agent`) is no longer excluded: it relaunches with `opencode --auto -c`, which resumes the most recent session for that directory, so the last conversation is still there after the machine dies. A saved `--prompt` is stripped so a reboot can never re-fire an old prompt unattended.
- The Apple menu's **Restart…** / **Shut Down…** run `xspark-system-reboot` / `xspark-system-shutdown`: they take a synchronous `session-restore save` and a best-effort `wal_checkpoint(PASSIVE)` on `opencode.db` (so recent messages survive a power cut), then hand off to the stock `omarchy-system-reboot` / `omarchy-system-shutdown` for the graceful window close.

## Notes

- **Apps menu**: the platform injects `shell.appLibrary` only for first-party menu plugins. The cloned menu owned by a third-party id receives a null bridge (a platform gap), so `plugins/menu/Menu.qml` falls back to a private `AppLibrary` instance, and keeps the injected one when/if the shell supplies it.
- **Hairline borders**: on HiDPI (scale 2) a 1px border renders as 2 device pixels, so the menu border is `0.5` logical px (1 device px). Hyprland `general:border_size` is integer-only, so windows use `1`.
- **QML edits**: hot reload / `rescanPlugins` serve a stale compiled cache for keep-loaded plugins; do a full shell restart after editing `Menu.qml`.
- **Plugin file edits**: copying into `~/.config/omarchy/plugins/` triggers an async hot reload; restarting the shell (`omarchy-restart-shell`) while that reload is in flight crashed quickshell twice on 2026-10-08 — pause ~1s between copying and restarting.

## License

The bundled plugin files retain their original licenses. mac-mode scripts and configs are provided as-is for personal use.