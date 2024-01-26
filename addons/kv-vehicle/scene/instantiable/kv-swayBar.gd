extends KVComponent
## sway bars are used to prevent rolling
##
## applies a torque to the vehicle that is proportional to the delta in suspension load.
## can be also be used to prevent excessive pitch

class_name KVSwayBar
@export var wheels: Array[KVWheel]

## stiffness as a coeficient, final torque is proportional to vehicle mass.
## [br] lower values allow the vehicle to roll more
@export var stiffness = 1.0

## controls the response curve. higher values allow the vehicle to roll more.
## [br] 1.0: linear
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

func _integrate(delta, oneByDelta, modDelta, oneBySubstep):
	
	var stiffnessActual = stiffness*vehicle.mass
	
	var compressionDelta = w1.normalizedCompression-w2.normalizedCompression
	compressionDelta = pow( abs(compressionDelta), exponent ) * sign(compressionDelta)
	
	w1.additionalSuspensionForceMagnitude = compressionDelta*stiffnessActual
	w2.additionalSuspensionForceMagnitude = -compressionDelta*stiffnessActual
