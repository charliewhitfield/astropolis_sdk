# biome.gd
# This file is part of Astropolis
# Copyright 2019-2023 Charlie Whitfield, all rights reserved
# *****************************************************************************
class_name Biome
extends NetRef

# SDK Note: This class will be ported to C++ becoming a GDExtension class. You
# will have access to API (just like any Godot class) but the GDScript class
# will be removed.
#

enum { # _dirty
	DIRTY_BIOPRODUCTIVITY = 1,
	DIRTY_BIOMASS = 1 << 1,
	DIRTY_DIVERSITY_MODEL = 1 << 2,
}


# save/load persistence for server only
const PERSIST_PROPERTIES2: Array[StringName] = [
	&"bioproductivity",
	&"biomass",
	&"diversity_model",
	
	&"delta_bioproductivity",
	&"delta_biomass",
	&"delta_diversity_model",
]

var bioproductivity := 0.0
var biomass := 0.0
var diversity_model: Dictionary # see static/diversity.gd

# TODO: histories for all dev stats

# accumulators
var delta_bioproductivity := 0.0
var delta_biomass := 0.0
var delta_diversity_model: Dictionary



func _init(is_new := false) -> void:
	if !is_new: # game load
		return
	diversity_model = {}

# ********************************** READ *************************************
# NOT all threadsafe!

func get_development_biodiversity() -> float:
	# NOT THREADSAFE !!!!
	var entropy := diversity.get_shannon_entropy_2(diversity_model, delta_diversity_model, false)
	if entropy == 0.0:
		return 0.0 # no species case; technically incorrect but intuitive
	return exp(entropy)


func get_species_richness() -> float:
	# NOT THREADSAFE !!!!
	# total number of species
	return diversity.get_species_richness_2(diversity_model, delta_diversity_model)
 
# ****************************** SERVER MODIFY ********************************

func change_diversity_model(key: int, change: float) -> void:
	diversity.change_model(diversity_model, key, change)


# ********************************** SYNC *************************************

func take_server_delta(data: Array) -> void:
	# facility accumulator only; zero accumulators and dirty flags
	
	_int_data = data[0]
	_float_data = data[1]
	
	_int_data[10] = _int_data.size()
	_int_data[11] = _float_data.size()
	
	_int_data.append(_dirty)
	if _dirty & DIRTY_BIOPRODUCTIVITY:
		_float_data.append(bioproductivity)
		bioproductivity = 0.0
	if _dirty & DIRTY_BIOMASS:
		_float_data.append(biomass)
		biomass = 0.0
	
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
	
	_int_offset = _int_data[10]
	_float_offset = _int_data[11]
	
	var svr_qtr := _int_data[0]
	run_qtr = svr_qtr # TODO: histories
	
	var flags := _int_data[_int_offset]
	_int_offset += 1
	if flags & DIRTY_BIOPRODUCTIVITY:
		bioproductivity += _float_data[_float_offset]
		_float_offset += 1
	if flags & DIRTY_BIOMASS:
		biomass += _float_data[_float_offset]
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

