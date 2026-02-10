#-------------------------------------------------------------------------------
# xrt2_finger_poses.gd
#-------------------------------------------------------------------------------
# MIT License
#
# Copyright (c) 2024-present Bastiaan Olij, Malcolm A Nixon and contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#-------------------------------------------------------------------------------

class_name XRT2FingerPoses
extends Resource

@export_group("Thumb", "thumb_")

## Enable posing of the thumb
@export var thumb_enabled: bool = false

## Spread for our thumb
@export_range(-20.0, 20.0, 1.0, "radians_as_degrees") var thumb_spread: float = 0.0

## Metacarpal curl for our thumb
@export_range(-10.0, 90.0, 1.0, "radians_as_degrees") var thumb_metacarpal_curl: float = 0.0

## Proximal curl for our thumb
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var thumb_proximal_curl: float = 0.0

## Distal curl for our thumb
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var thumb_distal_curl: float = 0.0


@export_group("Index finger", "index_")

## Mode for posing of the index finger ("On trigger" animates based on trigger input)
@export_enum("Disabled", "Pose", "On trigger") var index_mode: int = 0

## Spread for our index finger
@export_range(-20.0, 20.0, 1.0, "radians_as_degrees") var index_spread: float = 0.0

## Proximal curl for our index finger
@export_range(-10.0, 90.0, 1.0, "radians_as_degrees") var index_proximal_curl: float = deg_to_rad(25.0)

## Intermediate curl for our index finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var index_intermediate_curl: float = deg_to_rad(45.0)

## Distal curl for our index finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var index_distal_curl: float = deg_to_rad(45.0)

@export_group("Middle finger", "middle_")

## Mode for posing of the middle finger ("On grip" animates based on grip input)
@export_enum("Disabled", "Pose", "On grip") var middle_mode: int = 0

## Spread for our middle finger
@export_range(-20.0, 20.0, 1.0, "radians_as_degrees") var middle_spread: float = 0.0

## Proximal curl for our middle finger
@export_range(-10.0, 90.0, 1.0, "radians_as_degrees") var middle_proximal_curl: float = deg_to_rad(25.0)

## Intermediate curl for our middle finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var middle_intermediate_curl: float = deg_to_rad(45.0)

## Distal curl for our middle finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var middle_distal_curl: float = deg_to_rad(45.0)

@export_group("Ring finger", "ring_")

## Mode for posing of the ring finger ("On grip" animates based on grip input)
@export_enum("Disabled", "Pose", "On grip") var ring_mode: int = 0

## Spread for our ring finger
@export_range(-20.0, 20.0, 1.0, "radians_as_degrees") var ring_spread: float = 0.0

## Proximal curl for our ring finger
@export_range(-10.0, 90.0, 1.0, "radians_as_degrees") var ring_proximal_curl: float = deg_to_rad(25.0)

## Intermediate curl for our ring finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var ring_intermediate_curl: float = deg_to_rad(45.0)

## Distal curl for our ring finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var ring_distal_curl: float = deg_to_rad(45.0)

@export_group("Pinky", "pinky_")

## Mode for posing of the pinky ("On grip" animates based on grip input)
@export_enum("Disabled", "Pose", "On grip") var pinky_mode: int = 0

## Spread for our pinky
@export_range(-20.0, 20.0, 1.0, "radians_as_degrees") var pinky_spread: float = 0.0

## Proximal curl for our pinky
@export_range(-10.0, 90.0, 1.0, "radians_as_degrees") var pinky_proximal_curl: float = deg_to_rad(25.0)

## Intermediate curl for our pinky
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var pinky_intermediate_curl: float = deg_to_rad(45.0)

## Distal curl for our pinky
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var pinky_distal_curl: float = deg_to_rad(45.0)
