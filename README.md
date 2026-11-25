# Floaty

A tiny, cute drawing overlay for your Mac. Floaty floats on top of every window so you can scribble, highlight, and write notes right over your screen, then switch back to using your apps with one shortcut. Your drawings stay put until you clear them.

## Features

- **Pencil, eraser and text** tools
- **Any color** from the color picker, with your 3 most recent colors one click away (remembered between launches)
- **Adjustable size** for the pen, eraser and text
- **Click-through mode**: drawings stay visible while you use your apps normally
- **Works on every display**, even when you plug in or unplug monitors
- **Undo** and **Clear all**
- Lives in the menu bar (no Dock icon) and needs no special permissions

## Shortcuts

| Keys | What it does |
|---|---|
| Control + Option + D | Turn drawing on/off from any app |
| Esc | Stop drawing (clicks go back to your apps) |
| P / E / T | Pencil / Eraser / Text |
| [ / ] | Smaller / bigger |
| Cmd + Z | Undo |

To add text, choose the text tool, click where you want it, type, and press Return.

## Install

Floaty is built from source. It takes about a minute.

1. Install Apple's free developer tools (one time only). Open Terminal and run:
   ```
   xcode-select --install
   ```
2. Download this project: click the green **Code** button above, then **Download ZIP**, and unzip it.
3. In Terminal, go to the unzipped folder and build it:
   ```
   cd ~/Downloads/Floaty-main
   bash build.sh
   open Floaty.app
   ```
4. Optional: drag **Floaty.app** into your Applications folder to keep it.

Requires macOS 12 (Monterey) or later.

## What's in here

- `Floaty.swift`: the whole app
- `build.sh`: compiles the app and packages it as `Floaty.app`
- `make_icon.swift`: draws the app icon (only runs if `AppIcon.icns` is missing)
- `AppIcon.icns`: the app icon
