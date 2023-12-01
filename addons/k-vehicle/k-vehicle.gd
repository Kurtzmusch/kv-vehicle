@tool
extends EditorPlugin


func _enter_tree():
	add_custom_type('KVehicle', 'KVehicle', preload("res://addons/k-vehicle/scene/instantiable/kvehicle.gd"), preload("res://addons/k-vehicle/city-car.svg"))
	add_custom_type('KWheel', 'KWheelInstancer', preload("res://addons/k-vehicle/scene/instantiable/kwheelinstancer.gd"), preload("res://addons/k-vehicle/car-wheel.svg"))
	pass


func _exit_tree():
	remove_custom_type('KVehicle')
	remove_custom_type('KWHeel')
	pass
