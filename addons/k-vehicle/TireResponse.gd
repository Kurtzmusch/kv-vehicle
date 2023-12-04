extends Resource

class_name TireResponse

@export var materialName: String

@export_category('Friction')
@export var gripMultiplier: float
@export var gripXCurve: Curve
@export var slipAngleBegin: float
@export var slipAngleEnd: float
@export var gripZCurve: Curve
@export var relativeZSpeedBegin: float
@export var relativeZSpeedEnd: float
@export var useSlipRatio = true
@export var feedbackCurve: Curve

@export_category('Audio')
@export var slippingStream: AudioStream
@export var slipAudioMinimumVelocity = 30.0/3.6
@export var slipAudioMinimumPitch = 1.0
@export var slipAudioMaximumVelocity = 100.0/3.6
@export var slipAudioMaximumPitch = 1.0

## slipping volume transition in seconds
@export var audioVolumeEase = 0.5
@export var rollingStream: AudioStream

@export var bumpHeight = 0.0
@export var bumpNoiseHeight: NoiseTexture2D
@export var bumpNoiseNormal: NoiseTexture2D
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

func getAudioLevels(localVelocity, radsPerSec, radius):
	var slipAngleDeg = rad_to_deg(localVelocity.signed_angle_to(Vector3.FORWARD, Vector3.UP))
	var relativeZSpeed = (radsPerSec*radius)-localVelocity.z
	var relativeVelocity = Vector3(0.0, 0.0, relativeZSpeed)
	if slipAngleDeg > slipAngleBegin:
		relativeVelocity.x = localVelocity.x
	var normalizedSlippingVolume = clamp( relativeVelocity.length(), 0.0, 12.0 )/12.0
	return(normalizedSlippingVolume)

func getSamplePositionX(localVelocity, radsPerSec, radius):
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
	
	
	var samplePosition = max(xSamplePosition, zSamplePosition)
	
	samplePosition = -0.1 + relativeVelocity.length()*0.25
	var x = gripXCurve.sample_baked(samplePosition)
	var z = gripZCurve.sample_baked(samplePosition)
	if abs(relativeZSpeed) < relativeZSpeedBegin:
		#z = ease(lerp(0.0, 1.0, (abs(relativeZSpeed)/relativeZSpeedBegin) ),0.8 )
		z = lerp(0.0, 1.0, (abs(relativeZSpeed)/relativeZSpeedBegin) )
	
	var feedbackRange = slipAngleEnd
	var feedbackSamplePosition = clamp( abs(slipAngleDeg), 0.0, slipAngleEnd )
	var feedback = feedbackCurve.sample_baked(feedbackSamplePosition/feedbackRange)
	
	return samplePosition

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
	
	
	var samplePosition = max(xSamplePosition, zSamplePosition)
	
	samplePosition = -0.1 + relativeVelocity.length()*0.25
	var x = gripXCurve.sample_baked(samplePosition)
	zSamplePosition = samplePosition
	if useSlipRatio:
		var slipRatio = 0.01
		if not localVelocity.z == 0:
			slipRatio = relativeVelocity.z / abs(localVelocity.z)
		zSamplePosition = slipRatio
	var z = gripZCurve.sample_baked(zSamplePosition)
	if abs(relativeZSpeed) < relativeZSpeedBegin:
		#z = ease(lerp(0.0, 1.0, (abs(relativeZSpeed)/relativeZSpeedBegin) ),0.8 )
		z = lerp(0.0, 1.0, (abs(relativeZSpeed)/relativeZSpeedBegin) )
	
	var feedbackRange = slipAngleEnd
	var feedbackSamplePosition = clamp( abs(slipAngleDeg), 0.0, slipAngleEnd )
	var feedback = feedbackCurve.sample_baked(feedbackSamplePosition/feedbackRange)
	
	return Vector3(x*gripMultiplier, feedback, z*gripMultiplier)
