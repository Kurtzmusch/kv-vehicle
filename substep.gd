extends Node3D


var useSlipRatio = false
var substeps = 5

var secondsToSimulate = 4
var del = 1.0/100.0
var gearRatio = 0.3
var eTorque = 250.0/gearRatio
var radius = 0.3
var momentOfInertia = 0.675*10#(0.3*0.3)*0.5*15.0

var mass = 4000.0

var linearVelX = 0.0
var xpos = 0.0
var prevXpos = 0.0
var normalMag = mass*10.0

var radsPerSec = 0.0

@export var tireResponse: Curve
var gripMult = 1.2
var relativeZSpeedEnd = 4.0
var relativeZSpeedBegin = 0.2

var ticksToSimulate = 0.0
var f = 0.0

var ft = 0.0
func _ready():
	$zero.add_point(Vector2(0, 270))
	$zero.add_point(Vector2(960, 270.0))
	ticksToSimulate = secondsToSimulate/del
	print(ticksToSimulate)
	for i in range( round(ticksToSimulate) ):
		var prevRadsPerSec = radsPerSec
		if substeps > 1:
			simulateSubstep(del)
		else:
			simulateNormal(del)
		var rpsDelta = (radsPerSec-prevRadsPerSec) * 8
		$rpsDelta.add_point(Vector2(float(i)/float(ticksToSimulate)*960, 270.0+rpsDelta))
		$dforce.add_point(Vector2(float(i)/float(ticksToSimulate)*960, 270.0+ f*200))
	print('vel kmh: ' + str(linearVelX*3.6))
	print('distanceTraveled: ' + str(xpos))
	

func engineTorque(d):
	applyTorque(eTorque, d)

func simulateSubstep(d):
	xpos += linearVelX *d
	
	var xdelta = xpos - prevXpos
	prevXpos = xpos
	var xvel = xdelta/d
	var modD = d/substeps
	for i in range(substeps):
		
		engineTorque(modD)
		
		var relativeXspeed = (radsPerSec*radius)-xvel
		var z_slip = 0.01
		if not xvel == 0:  z_slip = (radsPerSec * radius - xvel) / abs(xvel)
		var param = z_slip
		if !useSlipRatio: param = relativeXspeed
		f = sign(z_slip)*getCoeficients(param, radsPerSec, radius)
		applyFriction(f*normalMag, modD)
		applyTorqueFromFriction(f*normalMag, modD)

func simulateNormal(d):
	xpos += linearVelX *d
	engineTorque(d)
	var xdelta = xpos - prevXpos
	prevXpos = xpos
	var xvel = xdelta/d
	var relativeXspeed = (radsPerSec*radius)-xvel
	var z_slip = 0.01
	if not xvel == 0:  z_slip = (radsPerSec * radius - xvel) / abs(xvel)
	var param = z_slip
	if !useSlipRatio: param = relativeXspeed
	f = sign(z_slip)*getCoeficients(param, radsPerSec, radius)
	applyFriction(f*normalMag, d)
	applyTorqueFromFriction(f*normalMag, d)
	

func applyTorqueFromFriction(friction, d):
	var torque = friction*radius*gearRatio
	#ft = torque
	applyTorque(-torque, d)

func applyFriction(force, d):
	applyForce(force, d)

func applyForce(force, d):
	linearVelX += force/mass *d

func applyTorque(torque, d):
	radsPerSec += torque/momentOfInertia *d
	

func getCoeficients(relativeXspeed, radsPerSec, radius):
	var zRange = relativeZSpeedEnd-relativeZSpeedBegin
	
	var zSamplePosition = clamp( abs(relativeXspeed), relativeZSpeedBegin, relativeZSpeedEnd )
	zSamplePosition = (zSamplePosition-relativeZSpeedBegin)/zRange
	
	var samplePosition = -0.1 + abs(relativeXspeed)*0.25
	var z = tireResponse.sample_baked(samplePosition)
	if abs(relativeXspeed) < relativeZSpeedBegin:
		#z = ease(lerp(0.0, 1.0, (abs(relativeZSpeed)/relativeZSpeedBegin) ),0.8 )
		z = lerp(0.0, 1.0, (abs(relativeXspeed)/relativeZSpeedBegin) )
		
	return z*gripMult
