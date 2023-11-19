# metaverse.gd
# This file is part of Astropolis
# Copyright 2019-2023 Charlie Whitfield, all rights reserved
# *****************************************************************************
class_name Metaverse
extends NetRef

# SDK Note: This class will be ported to C++ becoming a GDExtension class. You
# will have access to API (just like any Godot class) but the GDScript class
# will be removed.


enum { # _dirty
	DIRTY_COMPUTATIONS = 1,
	DIRTY_DIVERSITY_MODEL = 1 << 1,
}

# save/load persistence for server only
const PERSIST_PROPERTIES2: Array[StringName] = [
	&"computations",
	&"diversity_model",
	
	&"delta_computations",
	&"delta_diversity_model",
]

var computations := 0.0
var diversity_model: Dictionary # see static/diversity.gd

# TODO: histories including information using get_development_information()

# accumulators
var delta_computations := 0.0
var delta_diversity_model: Dictionary



func _init(is_new := false) -> void:
	if !is_new: # loaded game
		return
	diversity_model = {}
 
# ********************************** READ *************************************
# NOT all threadsafe!

func get_development_information() -> float:
	# NOT THREADSAFE !!!!
	return diversity.get_shannon_entropy_2(diversity_model, delta_diversity_model) # in 'bits'



# ****************************** SERVER MODIFY ********************************

func change_diversity_model(key: int, change: float) -> void:
	diversity.change_model(delta_diversity_model, key, change)
	assert(_debug_assert_diversity_model_change(diversity_model, delta_diversity_model, key))
	_dirty |= DIRTY_DIVERSITY_MODEL


# ********************************** SYNC *************************************


func take_delta(data: Array) -> void:
	# save delta in data, apply & zero delta, reset dirty flags
	
	_int_data = data[0]
	_float_data = data[1]
	
	_int_data[10] = _int_data.size()
	_int_data[11] = _float_data.size()
	
	_int_data.append(_dirty)
	if _dirty & DIRTY_COMPUTATIONS:
		_float_data.append(delta_computations)
		computations += delta_computations
		delta_computations = 0.0
	if _dirty & DIRTY_DIVERSITY_MODEL:
		_take_diversity_model_delta(diversity_model, delta_diversity_model)
	
	_dirty = 0


func add_delta(data: Array) -> void:
	# apply delta & dirty flags
	
	_int_data = data[0]
	_float_data = data[1]
	
	_int_offset = _int_data[10]
	_float_offset = _int_data[11]
	
	var svr_qtr := _int_data[0]
	run_qtr = svr_qtr # TODO: histories
	
	var dirty := _int_data[_int_offset]
	_int_offset += 1
	_dirty |= dirty
	
	if dirty & DIRTY_COMPUTATIONS:
		delta_computations += _float_data[_float_offset]
		_float_offset += 1
	if dirty & DIRTY_DIVERSITY_MODEL:
		_add_diversity_model_delta(delta_diversity_model)


# REMOVE BELOW!


func take_server_delta(data: Array) -> void:
	# facility accumulator only; zero accumulators and dirty flags
	
	_int_data = data[0]
	_float_data = data[1]
	
	_int_data[12] = _int_data.size()
	_int_data[13] = _float_data.size()
	
	_int_data.append(_dirty)
	if _dirty & DIRTY_COMPUTATIONS:
		_float_data.append(computations)
		computations = 0.0
	
	if _dirty & DIRTY_DIVERSITY_MODEL:
		_int_data.append(diversity_model.size())
		for key: int in diversity_model: # has changes only
			_int_data.append(key)
			_float_data.append(diversity_model[key])
		diversity_model.clear()
	_dirty = 0


func add_server_delta(data: Array) -> void:
	# any target; reference safe
	
	_int_data = data[0]
	_float_data = data[1]
	
	_int_offset = _int_data[12]
	_float_offset = _int_data[13]
	
	var svr_qtr := _int_data[0]
	run_qtr = svr_qtr # TODO: histories

	var flags := _int_data[_int_offset]
	_int_offset += 1
	if flags & DIRTY_COMPUTATIONS:
		computations += _float_data[_float_offset]
		_float_offset += 1
	
	if flags & DIRTY_DIVERSITY_MODEL:
		var size := _int_data[_int_offset]
		_int_offset += 1
		var i := 0
		while i < size:
			var key := _int_data[_int_offset]
			_int_offset += 1
			var change := _float_data[_float_offset]
			_float_offset += 1
			if diversity_model.has(key):
				diversity_model[key] += change
				if diversity_model[key] == 0.0:
					diversity_model.erase(key)
			else:
				diversity_model[key] = change
			i += 1

