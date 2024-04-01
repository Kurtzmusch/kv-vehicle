extends KVComponent
## implements a drivetrain with clutch and gearbox
##
## angular velocity is transfered from the engine to the powered wheels using a clutch
## that applies opossite torque on both sides

class_name KVDrivetrain
## wheels to be powered by this drivetrain
@export var poweredWheels: Array[KVWheel]
## engine that powers this drivetrain
@export var engine: Node
# FIXME, this torque should probably be *oneModDelta
## maximum torque of the clutch, use 0.0 for infinite torque. should be generally higher then the engine torque
@export var clutchMaxTorque = 0.0

## the gear ratios of the gearbox, example: 0.1, 0.0, 0.15, 0.3, 0.5
## [br]use negative ratios for reverse and 0.0 for neutral
@export var gearRatios: Array[float] = [-0.15, 0.0, 0.25, 0.5]
## final ratio that gets multiplied by gear ratio from the gearbox: 0.3
@export var finalRatio = 0.3


## overwrites the clutch input if engine angular velocity is below minimum
@export var autoClutch = true

var currentGearIndex = 0
var gearRatio = 0.0
var neutralGearIndex: int

var _totalWheelMomentOfInertia = 0.0
var vehicle

var clutchInput = 0.0

var prevCT = 0.0

var wheelEngineAngularDelta = 0.0

var rpsDelta = 0.0

func _ready():
	for idx in range(gearRatios.size()):
		var ratio = gearRatios[idx]
		if is_zero_approx(ratio):
			neutralGearIndex = idx
			break 
	currentGearIndex = neutralGearIndex
	vehicle = get_parent()
	updatePoweredWheels()

func updatePoweredWheels():
	_totalWheelMomentOfInertia = 0.0
	for wheel in poweredWheels:
		wheel.powered = true
		_totalWheelMomentOfInertia += wheel.momentOfInertia

func shiftIntoGear(gearIndex):
	if vehicle.freeze: return
	currentGearIndex = gearIndex 
	currentGearIndex = clamp(currentGearIndex, 0, gearRatios.size()-1)

func shiftGear(gearOffset):
	if vehicle.freeze: return
	currentGearIndex += gearOffset 
	currentGearIndex = clamp(currentGearIndex, 0, gearRatios.size()-1)

func _physics_process(delta):
	if vehicle.freeze: return
	
	
	var samplePosition = engine.revsPerMinute/engine.maxRevsPerMinute
	var t = vehicle.accelerationInput*engine.torqueCurve.sample_baked(samplePosition)*engine.peakTorque
	t /= gearRatio
	var f = t/vehicle.wheels[0].radius

	#vehicle.debugString = str((int(f)))

func clutch(delta, oneByDelta, modDelta, oneBySubstep):
	var oneByModDelta = 1.0/modDelta
	if is_zero_approx(gearRatio) or is_zero_approx(clutchInput): return
	var engineAngularModified = engine.radsPerSec*gearRatio
	var wheelAngularModified = -getFastestWheel().radsPerSec/gearRatio
	#var rpsDelta = -getFastestWheel().radsPerSec -engineAngularModified 
	rpsDelta = wheelAngularModified - engine.radsPerSec
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
	vehicle.debugString = str( int(wheelAngularModified) )
	vehicle.debugString += '/' + str(int(engine.radsPerSec))
	
	torque*=oneByModDelta
	if clutchMaxTorque > 0.0:
		var maxTorqueActual = clutchMaxTorque*clutchInput
		#vehicle.debugString = str( snapped(abs(torque)/maxTorqueActual, 0.01) )
		torque = sign(torque) * min(abs(torque), maxTorqueActual)
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
	var fastestWheelModAV = -getFastestWheel().radsPerSec/gearRatio
	if autoClutch:
		if (engine.radsPerSec < engine.idleRadsPerSec+1) and fastestWheelModAV < engine.idleRadsPerSec+1:
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
	for wheel in poweredWheels:
		var wheelRelativeAV = wheel.radsPerSec*sign(gearRatio)-engine.radsPerSec
		var fastestWheelrelativeAV = fastestWheel.radsPerSec*sign(gearRatio)-engine.radsPerSec
		if abs(wheelRelativeAV) > abs(fastestWheelrelativeAV):
			fastestWheel = wheel
	return fastestWheel
