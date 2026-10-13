# Call Clock

A small floating Mac clock for pacing calls in five-minute sections.
The perimeter fills clockwise every five minutes, then starts again.
The middle shows completed loops and your current local time.

Double-click **Launch.command** to build and open it, or run `./build.sh` and
open `build/Call Clock.app`. Building requires Apple's command-line tools.

Drag the clock to move it. Hover to show pause, restart, and close controls.
Restart begins a new call at zero loops. The clock keeps looping after five
repetitions, and stays above other windows, including full-screen spaces.
Closing the window quits the app. Each launch starts a fresh timer.
