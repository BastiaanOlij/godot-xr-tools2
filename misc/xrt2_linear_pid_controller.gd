#-------------------------------------------------------------------------------
# xrt2_linear_pid_controller.gd
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

class_name XRT2LinearPIDController
extends Resource

## Linear PID Controller
##
## Based on https://vazgriz.com/621/pid-controllers/
## But rewritten for Godot

enum DerivativeMeasurement {
	VELOCITY,
	ERROR_RATE_OF_CHANGE
}

@export var proportional_gain = 1.0

@export var integral_gain = 0.0
@export var integral_saturation = 1.0

@export var derivative_measurement : DerivativeMeasurement = DerivativeMeasurement.VELOCITY
@export var derivative_gain = 0.0

var _error_last : float = 0.0
var _value_last : float = 0.0
var _derivative_initialised : bool = false
var _integral_stored = 0.0

func reset():
	_derivative_initialised = false

func calculate(delta : float, current_value : float, target_value : float) -> float:
	var error : float = target_value - current_value

	# Calculate P term
	var p : float = proportional_gain * error

	# Calculate I term
	_integral_stored = clamp(_integral_stored + (error * delta), -integral_saturation, integral_saturation)
	var i : float = integral_gain * _integral_stored

	# Calculate D term
	var error_rate_of_change = (error - _error_last) / delta
	_error_last = error

	var value_rate_of_change = (current_value - _value_last) / delta
	_value_last = current_value

	var derive_measure : float = 0.0
	if _derivative_initialised:
		if derivative_measurement == DerivativeMeasurement.VELOCITY:
			derive_measure = -value_rate_of_change
		else:
			derive_measure = error_rate_of_change
	else:
		_derivative_initialised = true

	var d : float = derivative_gain * derive_measure

	return p + i + d
