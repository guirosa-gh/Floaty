# Floaty

**Floaty** is a tiny drawing toolbar for your Mac that floats on top of everything on your screen.

I'm a creative leader, and I made it because I kept wanting to doodle over apps, websites and slides during remote calls with teammates and clients. Sometimes I need to circle something to give feedback; other times I just want to sketch a quick wireframe. Not every video call tool lets you draw, so Floaty sits on top of your screen and works with any of them. Share your screen, press a shortcut, and start sketching. Press it again and you're back to clicking around normally, with your drawings still in place until you clear them.

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
