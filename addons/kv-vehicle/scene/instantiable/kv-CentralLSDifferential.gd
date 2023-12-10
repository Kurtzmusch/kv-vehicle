extends KVComponent
class_name KVCentralLSDifferential
## differential between [KVLimitedSlipDifferential]s


@export var lsds: Array[KVLimitedSlipDifferential]
## angular velocity limit (radians/second)
@export var limit = 10.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _integrate(delta, oneByDelta, modDelta, oneBySubstep):
	if get_parent().clutchInput > 0.0: return
	var lsd1Highest = lsds[0].highestRPSWheel
	var lsd2Highest = lsds[1].highestRPSWheel
	
	var highestRPSWheel = lsd1Highest
	var otherWheel = lsd2Highest
	if abs(otherWheel.radsPerSec) > abs(highestRPSWheel.radsPerSec):
		highestRPSWheel = otherWheel
		otherWheel = lsd1Highest
		
	var radsPerSecDelta = highestRPSWheel.radsPerSec - otherWheel.radsPerSec
	if abs(radsPerSecDelta) > limit:
		
		var overLimit = abs(radsPerSecDelta)-limit
		var weight = clamp(overLimit*0.5, 0.0, 1.0)
		#weight = 1.0
		highestRPSWheel.radsPerSec -= overLimit*0.5*weight*sign(radsPerSecDelta)
		otherWheel.radsPerSec += overLimit*0.5*weight*sign(radsPerSecDelta)
