# player_interface.gd
# This file is part of Astropolis
# https://t2civ.com
# *****************************************************************************
# Copyright 2019-2024 Charlie Whitfield; ALL RIGHTS RESERVED
# Astropolis is a registered trademark of Charlie Whitfield in the US
# *****************************************************************************
class_name PlayerInterface
extends Interface

# SDK Note: This class will be ported to C++ becoming a GDExtension class. You
# will have access to API (just like any Godot class) but the GDScript class
# will be removed.
#
# To modify AI, see comments in '_base_ai.gd' files.
#
# Warning! This object lives and dies on the AI thread! Containers and many
# methods are not threadsafe. Accessing non-container properties is safe.
#
# Players are never removed, but they are effectively dead if is_facilities == false.

static var player_interfaces: Array[PlayerInterface] = [] # indexed by player_id

# public read-only
var player_id := -1
var player_class := -1 # PlayerClasses enum
var part_of: PlayerInterface # non-polity players only!
var polity_name: StringName
var homeworld := ""
var is_facilities := true # 'alive' player test

var facilities: Array[Interface] = [] # resizable container - not threadsafe!

var operations := Operations.new(true, true)
var financials := Financials.new(true)
var population := Population.new(true)
var biome := Biome.new(true)
var metaverse := Metaverse.new(true)



func _init() -> void:
	super()
	entity_type = ENTITY_PLAYER


func _clear_circular_references() -> void:
	# down hierarchy only
	facilities.clear()


# *****************************************************************************
# interface API


func has_development() -> bool:
	return true


func has_markets() -> bool:
	return false


func get_player_name() -> StringName:
	return name


func get_player_class() -> int:
	return player_class


func get_polity_name() -> StringName:
	return polity_name


func get_facilities() -> Array[Interface]:
	# AI thread only!
	return facilities


func get_development_population(population_type := -1) -> float:
	return population.get_number(population_type) + operations.get_crew(population_type)


func get_development_economy() -> float:
	return operations.get_lfq_gross_output()


func get_development_energy() -> float:
	return operations.get_development_energy()


func get_development_manufacturing() -> float:
	return operations.get_development_manufacturing()


func get_development_constructions() -> float:
	return operations.get_constructions()


func get_development_computations() -> float:
	return metaverse.get_computations()


func get_development_information() -> float:
	return metaverse.get_development_information()


func get_development_bioproductivity() -> float:
	return biome.get_bioproductivity()


func get_development_biomass() -> float:
	return biome.get_biomass()


func get_development_biodiversity() -> float:
	return biome.get_development_biodiversity()




# *****************************************************************************
# sync

func set_server_init(data: Array) -> void:
	player_id = data[2]
	name = data[3]
	gui_name = data[4]
	player_class = data[5]
	var part_of_name: StringName = data[6]
	part_of = interfaces_by_name[part_of_name] if part_of_name else null
	polity_name = data[7]
	homeworld = data[8]
	
	var operations_data: Array = data[9]
	var financials_data: Array = data[10]
	var population_data: Array = data[11]
	var biome_data: Array = data[12]
	var metaverse_data: Array = data[13]
	
	operations.set_server_init(operations_data)
	financials.set_server_init(financials_data)
	population.set_server_init(population_data)
	biome.set_server_init(biome_data)
	metaverse.set_server_init(metaverse_data)


func sync_server_dirty(data: Array) -> void:
	
	var offsets: Array[int] = data[0]
	var int_data: Array[int] = data[1]
	var dirty: int = offsets[0]
	var k := 1 # offsets offset
	
	if dirty & DIRTY_BASE:
		var string_data: Array[String] = data[3]
		gui_name = string_data[0]
		player_class = int_data[1]
		var part_of_name := string_data[1]
		part_of = interfaces_by_name[part_of_name] if part_of_name else null
		polity_name = string_data[2]
		homeworld = string_data[3]
	
	if dirty & DIRTY_OPERATIONS:
		operations.add_dirty(data, offsets[k], offsets[k + 1])
		k += 2
	if dirty & DIRTY_FINANCIALS:
		financials.add_dirty(data, offsets[k], offsets[k + 1])
		k += 2
	if dirty & DIRTY_POPULATION:
		population.add_dirty(data, offsets[k], offsets[k + 1])
		k += 2
	if dirty & DIRTY_BIOME:
		biome.add_dirty(data, offsets[k], offsets[k + 1])
		k += 2
	if dirty & DIRTY_METAVERSE:
		metaverse.add_dirty(data, offsets[k], offsets[k + 1])
	
	assert(int_data[0] >= run_qtr)
	if int_data[0] > run_qtr:
		if run_qtr == -1:
			run_qtr = int_data[0]
		else:
			run_qtr = int_data[0]
			process_ai_new_quarter() # after component histories have updated



func add_facility(facility: Interface) -> void:
	assert(!facilities.has(facility))
	facilities.append(facility)
	is_facilities = true


func remove_facility(facility: Interface) -> void:
	facilities.erase(facility)
	is_facilities = !facilities.is_empty()

