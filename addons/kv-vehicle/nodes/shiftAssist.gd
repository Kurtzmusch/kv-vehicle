extends Node

## since it needs to overrride clutch and throtle, this node must be after the input handler in the scene tree

@export var engine: KVEngine
@export var drivetrain: KVDrivetrain

enum shiftMethods {
	None,
	Clamp,
	MaximizeTorque
}
## shifting logic to be used.
##[br] [b]clamp[/b]: shifts if below engine idle, or above engine rev limit
##[br] [b]maximizeTorque[/b]: shifts up or down trying to obtain the maximum amount of torque
@export var shiftMethod = shiftMethods.Clamp

var shiftingFunctions = [
	shiftNone,
	shiftClamp,
	shiftMaximizeTorque
]
## if true, ignores user input
@export var disableUserShifting = false
## if true, overrides acceleration to help with smoother gear transition
@export var revMatch = true
## how much rev matching overrides user input
@export_range(0.0, 1.0) var revMatchAuthority = 0.5
## amount of clutch to use when updshifting, overrides user input
@export var upshiftClutchMult = 1.0
## amount of clutch to use when downshifting, overrides user input
@export var downshiftClutchMult = .25
## if true, presses the accelerator to counter engine breaking.
@export var antiEngineBreak = false
## threshold as a coeficient of max engine torque to use when downshifting.
##[br] increase this if the vehicle downshifts right after an upshift. useful when the clutch is not very agressive.
@export_range(0.0, 1.0) var downshiftThreshold = 0.1
## threshold as a coeficient of max engine torque to use when upshifting.
##[br] increase this if the vehicle downshifts right after an upshift. useful when the clutch is not very agressive.
@export_range(0.0, 1.0) var upshiftThreshold = 0.1

@export_range(0.0,1.0) var antiEngineBreakPressure = 0.05

var vehicle: KVVehicle


func _ready():
	vehicle = get_parent()

func _physics_process(delta):
	if !disableUserShifting:
		if Input.is_action_just_pressed('shift+'):
			drivetrain.shiftGear(1)
			
		if Input.is_action_just_pressed('shift-'):
			drivetrain.shiftGear(-1)
			
	
	
	var isNeutral = is_zero_approx(drivetrain.gearRatio)
	if isNeutral:
		if vehicle.localLinearVelocity.length() < 0.1:
			shiftFromNeutral()
		else:
			shiftingFunctions[shiftMethod].call()
		return
	if Input.get_action_strength('clutch') >= 0.99\
	or Input.get_action_strength('handbreak') > 0.0:
		shiftingFunctions[shiftMethod].call()
		return
	var downshifting = drivetrain.rpsDelta > 0.001
	"if downshifting:
		print(drivetrain.rpsDelta)
		vehicle.clutchInput = 0.9"
	if (abs(drivetrain.rpsDelta) > 2.0 or downshifting) and engine.radsPerSec>(engine.idleRadsPerSec+20):
		if sign(drivetrain.rpsDelta) != 0.0:
			var desired = max(0.0, sign(drivetrain.rpsDelta) )
			vehicle.accelerationInput = lerp(vehicle.accelerationInput, desired, revMatchAuthority)
			
			
			
		var mult = upshiftClutchMult
		if downshifting: mult = downshiftClutchMult
		
		#vehicle.clutchInput = (1.0 - clamp((1.0-revMatchClutchInput)*drivetrain.gearRatio, 0.0, 1.0) )*revMatchClutchInput
		vehicle.clutchInput = clamp(( ( 1.0-(abs(drivetrain.gearRatio) )*mult) ), 0.0, 1.0)
			
	else:
		if antiEngineBreak and is_zero_approx(vehicle.break2Input):
			# constant for now since there is no rolling resist
			var counterEngineBreak = antiEngineBreakPressure# * drivetrain.gearRatio
			vehicle.accelerationInput = max(vehicle.accelerationInput, counterEngineBreak)
	shiftingFunctions[shiftMethod].call()

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
		var wheelRPM = abs(drivetrain.getFastestWheel().radsPerSec)/TAU*60.0
		var engineCoupledRPM = getEngineRPM(drivetrain.gearRatio, wheelRPM)
		if engineCoupledRPM >= engine.maxRevsPerMinute-50:
			drivetrain.shiftGear(sign(drivetrain.gearRatio))
		if engineCoupledRPM <= engine.idleRevsPerMinute+100\
		and drivetrain.currentGearIndex != drivetrain.neutralGearIndex:
			shiftToNeutral()

func shiftMaximizeTorque():
	#only works for positive gears
	if drivetrain.currentGearIndex == drivetrain.neutralGearIndex:
		shiftFromNeutral()
	else:
		#var currentTorque = getEngineTorque(engine.revsPerMinute)
		var wheelRPM = abs(drivetrain.getFastestWheel().radsPerSec)/TAU*60.0
		var nextGear = min(drivetrain.currentGearIndex+1, drivetrain.gearRatios.size()-1)
		var currentTorque = getEngineTorque(getEngineRPM(drivetrain.gearRatio, wheelRPM))
		if nextGear > drivetrain.currentGearIndex:
			var nextGearRatio = getGearRatio(nextGear)
			var nextRPM = getEngineRPM(nextGearRatio, wheelRPM)
			var nextTorque = getEngineTorque(nextRPM)
			var threshold = currentTorque+upshiftThreshold
			
			if nextTorque > threshold:
				drivetrain.shiftGear(1)
				vehicle.accelerationInput = 0.0
				vehicle.clutchInput = 1.0
				return
		var prevGear = max(drivetrain.neutralGearIndex+1, drivetrain.currentGearIndex-1)
		if prevGear < drivetrain.currentGearIndex:
			var prevGearRatio = getGearRatio(prevGear)
			var prevRPM = getEngineRPM(prevGearRatio, wheelRPM)
			var prevTorque = getEngineTorque(prevRPM)
			var threshold = currentTorque+downshiftThreshold
			
			if prevTorque > threshold:
				drivetrain.shiftGear(-1)
				
				vehicle.accelerationInput = 1.0
				vehicle.clutchInput = 1.0
		else:
			if engine.radsPerSec <= engine.idleRadsPerSec+5\
			and drivetrain.currentGearIndex != drivetrain.neutralGearIndex:
				shiftToNeutral()

func getEngineRPM(gearRatio, wheelRPM):
	return wheelRPM/abs(gearRatio)

func getGearRatio(gearIndex):
	return drivetrain.gearRatios[gearIndex]*drivetrain.finalRatio

func getWheelRPM():
	return engine.revsPerMinute*drivetrain.gearRatio

func getEngineTorque(revsPerMinute):
	var samplePosition = revsPerMinute/engine.maxRevsPerMinute
	return engine.torqueCurve.sample_baked(samplePosition)
