extends Node

@export var wheels: Array[KWheel]
@export var strength = 2000.0

var vehicle
func _ready():
	vehicle = get_parent()

func _process(delta):
	pass

func _integrate(delta, oneByDelta):
	var str = vehicle.break2Input
	for wheel in wheels:
		wheel.applyBreakTorque(strength*str, delta)
