extends Resource

## defines a tire response to be used by a vehicle wheel
## handles friction and audio responses for when a wheel is in contact with a material
class_name TireResponse

## the name of the material.
## the response is used when a [CollisionObject3D]s 'material' meta matches the materialName
@export var materialName: String

@export_category('Friction')
## coeficient of friction for this material
@export var coeficientOfFriction = 1.0
## ease curve that controls how much the grip changes with normal load.
## [br] 1.0 = linear
@export_range(0.1, 1.0) var loadEase = 1.0

## clamps the net friction instead of it's individual components
##[br] prevents breaking steering the vehicle in the opposite direction when using a lot of maxSteerAngle
##[br] makes drifting easier, since a large longitudinal vector from accceleration or handbraking will cause a reduction in sideways friction
@export var clampAfterCombining = true
## [br] tire friction grows proportional to the normal load, but only up to a certain amount
@export var maxNormalLoadCoeficient = 8.0
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

@export_category('Audio')
## [AudioStream] to be used when the tire is slipping
@export var slippingStream: AudioStream
## velocity (meters/second) of the contact patch relative to ground to start playing the audio
@export var slipAudioMinimumVelocity = 30.0/3.6
## audio pitch when the contact patch is at minimum velocity
@export var slipAudioMinimumPitch = 1.0
## velocity (meters/second) of the contact patch relative to ground to use maximum pitch
@export var slipAudioMaximumVelocity = 100.0/3.6
## audio pitch at maximum velocity
@export var slipAudioMaximumPitch = 1.0

## slipping volume transition in seconds
@export var audioVolumeEase = 0.5
## [AudioStream] to be used when the tire is rolling
@export var rollingStream: AudioStream

## height (meters) of ground bumps
@export var bumpHeight = 0.0
## noise image to sample the bump height
@export var bumpNoiseHeight: NoiseTexture2D
## noise image to sample the bump normal
@export var bumpNoiseNormal: NoiseTexture2D
## how much the bump influences the physics:
## [br]1.0: bumps are only visual on the wheel
## [br]0.0: bumps are visual and have full influence on the suspension
@export var bumpVisualBias = 0.0
var bumpNoiseHeightValues: PackedFloat32Array
var bumpNoiseNormalValues: PackedColorArray

func sampleBumpNormal(normalizedTraveled):
	if !bumpNoiseNormal: return Vector3.UP
	if !bumpNoiseNormalValues:
		var bumpNoiseNormalImage = bumpNoiseNormal.get_image()
		if bumpNoiseNormalImage:
			for i in range(bumpNoiseNormal.width):
				var color = bumpNoiseNormalImage.get_pixel(i, 0)
				bumpNoiseNormalValues.append( color )
		return Vector3.UP
	
	var sampleIdx = int(normalizedTraveled*bumpNoiseNormalValues.size())
	var color = bumpNoiseNormalValues[sampleIdx]
	var normal = Vector3( (2.0*color.r)-1.0,\
	(2.0*color.b)-1.0,\
	(2.0*color.g)-1.0 )
	return normal

func sampleBumpHeight(normalizedTraveled):
	if !bumpNoiseHeight: return 0.0
	if !bumpNoiseHeightValues:
		var bumpNoiseImage = bumpNoiseHeight.get_image()
		if bumpNoiseImage:
			for i in range(bumpNoiseHeight.width):
				var color = bumpNoiseImage.get_pixel(i, 0)
				bumpNoiseHeightValues.append( (color.r-0.5)*2.0 )
		return 0.0
	
	var sampleIdx = int(normalizedTraveled*bumpNoiseHeightValues.size())
	
	return bumpNoiseHeightValues[sampleIdx]*bumpHeight

func handleAudio(delta, rollingPlayer: AudioStreamPlayer3D, slippingPlayer: AudioStreamPlayer3D, localVelocity, radsPerSec, radius):
	var relativeVelocity = getVelocity(localVelocity, radsPerSec, radius)
	
	if slippingPlayer.stream != slippingStream:
		slippingPlayer.stream = slippingStream
		slippingPlayer.play()
	if rollingPlayer.stream != rollingStream:
		rollingPlayer.stream = rollingStream
		rollingPlayer.play()
	
	#var rolling = localVelocity.z
	var slippingPitch = 0.0
	var relativeVelocityMagnitude = relativeVelocity.length()
	var targetVolume = 0.0
	if  relativeVelocityMagnitude > slipAudioMinimumVelocity:
		slippingPitch = remap( relativeVelocityMagnitude,\
		slipAudioMinimumVelocity, slipAudioMaximumVelocity,\
		slipAudioMinimumPitch, slipAudioMaximumPitch )
		targetVolume = 1.0
	
	var currentVolume = db_to_linear(slippingPlayer.volume_db)
	currentVolume = move_toward(currentVolume, targetVolume, delta*audioVolumeEase)
	if is_zero_approx(targetVolume):
		currentVolume = 0.0
	slippingPlayer.volume_db = linear_to_db(currentVolume)
	slippingPlayer.pitch_scale = clamp(slippingPitch, slipAudioMinimumPitch, slipAudioMaximumPitch)
 
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
