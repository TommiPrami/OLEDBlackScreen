# OLEDBlackScreen

A screensaver-like app that protects OLED screens from burn-in (without blocking the system screensaver the way a static image would).

## Work heavily in progress

The idea is to keep the display black while still preventing the system from sleeping or starting its own screensaver.

Starts minimized to the tray. (So when you launch it, it looks like nothing happens - that might change later.)

### Usage:
  - The black screen covers every monitor, taskbar included, and hides the mouse cursor. The cursor comes back as soon as you move the mouse or press Shift, Ctrl, Alt or Win.
  - Dismiss the black screen: press any other key, click, or move the mouse far enough. The key press is swallowed, so it never reaches the program you were working in, and that program keeps the keyboard focus. Volume, media and browser keys are left alone.
  - Right-click the black screen or the tray icon for the menu (pause, settings, exit). Picking a pause also dismisses the black screen.

### Settings:
Right-click the tray icon and choose **Settings...** (or double-click the tray icon):
  - **User idle time** - how long you have to be idle before the black screen kicks in
  - **Mouse move distance** / **Mouse move reset time** - how much mouse movement it takes to dismiss the black screen
  - **Prevent-locking schedule** - by default the app keeps the computer from locking around the clock. Check one or more weekdays to limit that to those days only, and optionally give a start and/or end time to narrow it to a window (e.g. Mon-Fri 07:00-15:15). The end time is exclusive: an end of 15:15 lets the computer lock at 15:15. A start with no end runs until midnight; an end with no start runs from 00:00. A start later than the end is an overnight window (e.g. 22:00-06:00) that begins on the checked day and ends the next morning. Outside the window the black screen still shows, but it no longer keeps Windows from locking.
  - **Lock the computer when the schedule ends** - optional. When the no-lock window closes, the app locks the workstation - but only once you have been idle for the configured number of seconds (default 30), so it never locks while you are mid-sentence or moving the mouse. For the rest of that day the computer is also locked whenever the black screen comes on, so it does not stay open after you have unlocked it once, or when you start the computer after the window.

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
- ~~Cover every monitor~~
- ...
