extends TireResponse

## defines a tire response to be used by a vehicle wheel
## handles friction and audio responses for when a wheel is in contact with a material
class_name TireResponseKV




## ease curve that controls how much the grip changes with normal load.
## [br] 1.0 = linear
@export_range(0.1, 1.0) var loadEase = 1.0

## clamps the net friction instead of it's individual components
##[br] prevents breaking steering the vehicle in the opposite direction when using a lot of maxSteerAngle
##[br] makes drifting easier, since a large longitudinal vector from accceleration or handbraking will cause a reduction in sideways friction
@export var clampAfterCombining = true

## curve that multiplies the coeficientOfFriction, depending on slip angle
@export var gripXCurve: Curve
## use an ease buildup curve for when the slip angle is smalelr then [member slipAngleBegin]
## [br]
@export var useBuildupEase = false
## ease value to be used for the buildup curve:
## [br] smaller values are more responsive to steering, bigger values will feel less responsive, more floaty/slippery
@export var buildupEase = 0.01
## slip angle that maps to the beginning of the curve
@export var slipAngleBegin = 8.0
## slip angle that maps to the end of the curve
@export var slipAngleEnd  = 12.0


## curve that multiplies the coeficientOfFriction, depending on relative longitudinal speed of the contact patch or slip ratio of the contact patch
@export var gripZCurve: Curve
## relative longitudinal speed(between ground and contact patch) that maps to the beginning of the curve
@export var relativeZSpeedBegin: float
## relative longitudinal speed(between ground and contact patch) that maps to the end of the curve
@export var relativeZSpeedEnd: float

## use slip ratio instead of relative longitudinal velocity
@export var useSlipRatio = true
@export var feedbackCurve: Curve

func getVelocity(localVelocity, radsPerSec, radius):
	var slipAngleDeg = rad_to_deg(localVelocity.signed_angle_to(Vector3.FORWARD, Vector3.UP))
	var relativeZSpeed = (radsPerSec*radius)-localVelocity.z
	var relativeVelocity = Vector3(0.0, 0.0, relativeZSpeed)
	if abs(slipAngleDeg) > slipAngleBegin:
		relativeVelocity.x = localVelocity.x
	return relativeVelocity

func getFrictionForces(localVelocity, radsPerSec, radius, slipAngle, desiredFrictionVec, gripMultiplier, normalForce, loadFactor, normalForceAtRest):
	var coeficients = getCoeficients(localVelocity, radsPerSec, radius)
	var normalForceModified = normalForceAtRest*pow(loadFactor, loadEase)
	
	var frictionForce
	if clampAfterCombining:
		frictionForce = clampCombined(slipAngle, desiredFrictionVec, coeficients, gripMultiplier, normalForceModified)
	else:
		frictionForce = clampIndividual(desiredFrictionVec, coeficients, gripMultiplier, normalForceModified )
	return frictionForce

func clampIndividual(desiredFrictionVec, coeficients, gripMultiplier, normalForce ):

	var xFriction = min(abs(desiredFrictionVec.x), coeficients.x*gripMultiplier.x*normalForce)
	var zFriction = min(abs(desiredFrictionVec.z), coeficients.z*gripMultiplier.z*normalForce)
	#zFriction = coeficients.z*gripMultiplier.x*maxedSuspensionForce
	#xFriction = coeficients.x*suspensionForceMagnitude
	xFriction *= sign(desiredFrictionVec.x)
	zFriction *= sign(desiredFrictionVec.z)
	
	return Vector3(xFriction, coeficients.y, zFriction)

func clampCombined(slipAngle, desiredFrictionVec, coeficients, gripMultiplier, normalForce):
	var xFriction = min(abs(desiredFrictionVec.x), coeficients.x*gripMultiplier.x*normalForce)
	var zFriction = min(abs(desiredFrictionVec.z), coeficients.z*gripMultiplier.z*normalForce)
	xFriction *= sign(desiredFrictionVec.x)
	zFriction *= sign(desiredFrictionVec.z)
	if useBuildupEase and abs(desiredFrictionVec.x) > 0.0:
		#desiredFricionVec = Vector3(xFriction, 0.0, necessaryZFriction)
		desiredFrictionVec *= abs(xFriction)/abs(desiredFrictionVec.x)
	var maxX = coeficients.x*gripMultiplier.x
	var maxZ = coeficients.z*gripMultiplier.z
	if abs(slipAngle) < deg_to_rad( slipAngleBegin ):
		maxX = coeficientOfFriction*gripMultiplier.x
	
	var maxFricLen = min(maxX, maxZ)*normalForce
	
	if desiredFrictionVec.length() > maxFricLen:
		desiredFrictionVec = desiredFrictionVec.normalized()*maxFricLen
	
	return Vector3(desiredFrictionVec.x, coeficients.y, desiredFrictionVec.z)

func getCoeficients(localVelocity, radsPerSec, radius):
	var slipAngleDeg = rad_to_deg(localVelocity.signed_angle_to(Vector3.FORWARD, Vector3.UP))
	var relativeZSpeed = (radsPerSec*radius)-localVelocity.z
	
	var relativeVelocity = Vector3(0.0, 0.0, relativeZSpeed)
	if abs(slipAngleDeg) > slipAngleBegin:
		relativeVelocity.x = localVelocity.x
	
	var xRange = slipAngleEnd-slipAngleBegin
	var xSamplePosition = clamp( abs(slipAngleDeg), slipAngleBegin, slipAngleEnd )
	xSamplePosition = (xSamplePosition-slipAngleBegin)/xRange
	
	var zRange = relativeZSpeedEnd-relativeZSpeedBegin
	
	var zSamplePosition = clamp( abs(relativeZSpeed), relativeZSpeedBegin, relativeZSpeedEnd )
	zSamplePosition = (zSamplePosition-relativeZSpeedBegin)/zRange
	
	
	#var samplePosition = max(xSamplePosition, zSamplePosition)
	#samplePosition = -0.1 + relativeVelocity.length()*0.25
	#zSamplePosition = samplePosition
	#xSamplePosition = samplePosition
	
	var x = gripXCurve.sample_baked(xSamplePosition)
	if useBuildupEase:
		if abs(slipAngleDeg) < slipAngleBegin:
			x = ease(abs(slipAngleDeg)/slipAngleBegin, buildupEase)
	
	if useSlipRatio:
		var slipRatio = 0.000976562
		if not localVelocity.z == 0:
			slipRatio = relativeVelocity.z / abs(localVelocity.z)
		zSamplePosition = slipRatio
	var z = gripZCurve.sample_baked(zSamplePosition)
	""" this easing improves stability but breaks KVWheels clampAfterCombining
	# does not seem necessary when using substeps
	if abs(relativeZSpeed) < relativeZSpeedBegin:
		#z = ease(lerp(0.0, 1.0, (abs(relativeZSpeed)/relativeZSpeedBegin) ),0.8 )
		z = lerp(0.0, 1.0, (abs(relativeZSpeed)/relativeZSpeedBegin) )
	"""
	#if z > x: z = x
	var feedbackRange = slipAngleEnd
	var feedbackSamplePosition = clamp( abs(slipAngleDeg), 0.0, slipAngleEnd )
	var feedback = feedbackCurve.sample_baked(feedbackSamplePosition/feedbackRange)
	return Vector3(x*coeficientOfFriction, feedback*sign(slipAngleDeg), z*coeficientOfFriction)
