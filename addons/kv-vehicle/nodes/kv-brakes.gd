extends KVComponent
## applies break torque to wheels
## [br] if [member KVBreak.abs] is true, the abs system will reduce break input. This can happen before the tire is considered to be slipping by setting [member KVBreak.absThreshold] to a value greater then 0.0.
## [br] if the contact patch is considered to be slipping, the abs will prevent the brake from applying any brake torque.
class_name KVBreak

@export var wheels: Array[KVWheel]

## torque applied to each wheel, tipically, front breaks are stronger, as the tractions increases in the front tires during breaking.
@export var strength = 2000.0

## anti locking, automatically reduces break input if the wheel is slipping 
@export var abs = false

## abs relative velocity(meter/second) threshold.
## [br] the abs will reduce break input when the contact patch relative velocity is over this threshold
@export var absThreshold = 2.0

## break strength multiplier when the tire is over the throshold.

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
		if !wheel.grounded: continue
		var threshold = absThreshold
		
		var strActual = str
		if abs:
			#wheel.debugString = ''
			#var slipping =  abs( wheel.contactRelativeVelocity.z ) > wheel.tireResponse.relativeZSpeedBegin
			#TODO maybe different tire response should have a method that tells if/how much it's slipping
			#current brush implementation never slips
			if abs( wheel.contactRelativeVelocity.z ) > threshold:
				#wheel.debugString = 'abs'
				strActual = str*slipStrengthMult
				absOverriding = true
				
			else:
				absOverriding = false
		wheel.applyBreakTorque(strength*strActual, modDelta)
