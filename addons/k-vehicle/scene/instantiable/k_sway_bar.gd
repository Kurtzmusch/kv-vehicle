extends Node
class_name KVSwayBar
@export var wheels: Array[KVWheel]
@export var stiffness = 4.0
@export var exponent = 1.0

var w1: KVWheel
var w2: KVWheel

var vehicle: KVVehicle

func _ready():
	vehicle = get_parent()
	w1 = wheels[0]
	w2 = wheels[1]
	if w1.position.x < 0:
		w1 = wheels[1]
		w2 = wheels[0]

func _process(delta):
	pass

func _integrate(delta, oneByDelta):
	var compressionDelta = w1.normalizedCompression-w2.normalizedCompression
	compressionDelta = pow( abs(compressionDelta), exponent ) * sign(compressionDelta)
	vehicle.accelerateRoll(delta, oneByDelta, compressionDelta*stiffness)
