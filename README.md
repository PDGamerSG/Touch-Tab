# Touch-Tab

![Touch-Tab AppSwitcher](https://user-images.githubusercontent.com/511242/185958284-e0f962aa-3f88-4d95-9176-3f3fe49a24c8.gif)

Switch apps with trackpad on macOS.
Use 3-fingers swipe right or 3-fingers swipe left to switch between apps.
Hold after the swipe or swipe slowly to show App Switcher UI.

This is a maintained fork of [ris58h/Touch-Tab](https://github.com/ris58h/Touch-Tab). Want to support the original author? [Buy me a coffee](https://www.buymeacoffee.com/ris58h).

## Installation
1. Download the [latest](https://github.com/PDGamerSG/Touch-Tab/releases/latest/download/Touch-Tab.zip) `Touch-Tab.zip` from [Releases](https://github.com/PDGamerSG/Touch-Tab/releases) page.
2. Unzip the archive and move `Touch-Tab.app` into the `Applications` folder.
3. The app is ad-hoc signed so when you run the app macOS will warn you: `"Touch-Tab" can’t be opened because Apple cannot check it for malicious software`. Right-click the app and click `Open`, a 
pop-up will appear, click `Open` again.
4. The app needs access to global trackpad events. Allow Touch-Tab to control your computer in `System Settings > Privacy & Security > Accessibility`. If you had Touch-Tab installed before you may need to remove Touch-Tab from the `Accessibility` list first and add it again.
5. Disable 3-finger swipe between full-screen apps or make it 4-finger in `System Settings > Trackpad > More Gestures > Swipe between full-screen apps`. If you switch Touch-Tab to 4 fingers, make that system gesture 3-finger or disable it instead.

## Usage
- Use 3-fingers swipe right or 3-fingers swipe left to switch between apps.
- Hold after the swipe or swipe slowly to show App Switcher UI. Pro tip: you can use 2-fingers scroll to switch apps in App Switcher faster.

### Settings
All settings are in the status bar menu:
- `Swipe With` - use 3 or 4 fingers. 4 fingers is handy if you use 3-finger drag or 3-finger swipes for something else.
- `Haptic Feedback` - a trackpad click on every app switch (Force Touch trackpads only).
- `Restore Minimized Windows` - unminimize windows of the selected app.
- `Launch at Login` - start Touch-Tab automatically (macOS 13 and later).

### Hide Status Bar Item
Holding ⌘ drag the item away from the status bar until you see ✖️ (cross icon) then let it go. To recover the item just open the app one more time.

## Troubleshooting
### "Touch-Tab" can’t be opened because Apple cannot check it for malicious software
Right-click the app and click `Open`, a pop-up will appear, click `Open` again.
### It's running but doesn't work
- Check that Touch-Tab is allowed to control your computer in `System Settings > Privacy & Security > Accessibility`.  If you had Touch-Tab installed before you may need to remove Touch-Tab from the `Accessibility` list first and add it again.
- Check that 3-finger swipe is disabled in `System Settings > Trackpad > More Gestures > Swipe between full-screen apps`.
### It stops working after sleep
Touch-Tab recreates its trackpad listener after wake and checks it every couple of seconds, so it recovers by itself. If it still doesn't respond, quit and relaunch it and please create an issue.
### It still doesn't work
Please create an [issue](https://github.com/PDGamerSG/Touch-Tab/issues).

## Building
Open `Touch-Tab.xcodeproj` in Xcode and run, or build from the command line:
```sh
xcodebuild -project Touch-Tab.xcodeproj -target Touch-Tab -configuration Release SYMROOT="$PWD/build" CODE_SIGN_IDENTITY=- build
```
The app is at `build/Release/Touch-Tab.app`. Every push is built by GitHub Actions, and pushing a `v*` tag publishes a release with `Touch-Tab.zip`.

## Changes in this fork
- 3-finger swipe no longer scrolls the content under the cursor ([ris58h#1](https://github.com/ris58h/Touch-Tab/issues/1)).
- Swiping right opens App Switcher reliably: Command is held for the whole gesture like a real keyboard would ([ris58h#26](https://github.com/ris58h/Touch-Tab/issues/26)).
- Works after long sleep: the event tap is recreated on wake and monitored while running ([ris58h#28](https://github.com/ris58h/Touch-Tab/issues/28)).
- Accessibility permission revoked or granted while running is handled without a restart.
- A thumb resting on the trackpad no longer breaks the gesture.
- 4-finger option ([ris58h#30](https://github.com/ris58h/Touch-Tab/issues/30), [ris58h#12](https://github.com/ris58h/Touch-Tab/issues/12)).
- Launch at Login ([ris58h#7](https://github.com/ris58h/Touch-Tab/issues/7)).
- Haptic feedback ([ris58h#8](https://github.com/ris58h/Touch-Tab/issues/8)).
- Restore minimized windows ([ris58h#11](https://github.com/ris58h/Touch-Tab/issues/11)).
- Fixed a crash when reopening the About window.
