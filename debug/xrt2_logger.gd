#-------------------------------------------------------------------------------
# xrt2_logger.gd
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

class_name XRT2Logger
extends Logger

## XRT2Logger is a Logger object that captures and caches new log entries
## so they can be displayed to the user.

signal message_changed

var mutex : Mutex = Mutex.new()
var entries: PackedStringArray


## Get entries from our log.
## If clear is [code]true[/code] we clear our buffer.
func get_entries(clear: bool = false) -> PackedStringArray:
	# Make a copy to return
	mutex.lock()
	var ret: PackedStringArray = entries
	if clear:
		entries.clear()
	mutex.unlock()

	return ret


func _log_error(function, file, line, code, rationale, editor_notify, error_type, script_backtraces):
	# TODO construct a proper message
	var message = rationale

	if error_type == ERROR_TYPE_ERROR:
		message = "[color=red]" + message + "[/color]"
	elif error_type == ERROR_TYPE_WARNING:
		message = "[color=orange]" + message + "[/color]"

	_add_message(message)


func _log_message(message, error):
	if error:
		message = "[color=red]" + message + "[/color]"
	_add_message(message)


func _add_message(message):
	mutex.lock()
	entries.push_back(message)
	mutex.unlock()

	message_changed.emit()
