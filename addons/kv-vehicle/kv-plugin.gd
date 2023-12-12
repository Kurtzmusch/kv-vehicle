@tool
extends EditorPlugin


func _enter_tree():
	add_custom_type('KVVehicle', 'KVVehicle', preload("res://addons/kv-vehicle/scene/instantiable/kv-vehicle.gd"), preload("res://addons/kv-vehicle/city-car.svg"))
	add_custom_type('KVWheel', 'KVWheel', preload("res://addons/kv-vehicle/scene/instantiable/kv-wheel.gd"), preload("res://addons/kv-vehicle/car-wheel.svg"))
	add_custom_type('KVVehicleInstantiator', 'KVVehicleInstantiator', preload("res://addons/kv-vehicle/nodes/kv-vehicleInstantiator.gd"), preload("res://addons/kv-vehicle/city-car.svg"))
	add_custom_type('KVWheelInstantiator', 'KVWheelInstantiator', preload("res://addons/kv-vehicle/nodes/kv-wheelInstantiator.gd"), preload("res://addons/kv-vehicle/car-wheel.svg"))


func _exit_tree():
	remove_custom_type('KVVehicle')
	remove_custom_type('KVWHeel')
	remove_custom_type('KVVehicleInstantiator')
	remove_custom_type('KVWheelInstantiator')
