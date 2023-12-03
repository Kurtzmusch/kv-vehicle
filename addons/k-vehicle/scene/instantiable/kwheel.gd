@icon("res://addons/k-vehicle/car-wheel.svg")
extends Node3D

class_name KVWheel


@export_category('Wheel and Tire')
@export var radius = 0.2
@export var momentOfInertia = 1.0
## overwrites [b]radius[/b] from the computed mesh bounding box
@export var getRadiusFromMeshAABB = false
@export var tireResponses: Array[TireResponse]
var tireResponseDictionary: Dictionary
@export var fidgetFix = true
@export var rpsDeltaThreshold = 1.0

@export_category('Steering')
@export var steer = false
@export var inverseSteering = false
@export var maxSteerAngle = PI/3.0
@export var useAckermanSteering = true

@export_category('Suspension')
@export var stiffness = 4.0
@export_range(0.0,1.0) var compressionDamp = 0.5
@export_range(0.0,1.0) var relaxationDamp = 0.9


@export_category('Physics Tweaking')
## if true, use shapecast collision data for physics.[br]
## shapcasting is currently broken in godot
@export var useShapecastForPhysics = false

## usefull for smoothing sidewalk physics response
@export var normalDirectionLimit = 0.6

## When false, the suspension can apply a force 'downwards'.
## This is unrealistic and can cause the vehicle to 'stick' more to the terrain
## instead of jumping naturally
@export var clampSuspensionForce = true

var debugString: String

var vehicle: KVVehicle

var ackermanSide = 1.0
var ackermanRatio = 1.0
var ackerman = 1.0
var maxSteerAngleActual = 0.0

## the wheel is touching a surface
var grounded = false

var previousCompression = 0.0
var previousGlobalPosition = Vector3.ZERO

var restExtension = 0.0
var maxExtension = 0.0
var restRatio = 1.0

var normalForceAtRest = 0.0
var suspensionForceMagnitude = 0.0
var wheelContribution = 0.25
var massPerWheel = 0.0

var feedback = 0.0

var globalGravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var contactTransform
var localVelocity = Vector3.ZERO

var radsPerSec = 0.0

var relativeZSpeed = 0.0

var breakTorque = 0.0

var powered = false

var frictionTorque = 0.0
var prevFrictionTorque = 0.0
var appliedZFriction = 0.0

var surfaceMaterial: StringName = 'tarmac'

var normalizedCompression = 0.0

var suspensionForce = Vector3.ZERO

var contactRelativeVelocity = Vector3.ZERO

var tireResponse: TireResponse

var targetRPS = 0.0

var traveled = 0.0
var maxTraveled = 32.0


var xFrictionAccumulated = 0.0
var zFrictionAccumulated = 0.0
var frictionColor = Color.RED
var substepZFriction = 0.0

var _steerInverse = 1.0

func findVehicle():
	var parent = get_parent()
	while !(parent is KVVehicle):
		parent = parent.get_parent()
	vehicle = parent

func _enter_tree():
	var newResponses = tireResponses.duplicate()
	newResponses.clear()
	for tireResponse in tireResponses:
		newResponses.append(tireResponse.duplicate())
	tireResponses = (newResponses as Array[TireResponse])
	for tireResponse in tireResponses:
		tireResponseDictionary[tireResponse.materialName] = tireResponse
	
	findVehicle()
	vehicle.wheels.append(self)
	$RayCast3D.add_exception(vehicle)
	$shapecastPivot/ShapeCast3D.add_exception(vehicle)
	
	if getRadiusFromMeshAABB:
		var aabb = $wheelSteerPivot/wheelRollPivot/wheelMesh.mesh.get_aabb()
		radius = aabb.size.y*0.5
		$shapecastPivot/ShapeCast3D.shape.radius = radius
		$shapecastPivot/ShapeCast3D.shape.height = aabb.size.x
	
func updateAckerman(newRatio):
	ackermanRatio = newRatio
	updateMaxSteering()

func _ready():
	updateMaxSteering()
	
	previousGlobalPosition = global_position
	restExtension = abs($wheelSteerPivot.restExtension)#+.2
	maxExtension = abs($wheelSteerPivot.maxExtension)#+.2
	restRatio = restExtension/maxExtension
	wheelContribution = 1.0/vehicle.wheels.size()
	massPerWheel = wheelContribution*vehicle.mass
	normalForceAtRest = vehicle.mass*vehicle.gravity_scale*globalGravity*wheelContribution
	$RayCast3D.target_position.y = -maxExtension-radius
	$shapecastPivot/ShapeCast3D.target_position.z = -maxExtension
	$shapecastPivot/ShapeCast3D.add_exception(get_parent())

func updateMaxSteering():
	ackermanSide = sign(position.x)
	ackerman = ackermanRatio*ackermanSide
	maxSteerAngleActual = -ackerman*maxSteerAngle
	if inverseSteering:
		_steerInverse = -1.0
	else:
		_steerInverse = 1.0

func _physics_process(delta):
	if steer:
		var steerAngleActual = maxSteerAngle
		#var ackermanActual = lerp(1.0, ackermanRatio,\
		#sin( abs(vehicle.normalizedSteering)*PI*0.5 ) )
		var ackermanActual = lerp(1.0, ackermanRatio,abs(vehicle.normalizedSteering) )
		if is_equal_approx( sign(vehicle.normalizedSteering), ackermanSide):
			steerAngleActual = ackermanActual*maxSteerAngle
		$wheelSteerPivot.rotation.y = -vehicle.normalizedSteering*steerAngleActual*_steerInverse
	$shapecastPivot/ShapeCast3D.target_position = (Vector3.DOWN*abs(maxExtension+radius))*$shapecastPivot/ShapeCast3D.global_transform.basis

func updateCasts(state, delta, oneByDelta, contribution):
	contactTransform = null
	
	
	var collisionNormal: Vector3
	var globalCollisionPoint: Vector3
	#var rayCollisionPoint = $RayCast3D.get_collision_point()
	#var shapecastCollisionPoint = $shapecastPivot/ShapeCast3D.get_collision_point(0)
	var collider
	if !useShapecastForPhysics:
		$RayCast3D.force_raycast_update()
		grounded = $RayCast3D.is_colliding()
		if grounded:
			collider = $RayCast3D.get_collider()
			globalCollisionPoint = $RayCast3D.get_collision_point()
			collisionNormal = $RayCast3D.get_collision_normal()
	else:
		$shapecastPivot/ShapeCast3D.force_shapecast_update()
		grounded = $shapecastPivot/ShapeCast3D.is_colliding()
		if grounded:
			collider = $shapecastPivot/ShapeCast3D.get_collider(0)
			collisionNormal = $shapecastPivot/ShapeCast3D.get_collision_normal(0)
			globalCollisionPoint = $shapecastPivot/ShapeCast3D.get_collision_point(0)
	
	if collisionNormal.dot(global_transform.basis.y) < normalDirectionLimit:
		collisionNormal = collisionNormal.slerp(global_transform.basis.y, 0.9)
	
	#var collider = $RayCast3D.get_collider()
	
	
	var globalVelocity = oneByDelta*(global_position-previousGlobalPosition+vehicle.teleportDelta)
	traveled+=globalVelocity.length()*delta
	traveled = fmod(traveled , maxTraveled)
	if grounded:
		
		surfaceMaterial = StringName('tarmac')
		if collider.has_meta('material'):
			var surfaceMaterialString = collider.get_meta('material')
			surfaceMaterial = surfaceMaterialString
		tireResponse = tireResponseDictionary[surfaceMaterial] 
		var bumpStrength = tireResponse.sampleBumpNoise(traveled/maxTraveled)
		globalCollisionPoint += collisionNormal*bumpStrength
		debugString = str( snapped( bumpStrength, 0.01) )
		contactTransform = Transform3D()
		contactTransform.origin = globalCollisionPoint
		contactTransform.basis.y = collisionNormal
		#var basisZ = collisionNormal.cross($wheelSteerPivot.global_transform.basis.x).normalized()
		var basisZ = $wheelSteerPivot.global_transform.basis.x.cross(collisionNormal).normalized()
		var basisX = collisionNormal.cross(basisZ)
		contactTransform.basis.z = basisZ
		contactTransform.basis.x = basisX
		
		localVelocity = contactTransform.basis.inverse() * globalVelocity
		targetRPS = localVelocity.z/radius
		var slipAngleDeg = rad_to_deg(localVelocity.signed_angle_to(Vector3.FORWARD, Vector3.UP))
		var relativeZSpeed = (radsPerSec*radius)-localVelocity.z
		contactRelativeVelocity = Vector3(localVelocity.x, 0.0, relativeZSpeed)
		
		$Particles.global_transform = contactTransform
		
		$contactTransform.clear()
		$contactTransform.addVector(contactTransform.origin, contactTransform.basis.y, Color.GREEN_YELLOW)
		$contactTransform.addVector(contactTransform.origin, contactTransform.basis.x, Color.INDIAN_RED)
		$contactTransform.addVector(contactTransform.origin, contactTransform.basis.z, Color.SKY_BLUE)
	else:
		feedback = 0.0
		normalizedCompression = 0.0
		suspensionForceMagnitude = 0.0
		$wheelSteerPivot.position.y = -maxExtension
		$RollingAudioStreamPlayer3D.volume_db = linear_to_db(0.0)
		$SlippingAudioStreamPlayer3D.volume_db = linear_to_db(0.0)
	previousGlobalPosition = global_position
	xFrictionAccumulated = 0.0
	zFrictionAccumulated = 0.0

func applyAccumulatedFrictionForces(state):
	if !grounded: return
	vehicle.applyGlobalForceState(xFrictionAccumulated*-contactTransform.basis.x, contactTransform.origin, state, frictionColor)
	vehicle.applyGlobalForceState(zFrictionAccumulated*contactTransform.basis.z, contactTransform.origin, state, Color.BLUE_VIOLET)

func applyFrictionForces(state, delta, oneByDelta, modDelta, oneBySubstep, contribution):
	if !grounded: return
	var oneByModDelta = 1.0/modDelta
	var necessaryXFriction = localVelocity.x*oneByDelta*massPerWheel*0.9
	relativeZSpeed = (radsPerSec*radius)-(localVelocity.z)
	var necessaryZFriction = relativeZSpeed*oneByDelta*massPerWheel*0.9
	
	
	var coeficients = tireResponse.getCoeficients(localVelocity, radsPerSec, radius)
	#debugString = str( snapped(tireResponse.getSamplePositionX(localVelocity, radsPerSec, radius),0.1))
	var stream = tireResponse.slippingStream
	
	feedback = coeficients.y
	
	var xFriction = min(abs(necessaryXFriction), coeficients.x*suspensionForceMagnitude)
	var zFriction = min(abs(necessaryZFriction), coeficients.z*suspensionForceMagnitude)
	zFriction = coeficients.z*suspensionForceMagnitude
	
	zFriction *= sign(necessaryZFriction)
	xFriction *= sign(necessaryXFriction)
	frictionColor = Color.RED
	#debugString = str( snapped(coeficients.x, 0.1)
	var frictionFraction = coeficients.x/tireResponse.gripMultiplier
	#debugString = str( snapped(frictionFraction, 0.1 ) )
	if coeficients.x < tireResponse.gripMultiplier:
		frictionColor = frictionColor.lerp(Color.YELLOW, 1.0-frictionFraction )
	#vehicle.applyGlobalForceState(xFriction*-contactTransform.basis.x, contactTransform.origin, state, frictionColor)
	substepZFriction = zFriction*oneBySubstep
	xFrictionAccumulated += xFriction*oneBySubstep
	#vehicle.applyGlobalForceState(zFriction*contactTransform.basis.z, contactTransform.origin, state, Color.BLUE_VIOLET)
	zFrictionAccumulated += zFriction*oneBySubstep
	#applyTorqueFromFriction(zFriction, delta, relativeZSpeed)
	
	appliedZFriction = zFriction
	
	
	tireResponse.handleAudio(delta, $RollingAudioStreamPlayer3D, $SlippingAudioStreamPlayer3D, localVelocity, radsPerSec, radius)
	#tireResponse.handleParticles(delta, localVelocity, radsPerSec, radius)

func animate(delta, oneByDelta):
	if fidgetFix and ( abs(targetRPS-radsPerSec) < rpsDeltaThreshold):
		$wheelSteerPivot/wheelRollPivot.rotation.x += targetRPS*delta
	else:
		$wheelSteerPivot/wheelRollPivot.rotation.x += radsPerSec*delta
	#applyTorqueFromFriction(delta, oneByDelta)

func applyTorqueFromFriction(delta, oneByDelta, modDelta, oneBySubstep):
	if grounded:
		appliedZFriction = substepZFriction
		#var targetRPS = localVelocity.z/radius
		var prevRPS = radsPerSec
		frictionTorque = -appliedZFriction*radius
		#frictionTorque = (frictionTorque+prevFrictionTorque)*0.5
		prevFrictionTorque = frictionTorque
		#if !powered:
		applyTorque(frictionTorque*1.0, delta)
		#debugString = str( snapped(frictionTorque, 0.1) )
		var newRelativeZspeed = (radsPerSec*radius)-(localVelocity.z)
		
		#if !is_zero_approx(prevRPS):
		if sign(newRelativeZspeed) != sign(relativeZSpeed):
			#pass
			if !powered:
				pass
				#radsPerSec = targetRPS
	_breakTorque(delta, oneByDelta, modDelta, oneBySubstep)
	
	#debugString = str(snapped(radsPerSec, 1))+'/'+str(snapped(targetRPS, 1))

func _breakTorque(delta, oneByDelta, modDelta, oneBySubstep):
	var signBefore = sign(radsPerSec)
	applyTorque(abs(breakTorque)*-sign(radsPerSec), delta)
	var signAfter = sign(radsPerSec)
	if (signBefore != signAfter):
		radsPerSec = 0.0
	breakTorque = 0.0

func applyBreakTorque(torque, delta):
	"""
	var signBefore = sign(radsPerSec)
	applyTorque(torque, delta)
	var signAfter = sign(radsPerSec)
	if signBefore != signAfter:
		radsPerSec = 0.0
	"""
	breakTorque += abs(torque)

func applyTorque(torque, delta):
	#debugString = str(torque)
	radsPerSec += torque/(momentOfInertia)*delta

func applySuspensionForce(state, delta, oneByDelta, contribution):
	if !grounded: return
	
	var wheelPivotPositionY = to_local(contactTransform.origin).y+radius
	wheelPivotPositionY = min(wheelPivotPositionY, 0.0)
	normalizedCompression = 1.0-abs(wheelPivotPositionY)/maxExtension
	var compression = remap(normalizedCompression,\
	(1.0-restRatio), 1.0,\
	1.0, stiffness)
	compression = clamp(compression, 0.0, stiffness)
	
	var compressionDelta = compression-previousCompression
	compressionDelta*=oneByDelta
	var damp = 0.0
	if compressionDelta > 0.0:
		damp = compressionDamp
	else:
		damp = relaxationDamp
	damp *= compressionDelta*vehicle.mass*wheelContribution
	suspensionForceMagnitude = compression*normalForceAtRest
	suspensionForceMagnitude += damp
	if clampSuspensionForce:
		suspensionForceMagnitude = max(0.0, suspensionForceMagnitude)
	
	suspensionForce = suspensionForceMagnitude*contactTransform.basis.y
	
	vehicle.applyGlobalForceState(suspensionForce, contactTransform.origin, state, Color.GREEN)
	
	$wheelSteerPivot.position.y = wheelPivotPositionY
	previousCompression = compression
