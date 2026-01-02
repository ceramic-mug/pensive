# Pensive - Native macOS Distraction-Free Writing App

This is a modern, native remake of the Pensive web prototype using SwiftUI and AppKit.

## Features
- **Premium Native Experience**: Smooth, high-performance text editing with custom `NSTextView`.
- **Typewriter Mode**: Keeps your cursor centered vertically as you type.
- **Unicode Lookup**: Press `/` anywhere in the editor to search and insert symbols like `→`, `§`, or `©`.
- **Themes**: Light, Dark, and Sepia modes with adaptive typography.
- **Distraction Free**: Hide all UI elements for a focused writing environment.
- **Notes Sidebar**: Keep snippets and outlines close by.
- **Native File I/O**: Standard macOS Save/Load dialogs.

## How to Run
1. Open the `/Users/joshua/Desktop/pensive` folder in **Xcode**.
2. Xcode will automatically recognize the `Package.swift` file.
3. Select the **Pensive** target and a **macOS** destination.
4. Press **Cmd + R** to build and run.

Alternatively, via Terminal:
```bash
cd /Users/joshua/Desktop/pensive
swift run
```
