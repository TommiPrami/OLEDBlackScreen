# OLEDBlackScreen

A screensaver-like app that protects OLED screens from burn-in (without blocking the system screensaver the way a static image would).

## Work heavily in progress

The idea is to keep the display black while still preventing the system from sleeping or starting its own screensaver.

Starts minimized to the tray. (So when you launch it, it looks like nothing happens - that might change later.)

### Usage:
  - Dismiss the black screen: **Esc**, any letter or space, **Ctrl+X** / **Ctrl+Z**, or just move or click the mouse
  - Quit: **Alt+F4** (or **Exit** from the tray menu)
  - Right-click the tray icon for the menu (settings, pause, exit)

### Settings:
Right-click the tray icon and choose **Settings...** (or double-click the tray icon):
  - **User idle time** - how long you have to be idle before the black screen kicks in
  - **Mouse move distance** / **Mouse move reset time** - how much mouse movement it takes to dismiss the black screen
  - **Prevent-locking schedule** - by default the app keeps the computer from locking around the clock. Check one or more weekdays to limit that to those days only, and optionally give a start and/or end time to narrow it to a window (e.g. Mon-Fri 07:00-15:15). A start with no end runs until 23:59; an end with no start runs from 00:00. This only affects the lock-blocking, never the OLED black screen.
  - **Lock the computer when the schedule ends** - optional. When the no-lock window closes, the app locks the workstation - but only once you have been idle for the configured number of seconds (default 30), so it never locks while you are mid-sentence or moving the mouse.

### TODO:
- ~~Make installer, needs tweaking~~
- ~~Add pause functionality~~
- ~~Tray icon menu~~
- ~~Most likely a right-click menu~~
- ~~Fix tray icon (showed only black)~~
- ~~Some kind of settings screen~~
  - ~~Saving and using settings~~
  - ~~Configurable timeouts etc.~~
  - ~~Schedule for the prevent-locking feature (weekdays + time window)~~
- ...
