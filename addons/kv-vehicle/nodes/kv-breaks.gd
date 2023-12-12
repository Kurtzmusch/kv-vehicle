extends KVComponent
## applies break torque to wheels

class_name KVBreak

@export var wheels: Array[KVWheel]

## torque applied to each wheel, tipically, front breaks are stronger, as the tractions increases in the front tires during breaking.
@export var strength = 2000.0

## anti locking, automatically reduces break input if the wheel is slipping 
@export var abs = false

## abs relative velocity(meter/second) threshold
@export var absThreshold = 0.10

## break strength multiplier when the tire is slipping
@export var slipStrengthMult = 0.5

var vehicle

## gets set to true when the abs is overriding break input
var absOverriding = false

func _ready():
	vehicle = get_parent()

func _process(delta):
	pass

func _integrate(delta, oneByDelta, modDelta, oneBySubstep):
	var str = vehicle.break2Input
	for wheel in wheels:
		
		if abs:
			wheel.debugString = ''
			if abs( wheel.contactRelativeVelocity.z ) > absThreshold:
				wheel.debugString = 'abs'
				str *= slipStrengthMult
				absOverriding = true
			else:
				absOverriding = false
		wheel.applyBreakTorque(strength*str, modDelta)
