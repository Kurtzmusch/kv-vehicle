extends Node

@export var wheels: Array[KVWheel]
@export var limit = 10.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _integrate(delta, oneByDelta):
	var highestRPSWheel = wheels[0]
	var otherWheel = wheels[1]
	if abs(wheels[1].radsPerSec) > abs(wheels[0].radsPerSec):
		highestRPSWheel = wheels[1]
		otherWheel = wheels[0]
		
	var radsPerSecDelta = highestRPSWheel.radsPerSec - otherWheel.radsPerSec
	if abs(radsPerSecDelta) > limit:
		
		var overLimit = abs(radsPerSecDelta)-limit
		var weight = clamp(overLimit*0.1, 0.0, 1.0)
		
		highestRPSWheel.radsPerSec -= overLimit*0.5*weight*sign(radsPerSecDelta)
		otherWheel.radsPerSec += overLimit*0.5*weight*sign(radsPerSecDelta)
		
