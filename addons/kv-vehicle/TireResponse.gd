extends Resource

## defines a tire response to be used by a vehicle wheel.
##[br] handles audio and bump when a wheel is in contact with a material.
##[br] extensions of this class must provide a friction response, see [TireResponseKV], [TireResponseBrushWolfie]
class_name TireResponse

## the name of the material.
## the response is used when a [CollisionObject3D]s 'material' meta matches the materialName
@export var materialName: String

@export_category('Friction')
## [br] tire friction grows proportional to the normal load, but only up to a certain amount
@export var maxNormalLoadCoeficient = 8.0
## coeficient of friction for this material
@export var coeficientOfFriction = 1.0

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

@export_category('Bumps')
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
	var relativeVelocity = Vector3(localVelocity.x, 0.0, relativeZSpeed)
	
	return relativeVelocity


func getFrictionForces(localVelocity, radsPerSec, radius, slipAngle, desiredFrictionVec, gripMultiplier, normalForce, loadFactor, normalForceAtRest):
	assert(false, 'The base TireResponse does not apply friction.')
	return Vector3.ZERO

func clampIndividual(desiredFrictionVec, coeficients, gripMultiplier, normalForce ):

	var xFriction = min(abs(desiredFrictionVec.x), coeficients.x*gripMultiplier.x*normalForce)
	var zFriction = min(abs(desiredFrictionVec.z), coeficients.z*gripMultiplier.z*normalForce)
	#zFriction = coeficients.z*gripMultiplier.x*maxedSuspensionForce
	#xFriction = coeficients.x*suspensionForceMagnitude
	xFriction *= sign(desiredFrictionVec.x)
	zFriction *= sign(desiredFrictionVec.z)
	
	return Vector3(xFriction, coeficients.y, zFriction)

func getCoeficients(localVelocity, radsPerSec, radius):
	return Vector3.ZERO
