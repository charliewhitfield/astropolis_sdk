# inventory.gd
# This file is part of Astropolis
# Copyright 2019-2023 Charlie Whitfield, all rights reserved
# *****************************************************************************
class_name Inventory
extends NetRef

# SDK Note: This class will be ported to C++ becoming a GDExtension class. You
# will have access to API (just like any Godot class) but the GDScript class
# will be removed.
#
# Arrays indexed by resource_type. Facility and (sometimes) Proxy have an
# Inventory. 'prices', 'bids' and 'asks' are common for polity at specific body.

# In trade units or in internal units????

# save/load persistence for server only
const PERSIST_PROPERTIES2: Array[StringName] = [
	&"reserves",
	&"markets",
	&"in_transits",
	&"contracteds",
	&"prices",
	&"bids",
	&"asks",
	
	&"delta_reserves",
	&"delta_markets",
	&"delta_in_transits",
	&"delta_contracteds",
	
	&"_dirty_reserves_1",
	&"_dirty_reserves_2",
	&"_dirty_markets_1",
	&"_dirty_markets_2",
	&"_dirty_in_transits_1",
	&"_dirty_in_transits_2",
	&"_dirty_contracteds_1",
	&"_dirty_contracteds_2",
	&"_dirty_prices_1",
	&"_dirty_prices_2",
	&"_dirty_bids_1",
	&"_dirty_bids_2",
	&"_dirty_asks_1",
	&"_dirty_asks_2",
]


# Interface read-only! Data flows server -> interface.
var reserves: Array[float] # exists here; we may need it (>= 0.0)
var markets: Array[float] # exists here; Trader may commit (>= 0.0)
var in_transits: Array[float] # on the way (>= 0.0), posibly under contract
var contracteds: Array[float] # sum of all contracts (+/-), here or elsewhere
var prices: Array[float] # last sale or set by Exchange (NAN if no price)
var bids: Array[float] # NAN if none
var asks: Array[float] # NAN if none

# accumulators
var delta_reserves: Array[float]
var delta_markets: Array[float]
var delta_in_transits: Array[float]
var delta_contracteds: Array[float]

# dirty flags
var _dirty_reserves_1 := 0
var _dirty_reserves_2 := 0 # max 128
var _dirty_markets_1 := 0
var _dirty_markets_2 := 0 # max 128
var _dirty_in_transits_1 := 0
var _dirty_in_transits_2 := 0 # max 128
var _dirty_contracteds_1 := 0
var _dirty_contracteds_2 := 0 # max 128
var _dirty_prices_1 := 0
var _dirty_prices_2 := 0 # max 128
var _dirty_bids_1 := 0
var _dirty_bids_2 := 0 # max 128
var _dirty_asks_1 := 0
var _dirty_asks_2 := 0 # max 128



func _init(is_new := false) -> void:
	if !is_new: # game load
		return
	var n_resources: int = IVTableData.table_n_rows.resources
	reserves = ivutils.init_array(n_resources, 0.0, TYPE_FLOAT)
	markets = reserves.duplicate()
	in_transits = reserves.duplicate()
	contracteds = reserves.duplicate()
	prices = ivutils.init_array(n_resources, NAN, TYPE_FLOAT)
	bids = prices.duplicate()
	asks = prices.duplicate()
	delta_reserves = reserves.duplicate()
	delta_markets = reserves.duplicate()
	delta_in_transits = reserves.duplicate()
	delta_contracteds = reserves.duplicate()


# ********************************** READ *************************************
# all threadsafe

func get_reserve(type: int) -> float:
	return reserves[type] + delta_reserves[type]


func get_market(type: int) -> float:
	return markets[type] + delta_markets[type]


func get_in_transit(type: int) -> float:
	return in_transits[type] + delta_in_transits[type]


func get_contracted(type: int) -> float:
	return contracteds[type] + delta_contracteds[type]


func get_price(type: int) -> float:
	return prices[type]


func get_bid(type: int) -> float:
	return bids[type]


func get_ask(type: int) -> float:
	return asks[type]


func get_in_stock(type: int) -> float:
	return reserves[type] + delta_reserves[type] + markets[type] + delta_markets[type]


# ****************************** SERVER MODIFY ********************************

func change_reserve(type: int, change: float) -> void:
	assert(change >= 0.0 or change + get_reserve(type) >= 0.0)
	if !change:
		return
	delta_reserves[type] += change
	if type < 64:
		_dirty_reserves_1 |= 1 << type
	else:
		_dirty_reserves_2 |= 1 << (type - 64)


func set_price(type: int, value: float) -> void:
	# NAN ok
	var current := prices[type]
	if value == current:
		return
	if is_nan(value) and is_nan(current):
		return
	prices[type] = value
	if type < 64:
		_dirty_prices_1 |= 1 << type
	else:
		_dirty_prices_2 |= 1 << (type - 64)
	

# ********************************** SYNC *************************************


func take_delta(data: Array) -> void:
	# save delta in data, apply & zero delta, reset dirty flags
	
	_int_data = data[0]
	_float_data = data[1]
	
	_int_data[4] = _int_data.size()
	_int_data[5] = _float_data.size()
	
	_take_floats_delta(reserves, delta_reserves, _dirty_reserves_1)
	_take_floats_delta(reserves, delta_reserves, _dirty_reserves_2, 64)
	_take_floats_delta(markets, delta_markets, _dirty_markets_1)
	_take_floats_delta(markets, delta_markets, _dirty_markets_2, 64)
	_take_floats_delta(in_transits, delta_in_transits, _dirty_in_transits_1)
	_take_floats_delta(in_transits, delta_in_transits, _dirty_in_transits_2, 64)
	_take_floats_delta(contracteds, delta_contracteds, _dirty_contracteds_1)
	_take_floats_delta(contracteds, delta_contracteds, _dirty_contracteds_2, 64)
	_get_floats_dirty(prices, _dirty_prices_1)
	_get_floats_dirty(prices, _dirty_prices_2, 64)
	_get_floats_dirty(bids, _dirty_bids_1)
	_get_floats_dirty(bids, _dirty_bids_2, 64)
	_get_floats_dirty(asks, _dirty_asks_1)
	_get_floats_dirty(asks, _dirty_asks_2, 64)
	
	_dirty_reserves_1 = 0
	_dirty_reserves_2 = 0
	_dirty_markets_1 = 0
	_dirty_markets_2 = 0
	_dirty_in_transits_1 = 0
	_dirty_in_transits_2 = 0
	_dirty_contracteds_1 = 0
	_dirty_contracteds_2 = 0
	_dirty_prices_1 = 0
	_dirty_prices_2 = 0
	_dirty_bids_1 = 0
	_dirty_bids_2 = 0
	_dirty_asks_1 = 0
	_dirty_asks_2 = 0



func add_delta(data: Array) -> void:
	# apply delta & dirty flags
	_int_data = data[0]
	_float_data = data[1]
	
	_int_offset = _int_data[4]
	_float_offset = _int_data[5]
	
	var svr_qtr := _int_data[0]
	run_qtr = svr_qtr # TODO: histories
	
	_dirty_reserves_1 |= _add_floats_delta(delta_reserves)
	_dirty_reserves_2 |= _add_floats_delta(delta_reserves, 64)
	_dirty_markets_1 |= _add_floats_delta(delta_markets)
	_dirty_markets_2 |= _add_floats_delta(delta_markets, 64)
	_dirty_in_transits_1 |= _add_floats_delta(delta_in_transits)
	_dirty_in_transits_2 |= _add_floats_delta(delta_in_transits, 64)
	_dirty_contracteds_1 |= _add_floats_delta(delta_contracteds)
	_dirty_contracteds_2 |= _add_floats_delta(delta_contracteds, 64)
	_dirty_prices_1 |= _set_floats_dirty(prices)
	_dirty_prices_2 |= _set_floats_dirty(prices, 64)
	_dirty_bids_1 |= _set_floats_dirty(bids)
	_dirty_bids_2 |= _set_floats_dirty(bids, 64)
	_dirty_asks_1 |= _set_floats_dirty(asks)
	_dirty_asks_2 |= _set_floats_dirty(asks, 64)




# REMOVE BELOW!


func take_server_delta(data: Array) -> void:
	# facility accumulator only; zero values and dirty flags
	
	_int_data = data[0]
	_float_data = data[1]
	
	_int_data[4] = _int_data.size()
	_int_data[5] = _float_data.size()
	
	_append_and_zero_dirty_floats(reserves, _dirty_reserves_1)
	_append_and_zero_dirty_floats(reserves, _dirty_reserves_2, 64)
	_append_and_zero_dirty_floats(markets, _dirty_markets_1)
	_append_and_zero_dirty_floats(markets, _dirty_markets_2, 64)
	_append_and_zero_dirty_floats(in_transits, _dirty_in_transits_1)
	_append_and_zero_dirty_floats(in_transits, _dirty_in_transits_2, 64)
	_append_and_zero_dirty_floats(contracteds, _dirty_contracteds_1)
	_append_and_zero_dirty_floats(contracteds, _dirty_contracteds_2, 64)
	_append_dirty_floats(prices, _dirty_prices_1)
	_append_dirty_floats(prices, _dirty_prices_2, 64)
	_append_dirty_floats(bids, _dirty_bids_1)
	_append_dirty_floats(bids, _dirty_bids_2, 64)
	_append_dirty_floats(asks, _dirty_asks_1)
	_append_dirty_floats(asks, _dirty_asks_2, 64)
	
	_dirty_reserves_1 = 0
	_dirty_reserves_2 = 0
	_dirty_markets_1 = 0
	_dirty_markets_2 = 0
	_dirty_in_transits_1 = 0
	_dirty_in_transits_2 = 0
	_dirty_contracteds_1 = 0
	_dirty_contracteds_2 = 0
	_dirty_prices_1 = 0
	_dirty_prices_2 = 0
	_dirty_bids_1 = 0
	_dirty_bids_2 = 0
	_dirty_asks_1 = 0
	_dirty_asks_2 = 0


func add_server_delta(data: Array) -> void:
	# any target
	
	_int_data = data[0]
	_float_data = data[1]
	
	_int_offset = _int_data[4]
	_float_offset = _int_data[5]
	
	var svr_qtr := _int_data[0]
	run_qtr = svr_qtr # TODO: histories
	
	_add_dirty_floats(reserves)
	_add_dirty_floats(reserves, 64)
	_add_dirty_floats(markets)
	_add_dirty_floats(markets, 64)
	_add_dirty_floats(in_transits)
	_add_dirty_floats(in_transits, 64)
	_add_dirty_floats(contracteds)
	_add_dirty_floats(contracteds, 64)
	_set_dirty_floats(prices)     # not accumulator!
	_set_dirty_floats(prices, 64) # not accumulator!
	_set_dirty_floats(bids)     # not accumulator!
	_set_dirty_floats(bids, 64) # not accumulator!
	_set_dirty_floats(asks)     # not accumulator!
	_set_dirty_floats(asks, 64) # not accumulator!

