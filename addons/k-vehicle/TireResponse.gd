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

@export_category('Particles')
#@export var slippingParticleMaterial: ParticleProcessMaterial
@export var slippingParticleScenes: Array[PackedScene]
@export var slippingEmitThreshold = 1.0
#@export var rollingParticleMaterial: ParticleProcessMaterial
@export var rollingEmitThreshold = 1.0


var _particleNodes: Array

func populateParticles(particleContainer: Node3D):
	_particleNodes = Array()
	for scene in slippingParticleScenes:
		var parts = scene.instantiate()
		_particleNodes.append(parts)
		particleContainer.add_child(parts)

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
 
func handleParticles(delta,  localVelocity, radsPerSec, radius):
	var relativeVelocity = getVelocity(localVelocity, radsPerSec, radius)
	
	"""
	if slippingParticles.process_material != slippingParticleMaterial:
		slippingParticles.process_material = slippingParticleMaterial
	if rollingParticles.process_material != rollingParticleMaterial:
		rollingParticles.process_material = rollingParticleMaterial
	"""
	#var rolling = localVelocity.z
	
	#slippingParticles.emitting = relativeVelocity.length() > slippingEmitThreshold
	#rollingParticles.emitting = relativeVelocity.length() > rollingEmitThreshold
	for parts in _particleNodes:
		parts.emitting = relativeVelocity.length() > slippingEmitThreshold

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
	samplePosition = -0.1 + relativeVelocity.length()*0.125
	var x = gripXCurve.sample_baked(samplePosition)
	var z = gripZCurve.sample_baked(samplePosition)
	
	var feedbackRange = slipAngleEnd
	var feedbackSamplePosition = clamp( abs(slipAngleDeg), 0.0, slipAngleEnd )
	var feedback = feedbackCurve.sample_baked(feedbackSamplePosition/feedbackRange)
	
	return Vector3(x*gripMultiplier, feedback, z*gripMultiplier)
