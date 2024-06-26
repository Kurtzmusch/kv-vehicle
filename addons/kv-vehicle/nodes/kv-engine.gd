extends KVComponent
## engine meant to work with [KVDrivetrain]
## 
## will rev itself but won't apply any torque to wheels

class_name KVEngine

@export var torqueCurve: Curve
@export var peakTorque = 400.0
@export var maxRevsPerMinute = 6500.0
@export var idleRevsPerMinute = 800.0
@export var internalFrictionTorque = 100.0
## additional friction torque to be applied when vehicle acceleration input is 0.0
@export var breakTorque = 100.0
## torque applyed when engine revs are above maximum, multiplied by peakToruqe
@export var limmiterCounterTorqueRatio = 8.0
## how difficult the engine is to rev,
## but also how much energy it stores when
## revving with the clutch depressed
@export var momentOfInertia = 1.0

var radsPerSec = idleRevsPerMinute*TAU/60.0
var revsPerMinute = idleRevsPerMinute

var maxRadsPerSec = 0.0
var idleRadsPerSec = 0.0

var vehicle

var debugString: String

var prevRPS

func _ready():
	vehicle = get_parent()
	maxRadsPerSec = maxRevsPerMinute*TAU/60.0
	idleRadsPerSec = idleRevsPerMinute*TAU/60.0

func _process(delta):
	pass

func _physics_process(delta):
	revsPerMinute = radsPerSec/TAU*60.0
	#debugString = str( 'rps: ' + str(snapped(radsPerSec,1))+'\n'+\
	#'rpm: '+str(snapped(revsPerMinute,1)) )

func applyTorque(torque, delta):
	radsPerSec += torque/momentOfInertia*delta
	radsPerSec = max(radsPerSec, idleRadsPerSec)

func _integrate(delta, oneByDelta, modDelta, oneBySubstep):
	revsPerMinute = radsPerSec/TAU*60.0
	var samplePosition = revsPerMinute/maxRevsPerMinute
	var torque = vehicle.accelerationInput*torqueCurve.sample_baked(samplePosition)*peakTorque
	torque -= internalFrictionTorque
	#torque -= breakTorque*(1.0-sign(abs(vehicle.accelerationInput)))
	var bT = -breakTorque*(1.0-sign(abs(vehicle.accelerationInput)))
	if radsPerSec > maxRadsPerSec:
		torque = -peakTorque*limmiterCounterTorqueRatio
	applyTorque(bT, modDelta)
	prevRPS = radsPerSec
	applyTorque(torque, modDelta)
