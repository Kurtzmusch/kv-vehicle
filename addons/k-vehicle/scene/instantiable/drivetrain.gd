extends Node

@export var poweredWheels: Array[Node]
@export var engine: Node
@export var clutchMaxTorque = 800.0

@export var gearRatios: Array[float]

var currentGearIndex = 0
var gearRatio = 0.0

var _totalWheelMomentOfInertia = 0.0
var vehicle

func _ready():
	vehicle = get_parent()
	for wheel in poweredWheels:
		wheel.powered = true
		_totalWheelMomentOfInertia += wheel.momentOfInertia

func _physics_process(delta):
	if Input.is_action_just_pressed('shift+'):
		currentGearIndex += 1 
	if Input.is_action_just_pressed('shift-'):
		currentGearIndex -= 1
	currentGearIndex = max(0, currentGearIndex%gearRatios.size())

func _integrate(delta, oneByDelta):
	gearRatio = gearRatios[currentGearIndex]
	var clutchInput = max(0.0, 1.0-Input.get_action_strength('clutch')-vehicle.clutchInput)
	if engine.radsPerSec < engine.idleRadsPerSec+1:
		clutchInput = 0.0
	var engineAngularModified = engine.radsPerSec*gearRatio
	var rpsDelta = -getFastestWheel().radsPerSec -engineAngularModified 
	
	var ratio = engine.momentOfInertia/(_totalWheelMomentOfInertia*gearRatio)
	if is_zero_approx( clutchInput ): return
	var torque = (-getFastestWheel().radsPerSec-engineAngularModified)/(-1.0-ratio)
	torque*=oneByDelta
	var torqueEngine = -torque*ratio#*sign(rpsDelta)
	#FIXME make sure that *ratio is for engine and not for wheels
	engine.applyTorque(torqueEngine, delta)
	var torqueWheels = -torque/gearRatio#*sign(rpsDelta)
	#print('rpsDelta: '+ str(rpsDelta) + ' | '+'engineT: '+str(torqueEngine) +' | '+'wheelT: '+str(torqueWheels))
	for wheel in poweredWheels:
		#wheel.debugString = str( snapped(torqueWheels/poweredWheels.size(),1.0))
		wheel.debugString = str(snapped(wheel.radsPerSec,1.0))
		wheel.applyTorque(torqueWheels/poweredWheels.size(), delta)

func getGearRatio():
	return gearRatio

func getFastestWheel():
	#FIXME, consider car going back, reving and releasing the clutch
	var fastestWheel = poweredWheels[0]
	if abs(poweredWheels[1].radsPerSec) > abs(fastestWheel.radsPerSec):
		fastestWheel = poweredWheels[1]
	return fastestWheel
