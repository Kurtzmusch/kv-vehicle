extends Node
class_name KVBreak

@export var wheels: Array[KVWheel]
@export var strength = 2000.0

var vehicle
func _ready():
	vehicle = get_parent()

func _process(delta):
	pass

func _integrate(delta, oneByDelta, modDelta, oneBySubstep):
	var str = vehicle.break2Input
	for wheel in wheels:
		wheel.applyBreakTorque(strength*str, modDelta)
