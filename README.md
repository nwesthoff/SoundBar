# BarAudioSource

A macOS menu bar app that keeps your default audio device on the device *you* want, instead of whatever macOS most recently noticed.

You define an ordered priority list for outputs and a separate one for inputs. Whenever a device is connected or disconnected — or when System Settings (or any other app) changes the default — BarAudioSource picks the highest-priority connected device and snaps the system default back to it.

Disconnected devices stay in the priority list and resume their slot when they reappear.

## Why

macOS happily makes any newly-detected device the default: an external monitor's HDMI speakers when you plug in the cable, a Bluetooth headset that auto-reconnects, the iPhone someone just hooked up to charge. If you'd rather decide once and have the system follow your preference, this app does that.

## Requirements

- macOS 26.1 or later
- Xcode 26.1+ to build

## Build & run

```sh
xcodebuild -project BarAudioSource.xcodeproj \
           -scheme BarAudioSource \
           -configuration Debug \
           -derivedDataPath build \
           build

open build/Build/Products/Debug/BarAudioSource.app
```

The app has no dock icon — look for a speaker icon in the menu bar.

## Usage

Click the speaker icon to open the popover. Two sections, **Output** and **Input**, each with:

- A priority list (top = highest preference). Reorder with the up/down chevrons. Disconnected entries are dimmed and italicized but kept.
- An *Available* list of connected devices that aren't yet in the priority list. Click `+` to add.
- The currently active device for the section is shown next to the section header and marked with a check.

Footer controls:

- **Pause enforcement** — temporarily stop snapping the default back. Useful when you want to pick something manually and not have it overridden.
- **Launch at login** — register the app as a login item via `SMAppService`. The first time you flip this on, macOS may prompt you to authorize it in System Settings.
- **Quit** — ⌘Q.

## What gets driven

When a higher-priority device becomes available (or someone changes the default away from it), BarAudioSource sets all three of:

- the system default output device (what apps play through),
- the system default *system* output device (alerts/UI sounds),
- the system default input device.

Output and system output share the output priority list; input has its own.

## Device identity

Devices are matched across reconnects by their CoreAudio UID (`kAudioDevicePropertyDeviceUID`). For very old devices that don't expose a UID, the app falls back to a name-based match.

## App Sandbox

The App Sandbox is **disabled** for this target. Setting the system default audio device requires writing to a `kAudioObject` property on the system object, which the standard sandbox does not permit and for which Apple does not publish an entitlement. Distribution outside the App Store is fine without sandbox; hardened runtime is unaffected.

## Project layout

```
BarAudioSource/
  BarAudioSourceApp.swift            # @main, MenuBarExtra
  CoreAudio/                          # CoreAudio HAL wrapper + listeners
  Domain/                             # AudioDevice, PriorityList, resolver
  State/                              # PriorityStore (UserDefaults), AudioCoordinator, LoginItemController
  UI/                                 # PopoverRoot, ScopeSection, DeviceRow, FooterControls
```

`AudioCoordinator` is the single place that decides what the default should be: it reacts to device-set changes, default-changed events, and priority-list edits, then runs an idempotent `enforce()` pass per scope.
