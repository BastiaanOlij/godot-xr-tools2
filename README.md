# Godot XR Tools v2 Demo

This is the demo branch of the XR Tools v2 Godot plugin that shows you how you can incorporate XR Tools v2 into your project.
It is recommended to install the Godot OpenXR Vendor plugin, this is not included by default.

This is just a place holder, to be continued...

## Spectator view

This demo includes a spectator view solution.
On PCVR platforms (Windows, Linux, MacOS) Godot can output something separate to the desktop monitor while the wearer of the headset sees the first person stereo output.
This works by loading the `spectator.tscn` scene instead of the default `main.tscn` scene (which is included and rendered to a SubViewport in the spectator system).

> [!NOTE]
> Using a Linux ARM64 build for devices such as the Steam Frame, we also get separate output to the "desktop".
> The spectator system is thus also used here however this output is only shown when the user opens the system menu.
> To prevent overhead, we apply a `minimum_spectator` feature tag that results in a lower resolution output and
> a simplified view.

## Licensing

Code in this repository is licensed under the MIT license.
Images are licensed under CC0 unless otherwise specified.

See `LICENSE` for the full license.
