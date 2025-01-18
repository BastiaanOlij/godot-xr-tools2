# Godot XR Tools v2 (XRT2)

> **WARNING:** This repo is still a Work in Progress, this toolkit is still missing many features from [Godot XR Tools v1](https://github.com/godotvr/godot-xr-tools) and is short on documentation.
> If you've found yourself here early, be aware that things may and will drastically change as we deside the way forward.
> You may find yourself having to make large changes to anything you build using the toolkit.
> This is by no stretch of the imagination production ready.
> If you're looking for a toolkit with which to release a game, you should use [Godot XR Tools v1](https://github.com/godotvr/godot-xr-tools).
> 
> Check the demo branch for a demo showcasing current features.
>
> While under early development this repository is hosted on my personal GitHub space.

This repository contains a number of support files and support scenes that can be used together with the various AR and VR interfaces for the Godot game engine.

![GitHub forks](https://img.shields.io/github/forks/BastiaanOlij/godot-xr-tools2?style=plastic)
![GitHub Repo stars](https://img.shields.io/github/stars/BastiaanOlij/godot-xr-tools2?style=plastic)
![GitHub contributors](https://img.shields.io/github/contributors/BastiaanOlij/godot-xr-tools2?style=plastic)
![GitHub](https://img.shields.io/github/license/BastiaanOlij/godot-xr-tools2?style=plastic)

## Versions

> Godot XR Tools 2 is a from the ground up rewrite of Godot XR Tools applying what we've learned in the last 7 years or so.
> Version numbering has been reset for this rewrite.
> It is still catching up feature wise.
> You can find Godot XR Tools (1) [here](https://github.com/GodotVR/godot-xr-tools).

Official releases are tagged and can be found [here](https://github.com/BastiaanOlij/godot-xr-tools2/releases).

The following branches are in active development:

|  Branch   |  Description                  |  Godot version  |
|-----------|-------------------------------|-----------------|
|  master   | Current development branch    |  Godot 4.4+     |
|  demo     | Demo project for XRT2         |  Godot 4.4+     |

> Note, this repo is temporarily hosted on https://github.com/BastiaanOlij but will be moved to https://github.com/GodotVR once we're closer to a stable release.

## How to use

Documentation for this plugin will become available at a later date when the plugin is more complete.
For now check out [the demo branch](https://github.com/BastiaanOlij/godot-xr-tools2/tree/demo) in this repository.

## Requirements

Due to the introduction of UIDs and format changes to some of the resources used for OpenXR, the minimum version of Godot that needs to be used for this plugin is Godot 4.4.

## Installation

> **WARNING** At this point in time there are no stable releases of this plugin yet.
> Some of the information presented below only applies once a stable release is available.

### Godot Asset Library

Stable releases of this plugin can be found in the Godot Asset Library which is accessible from inside of the Godot IDE.
Simply search for `Godot XR Tools 2`, download the plugin and install it.

### GIT

If you use git for source control of your project, you can submodule Godot XR Tools 2. Godot XR Tools 2 must be placed in a specific location.
Open a command prompt and in the root of your Godot project execute:

```
mkdir addons
cd addons
git submodule add https://github.com/BastiaanOlij/godot-xr-tools2
```

If you require a specific version of this plugin, cd into the `godot-xr-tools2` folder and use `git checkout` to switch to the correct tag or commit.

### Downloading from Github

You can download a stable release from the releases page or use the download option in the `<> Code` dropdown menu on the main Github page.

Manually create the `addons/godot-xr-tools2` folder in your project and unzip the contents of Godot XR Tools 2 into that folder. 

## Upgrading from Godot XR Tools v1

> **WARNING** as we're not even close to feature parity, it is highly advisible to only use XR Tools v2 for new projects for now.

Godot XR Tools 2 is **not** a drop in replacement for Godot XR Tools and if you have a project that far along we recommend not upgrading as you will need to do major refactoring.

If you do wish to go down this route, install Godot XR Tools 2 alongside Godot XR Tools 1 and migrate your scenes over one by one.

While Godot XR Tools 2 builds ontop of the implementations in Godot XR Tools 1 there is a fundamental difference in approach.
Godot XR Tools 1 relies heavily on inheritence and require you to extend scenes.
Godot XR Tools 2 uses composition where you add XR nodes to your scenes to enable functionality.

This enabled Godot XR Tools 2 to be used even if you develop in another language than GDScript.

## Upgrading to a new version of this plugin

When upgrading this plugin to a newer v2 version, simply replace the contents of the `addons/godot-xr-tools2` folder with the new version.
If you've submoduled the plugin, simply pull a new version by executing:
```
cd addons/godot-xr-tools2
git pull origin main
```

> It's best to do this when Godot is NOT running!
> We recommend deleting the `.godot/uid_cache.bin` file before starting Godot again.
> We've had problems in the past of Godot retaining incorrect UIDs of the plugin. 

## Demo

This repository contains a demo project that can be found in [the demo branch](https://github.com/BastiaanOlij/godot-xr-tools2/tree/demo).
A full project can be downloaded from the releases page.

To obtain the latest version we recommend using git from the command line, this will pull in submodules correctly:
```
git clone -b demo --recurse-submodules https://github.com/BastiaanOlij/godot-xr-tools2
```

## Licensing

Code in this repository is licensed under the MIT license.
Images are licensed under CC0 unless otherwise specified.

See `LICENSE` for the full license.

### Complying with the license

If you use Godot XR Tools 2 in your project, this license must be accessible to your end users either by reproducing it in a credits/about screen or included as a distributed file.

## About this repository

This repository is primarily maintained by:
- [Bastiaan Olij](https://github.com/BastiaanOlij/)
- [Malcolm Nixon](https://github.com/Malcolmnixon/)

For further contributors please see `CONTRIBUTORS.md`

> As a successor to the original Godot XR Tools, all original contributors are credited.
