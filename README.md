# baseview

A low-level windowing system geared towards making audio plugin UIs.

`baseview` abstracts the platform-specific windowing APIs (winapi, cocoa, xcb) into a platform-independent API, but otherwise gets out of your way so you can write plugin UIs.

This is a fork of [RustAudio/baseview](https://github.com/RustAudio/baseview) carrying a fix for Pro Tools (AAX) unload / multi-editor crashes on macOS — see [Pro Tools (AAX) fix](#pro-tools-aax-fix) below.

## Prerequisites

### Linux

Install dependencies, e.g.:

```sh
sudo apt-get install libx11-dev libxcb1-dev libx11-xcb-dev libgl1-mesa-dev
```

## Pro Tools (AAX) fix

Upstream baseview on macOS crashes Pro Tools the moment a plugin editor is closed (or another plugin's editor is opened, which closes the first). This section describes the crash we actually observed, why it happens, and the minimal patch that fixes it.

### Crash signature

```
Thread 0 Crashed:: Main Thread Dispatch queue: com.apple.main-thread
0  libobjc.A.dylib                 objc_msgSend + 56
1  DFW                             -[DFW_NSContainer dealloc] + 56
2  libobjc.A.dylib                 AutoreleasePoolPage::releaseUntil
3  libobjc.A.dylib                 objc_autoreleasePoolPop + 244
4  DFW                             -[DFW_NSApplication sendEvent:] + 2016
5  AppKit                          -[NSApplication _handleEvent:]
6  AppKit                          -[NSApplication run]
7  DFW                             DFW_EventLoop::RunApplicationEventLoop
```

`EXC_BAD_ACCESS` with invalid addresses that varied between runs — `0x0`, `0x5`, `0x6`, `0x0f007fffffffffc0`. The address changes every time, which is the classic signature of dereferencing a freed object whose memory has been reused for unrelated data.

The crash happens deep inside Pro Tools' own event dispatch: `sendEvent:` holds an outer autorelease pool, plugin code runs inside it (our `close()` is called from that event), the pool drains after the event handler returns, and one of the autoreleased objects — always a `DFW_NSContainer` (Avid's private subclass of `NSView`) — tries to message one of its ivars during dealloc. The ivar's pointer is stale: it references an object we destroyed during plugin close.

### Root cause

When baseview's `WindowInner::close()` tears the view down it calls `removeFromSuperview` and then `release`. That is not enough.

While the view was attached, AppKit and the host embedded it in several back-referencing registries that **are not** cleared by `removeFromSuperview`:

- **Window first responder.** Our view can become first responder (it handles keyboard events and overrides `acceptsFirstResponder` to `YES`). `NSWindow.firstResponder` is a raw pointer; on the OS versions Pro Tools ships on it isn't always zeroing-weak, and even where it is, some hosts query or keep a parallel reference.
- **Tracking-area registry.** Baseview creates an `NSTrackingArea` with `owner: self` and adds it to the view. AppKit keeps the tracking area alive; its `owner` back-pointer to our view is not cleared by normal view teardown.
- **Layer contents.** If the view is layer-backed (wgpu via a `CAMetalLayer`, CoreGraphics blit via `setContents:`), the layer holds an image that in turn holds references into the view's rendering context.

Pro Tools' `DFW_NSContainer` — the container view Pro Tools wraps around the plugin embedding area — walks one of these registries during its own dealloc and messages what is now a freed pointer. Because the crash happens inside Pro Tools' outer pool drain, every host framework (CLAP, VST3 on other DAWs) that doesn't wrap plugin events in their own pools this way is unaffected. It's specific to the AAX + DFW shape.

The JUCE sources do the equivalent cleanup inside `NSViewComponentPeer::~NSViewComponentPeer`.

### The fix

`src/macos/window.rs`, inside `WindowInner::close()`, before `removeFromSuperview` + `release`:

1. Wrap the body in a local `NSAutoreleasePool` and drain it at the end. Any ObjC object we autorelease during teardown gets released **here**, not in the host's outer pool.
2. `[window makeFirstResponder: nil]` if we're a responder.
3. Enumerate `view.trackingAreas` and `removeTrackingArea:` each one.
4. `[view.layer setContents: nil]` to drop the layer's image.

That's the whole patch — about 35 added lines in a single file. See the `git diff` vs upstream master.

## License

Licensed under either of <a href="LICENSE-APACHE">Apache License, Version 2.0</a> or <a href="LICENSE-MIT">MIT license</a> at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in Baseview by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
