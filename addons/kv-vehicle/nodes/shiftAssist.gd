extends Node

## this node must be after the input handler, since it needs to overwrite clutch and throtle

@export var engine: KVEngine
@export var drivetrain: KVDrivetrain

enum shiftMethods {
	None,
	Clamp,
	MaximizeTorque
}
@export var shiftMethod = shiftMethods.Clamp

var steeringFunctions = [
	shiftNone,
	shiftClamp,
	shiftMaximizeTorque
]
@export var revMatch = true
@export var revMatchClutchInput = 0.94

var vehicle: KVVehicle

func _ready():
	vehicle = get_parent()

func _physics_process(delta):
	if Input.is_action_just_pressed('shift+'):
		drivetrain.shiftGear(1)
		return
	if Input.is_action_just_pressed('shift-'):
		drivetrain.shiftGear(-1)
		return
	if Input.get_action_strength('clutch') >= 0.99: return
	
	if abs(drivetrain.rpsDelta) > 2 and engine.radsPerSec>engine.idleRadsPerSec+2:
		if revMatch:
			vehicle.clutchInput = revMatchClutchInput
			
			if sign(drivetrain.rpsDelta) != 0.0:
				vehicle.accelerationInput = max(0.0, sign(drivetrain.rpsDelta) )
	else:
		
		steeringFunctions[shiftMethod].call()

func shiftNone(): return

func shiftFromNeutral():
	if Input.is_action_pressed("acceleration-"):
		drivetrain.shiftIntoGear(drivetrain.neutralGearIndex-1)
	else:
		if Input.is_action_pressed("acceleration+"):
			if engine.radsPerSec >= engine.idleRadsPerSec+5:
				drivetrain.shiftIntoGear(drivetrain.neutralGearIndex+1)

func shiftToNeutral():
	if !(drivetrain.currentGearIndex-sign(drivetrain.gearRatio) == drivetrain.neutralGearIndex)\
	or sign(Input.get_axis("acceleration-","acceleration+"))!=sign(drivetrain.gearRatio):
		drivetrain.shiftGear(-sign(drivetrain.gearRatio))

func shiftClamp():
	if drivetrain.currentGearIndex == drivetrain.neutralGearIndex:
		shiftFromNeutral()
	else:
		if engine.radsPerSec >= engine.maxRadsPerSec-5:
			drivetrain.shiftGear(sign(drivetrain.gearRatio))
		if engine.radsPerSec <= engine.idleRadsPerSec+5\
		and drivetrain.currentGearIndex != drivetrain.neutralGearIndex:
			shiftToNeutral()

func shiftMaximizeTorque():
	#only works for positive gears
	if drivetrain.currentGearIndex == drivetrain.neutralGearIndex:
		shiftFromNeutral()
	else:
		var currentTorque = getEngineTorque(engine.revsPerMinute)
		var wheelRPM = abs(drivetrain.getFastestWheel().radsPerSec)/TAU*60.0
		var nextGear = min(drivetrain.currentGearIndex+1, drivetrain.gearRatios.size()-1)
		if nextGear > drivetrain.currentGearIndex:
			var nextGearRatio = getGearRatio(nextGear)
			var nextRPM = getEngineRPM(nextGearRatio, wheelRPM)
			var nextTorque = getEngineTorque(nextRPM)
			var threshold = currentTorque+0.3
			if Input.get_action_strength("acceleration+")>0.1:
				threshold = currentTorque
			if nextTorque > threshold:
				drivetrain.shiftGear(1)
				vehicle.accelerationInput = 0.0
				vehicle.clutchInput = 0.0
				return
		var prevGear = max(drivetrain.neutralGearIndex+1, drivetrain.currentGearIndex-1)
		if prevGear < drivetrain.currentGearIndex:
			var prevGearRatio = getGearRatio(prevGear)
			var prevRPM = getEngineRPM(prevGearRatio, wheelRPM)
			var prevTorque = getEngineTorque(prevRPM)
			var threshold = currentTorque
			if Input.get_action_strength("acceleration+")>0.1:
				threshold += 0.3
			if prevTorque > threshold:
				drivetrain.shiftGear(-1)
				vehicle.accelerationInput = 1.0
				vehicle.clutchInput = 0.0
		else:
			if engine.radsPerSec <= engine.idleRadsPerSec+5\
			and drivetrain.currentGearIndex != drivetrain.neutralGearIndex:
				shiftToNeutral()

func getEngineRPM(gearRatio, wheelRPM):
	return wheelRPM/gearRatio

func getGearRatio(gearIndex):
	return drivetrain.gearRatios[gearIndex]*drivetrain.finalRatio

func getWheelRPM():
	return engine.revsPerMinute*drivetrain.gearRatio

func getEngineTorque(revsPerMinute):
	var samplePosition = revsPerMinute/engine.maxRevsPerMinute
	return engine.torqueCurve.sample_baked(samplePosition)
