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

@tool
class_name XRT2FingerPoses
extends Resource

@export_group("Thumb", "thumb_")

## Enable posing of the thumb
@export var thumb_enabled: bool = false:
	set(value):
		thumb_enabled = value
		notify_property_list_changed()

## Spread for our thumb
@export_range(-20.0, 20.0, 1.0, "radians_as_degrees") var thumb_spread: float = 0.0

## Metacarpal curl for our thumb
@export_range(-10.0, 90.0, 1.0, "radians_as_degrees") var thumb_metacarpal_curl: float = 0.0

## Proximal curl for our thumb
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var thumb_proximal_curl: float = 0.0

## Distal curl for our thumb
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var thumb_distal_curl: float = 0.0

@export_group("Index finger", "index_")

## Enable posing of the index finger
@export var index_enabled: bool = false:
	set(value):
		index_enabled = value
		notify_property_list_changed()

## Spread for our index finger
@export_range(-20.0, 20.0, 1.0, "radians_as_degrees") var index_spread: float = 0.0

## Proximal curl for our index finger
@export_range(-10.0, 90.0, 1.0, "radians_as_degrees") var index_proximal_curl: float = deg_to_rad(25.0)

## Intermediate curl for our index finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var index_intermediate_curl: float = deg_to_rad(45.0)

## Distal curl for our index finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var index_distal_curl: float = deg_to_rad(45.0)

@export_group("Middle finger", "middle_")

## Enable posing of the middle finger
@export var middle_enabled: bool = false:
	set(value):
		middle_enabled = value
		notify_property_list_changed()

## Spread for our middle finger
@export_range(-20.0, 20.0, 1.0, "radians_as_degrees") var middle_spread: float = 0.0

## Proximal curl for our middle finger
@export_range(-10.0, 90.0, 1.0, "radians_as_degrees") var middle_proximal_curl: float = deg_to_rad(25.0)

## Intermediate curl for our middle finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var middle_intermediate_curl: float = deg_to_rad(45.0)

## Distal curl for our middle finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var middle_distal_curl: float = deg_to_rad(45.0)

@export_group("Ring finger", "ring_")

## Enable posing of the ring finger
@export var ring_enabled: bool = false:
	set(value):
		ring_enabled = value
		notify_property_list_changed()

## Spread for our ring finger
@export_range(-20.0, 20.0, 1.0, "radians_as_degrees") var ring_spread: float = 0.0

## Proximal curl for our ring finger
@export_range(-10.0, 90.0, 1.0, "radians_as_degrees") var ring_proximal_curl: float = deg_to_rad(25.0)

## Intermediate curl for our ring finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var ring_intermediate_curl: float = deg_to_rad(45.0)

## Distal curl for our ring finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var ring_distal_curl: float = deg_to_rad(45.0)

@export_group("Little finger", "little_")

## Enable posing of the little finger
@export var little_enabled: bool = false:
	set(value):
		little_enabled = value
		notify_property_list_changed()

## Mode for posing of the pinky ("On grip" animates based on grip input)
@export_enum("Disabled", "Pose", "On grip") var little_mode: int = 0

## Spread for our little finger
@export_range(-20.0, 20.0, 1.0, "radians_as_degrees") var little_spread: float = 0.0

## Proximal curl for our little finger
@export_range(-10.0, 90.0, 1.0, "radians_as_degrees") var little_proximal_curl: float = deg_to_rad(25.0)

## Intermediate curl for our little finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var little_intermediate_curl: float = deg_to_rad(45.0)

## Distal curl for our little finger
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var little_distal_curl: float = deg_to_rad(45.0)


func _validate_property(property: Dictionary) -> void:
	if not thumb_enabled and property.name in [ "thumb_spread", "thumb_metacarpal_curl", "thumb_proximal_curl", "thumb_distal_curl" ]:
		property.usage = PROPERTY_USAGE_NONE
	elif not index_enabled and property.name in [ "index_spread", "index_metacarpal_curl", "index_proximal_curl", "index_intermediate_curl", "index_distal_curl" ]:
		property.usage = PROPERTY_USAGE_NONE
	elif not middle_enabled and property.name in [ "middle_spread", "middle_metacarpal_curl", "middle_proximal_curl", "middle_intermediate_curl", "middle_distal_curl" ]:
		property.usage = PROPERTY_USAGE_NONE
	elif not ring_enabled and property.name in [ "ring_spread", "ring_metacarpal_curl", "ring_proximal_curl", "ring_intermediate_curl", "ring_distal_curl" ]:
		property.usage = PROPERTY_USAGE_NONE
	elif not little_enabled and property.name in [ "little_spread", "little_metacarpal_curl", "little_proximal_curl", "little_intermediate_curl", "little_distal_curl" ]:
		property.usage = PROPERTY_USAGE_NONE
