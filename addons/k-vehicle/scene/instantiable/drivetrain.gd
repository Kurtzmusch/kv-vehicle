extends Node
class_name KVDrivetrain
@export var poweredWheels: Array[KVWheel]
@export var engine: Node
@export var clutchMaxTorque = 800.0

@export var gearRatios: Array[float]
@export var finalRatio = 1.0

var currentGearIndex = 0
var gearRatio = 0.0
var neutralGearIndex: int

var _totalWheelMomentOfInertia = 0.0
var vehicle

var clutchInput = 0.0

var prevCT = 0.0

func _ready():
	for idx in range(gearRatios.size()):
		var ratio = gearRatios[idx]
		if is_zero_approx(ratio):
			neutralGearIndex = idx
			break 
	currentGearIndex = neutralGearIndex
	vehicle = get_parent()
	for wheel in poweredWheels:
		wheel.powered = true
		_totalWheelMomentOfInertia += wheel.momentOfInertia

func _physics_process(delta):
	if vehicle.freeze: return
	if Input.is_action_just_pressed('shift+'):
		currentGearIndex += 1 
	if Input.is_action_just_pressed('shift-'):
		currentGearIndex -= 1
	currentGearIndex = clamp(currentGearIndex, 0, gearRatios.size()-1)
	
	
	var samplePosition = engine.revsPerMinute/engine.maxRevsPerMinute
	var t = vehicle.accelerationInput*engine.torqueCurve.sample_baked(samplePosition)*engine.peakTorque
	t /= gearRatio
	var f = t/vehicle.wheels[0].radius

	vehicle.debugString = str((int(f)))

func clutch(delta, oneByDelta, modDelta, oneBySubstep):
	var oneByModDelta = 1.0/modDelta
	if is_zero_approx(gearRatio) or is_zero_approx(clutchInput): return
	var engineAngularModified = engine.radsPerSec*gearRatio
	var wheelAngularModified = -getFastestWheel().radsPerSec/gearRatio
	#var rpsDelta = -getFastestWheel().radsPerSec -engineAngularModified 
	var rpsDelta = wheelAngularModified - engine.radsPerSec
	var ratio1 = engine.momentOfInertia/(_totalWheelMomentOfInertia*gearRatio*gearRatio)
	
	#var torque = (-getFastestWheel().radsPerSec-engineAngularModified)/(-1.0-ratio)
	var torque = (wheelAngularModified-engine.radsPerSec)/(-1.0-ratio1)
	#print('rpsdelta: '+str(snapped(rpsDelta, 0.1))+ ' | t1: '+str(snapped(torque,0.1))+' | '+'t2: '+str(snapped(torque2,0.1)))
	
	var engineMoment = engine.momentOfInertia
	var wheelMoment = _totalWheelMomentOfInertia*gearRatio*gearRatio
	var wheelAngular = -getFastestWheel().radsPerSec/gearRatio
	var engineAngular = engine.radsPerSec
	#print('_____')
	#print(wheelAngular)
	#print(engineAngular)
	
	torque = ((engineMoment*wheelMoment*wheelAngular)-(engineMoment*wheelMoment*engineAngular))/(engineMoment+wheelMoment)
	
	torque*=oneByModDelta
	var torqueEngine = torque#*ratio#*sign(rpsDelta)
	#print(torqueEngine)
	engine.applyTorque(torqueEngine, modDelta)
	var torqueWheels = torque/gearRatio#*sign(rpsDelta)
	#print('rpsDelta: '+ str(rpsDelta) + ' | '+'engineT: '+str(torqueEngine) +' | '+'wheelT: '+str(torqueWheels))
	for wheel in poweredWheels:
		wheel.powered = true
		#wheel.debugString = str( snapped(torqueWheels/poweredWheels.size(),1.0))
		#wheel.debugString = str(snapped(wheel.radsPerSec,1.0))
		wheel.applyTorque(torqueWheels/poweredWheels.size(), modDelta)
	engine.debugString = str( snapped(engine.radsPerSec, 1.0)) + '/' + str(snapped(-poweredWheels[0].radsPerSec/gearRatio,1.0))
	#engine.debugString = str( snapped( engine.radsPerSec- (-poweredWheels[0].radsPerSec/gearRatio), 0.1 ) )
	
	
	
	wheelAngularModified = -getFastestWheel().radsPerSec/gearRatio
	#var rpsDelta = -getFastestWheel().radsPerSec -engineAngularModified 
	rpsDelta = wheelAngularModified - engine.radsPerSec
	#print(str(snapped(rpsDelta, 0.1)))

func _integrate(delta, oneByDelta, modDelta, oneBySubstep):
	gearRatio = gearRatios[currentGearIndex]*finalRatio
	clutchInput = max(0.0, 1.0-Input.get_action_strength('clutch')-vehicle.clutchInput)
	if engine.radsPerSec < engine.idleRadsPerSec+1:
		clutchInput = 0.0
	if is_zero_approx(gearRatio) or is_zero_approx(clutchInput):
		for wheel in poweredWheels:
			wheel.powered = false
		return
	var counterTorque = 0.0
	for wheel in poweredWheels:
		counterTorque -= wheel.frictionTorque*gearRatio
	#var prevEngineRPS = engine.radsPerSec
	#engine.applyTorque((counterTorque+prevCT)*0.45, delta)
	#engine.radsPerSec = max(engine.prevRPS, engine.radsPerSec)
	prevCT = counterTorque
	clutch(delta, oneByDelta, modDelta, oneBySubstep)
	


func getGearRatio():
	return gearRatio

func getFastestWheel():
	#FIXME, consider car going back, reving and releasing the clutch
	var fastestWheel = poweredWheels[0]
	if abs(poweredWheels[1].radsPerSec) > abs(fastestWheel.radsPerSec):
		fastestWheel = poweredWheels[1]
	return fastestWheel
