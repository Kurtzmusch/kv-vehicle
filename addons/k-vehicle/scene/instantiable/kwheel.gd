extends Node3D

class_name KWheel

@export_category('Wheel and Tire')
@export var radius = 0.2
@export var momentOfInertia = 1.0
## overwrites [b]radius[/b] from the computed mesh bounding box
@export var getRadiusFromMeshAABB = false
@export var tireResponses: Array[TireResponse]
var tireResponseDictionary: Dictionary

@export_category('Steering')
@export var steer = false
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

var debugString: String

var vehicle: KVehicle

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

func findVehicle():
	var parent = get_parent()
	while !(parent is KVehicle):
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
	$ShapeCast3D.add_exception(vehicle)
	
	if getRadiusFromMeshAABB:
		radius = $wheelSteerPivot/wheelRollPivot/wheelMesh.mesh.get_aabb().size.y*0.5

func _ready():
	calculateAckerman()
	maxSteerAngleActual = -ackerman*maxSteerAngle
	previousGlobalPosition = global_position
	restExtension = abs($wheelSteerPivot.restExtension)#+.2
	maxExtension = abs($wheelSteerPivot.maxExtension)#+.2
	restRatio = restExtension/maxExtension
	wheelContribution = 1.0/vehicle.wheels.size()
	massPerWheel = wheelContribution*vehicle.mass
	normalForceAtRest = vehicle.mass*vehicle.gravity_scale*globalGravity*wheelContribution
	$RayCast3D.target_position.y = -maxExtension-radius
	$ShapeCast3D.target_position.z = -maxExtension
	for r in tireResponses:
		r.populateParticles($Particles)

func calculateAckerman():
	ackerman = ackermanRatio*ackermanSide

func _physics_process(delta):
	if steer:
		$wheelSteerPivot.rotation.y = vehicle.normalizedSteering*maxSteerAngleActual
	

func updateCasts(state, delta, oneByDelta, contribution):
	contactTransform = null
	$RayCast3D.force_raycast_update()
	$ShapeCast3D.force_shapecast_update()
	var collisionNormal: Vector3
	var globalCollisionPoint
	
	if !useShapecastForPhysics:
		globalCollisionPoint = $RayCast3D.get_collision_point()
		collisionNormal = $RayCast3D.get_collision_normal()
	if collisionNormal.dot(global_transform.basis.y) < normalDirectionLimit:
		collisionNormal = collisionNormal.slerp(global_transform.basis.y, 0.9)
	grounded = $RayCast3D.is_colliding()
	$Particles.global_position = globalCollisionPoint
	var globalVelocity = oneByDelta*(global_position-previousGlobalPosition)
	if grounded:
		
		contactTransform = Transform3D()
		contactTransform.origin = globalCollisionPoint
		contactTransform.basis.y = collisionNormal
		#var basisZ = collisionNormal.cross($wheelSteerPivot.global_transform.basis.x).normalized()
		var basisZ = $wheelSteerPivot.global_transform.basis.x.cross(collisionNormal).normalized()
		var basisX = collisionNormal.cross(basisZ)
		contactTransform.basis.z = basisZ
		contactTransform.basis.x = basisX
		
		localVelocity = contactTransform.basis.inverse() * globalVelocity
		
		$contactTransform.clear()
		$contactTransform.addVector(contactTransform.origin, contactTransform.basis.y, Color.GREEN_YELLOW)
		$contactTransform.addVector(contactTransform.origin, contactTransform.basis.x, Color.INDIAN_RED)
		$contactTransform.addVector(contactTransform.origin, contactTransform.basis.z, Color.SKY_BLUE)
	else:
		feedback = 0.0
	
	previousGlobalPosition = global_position
	

func applyFrictionForces(state, delta, oneByDelta, contribution):
	if !grounded: return
	
	var necessaryXFriction = localVelocity.x*oneByDelta*massPerWheel*0.9
	relativeZSpeed = (radsPerSec*radius)-(localVelocity.z)
	var necessaryZFriction = relativeZSpeed*oneByDelta*massPerWheel*0.9
	
	var tireResponse: TireResponse = tireResponseDictionary['tarmac'] 
	var coeficients = tireResponse.getCoeficients(localVelocity, radsPerSec, radius)
	var stream = tireResponse.slippingStream
	
	feedback = coeficients.y
	
	var xFriction = min(abs(necessaryXFriction), coeficients.x*suspensionForceMagnitude)
	var zFriction = min(abs(necessaryZFriction), coeficients.z*suspensionForceMagnitude)
	zFriction *= sign(necessaryZFriction)
	xFriction *= sign(necessaryXFriction)
	var frictionColor = Color.RED
	#debugString = str( snapped(coeficients.x, 0.1) )
	if coeficients.x < tireResponse.gripMultiplier:
		frictionColor = Color.ORANGE
	vehicle.applyGlobalForceState(xFriction*-contactTransform.basis.x, contactTransform.origin, state, frictionColor)
	vehicle.applyGlobalForceState(zFriction*contactTransform.basis.z, contactTransform.origin, state, Color.BLUE_VIOLET)
	#applyTorqueFromFriction(zFriction, delta, relativeZSpeed)
	
	appliedZFriction = zFriction
	
	
	tireResponse.handleAudio(delta, $RollingAudioStreamPlayer3D, $SlippingAudioStreamPlayer3D, localVelocity, radsPerSec, radius)
	tireResponse.handleParticles(delta, localVelocity, radsPerSec, radius)

func animate(delta):
	$wheelSteerPivot/wheelRollPivot.rotation.x += radsPerSec*delta
	applyTorqueFromFriction(delta)

func applyTorqueFromFriction(delta):
	if !grounded: return
	var targetRPS = localVelocity.z/radius
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
		#if !powered:
		radsPerSec = targetRPS
	var signBefore = sign(radsPerSec)
	applyTorque(abs(breakTorque)*-sign(radsPerSec), delta)
	var signAfter = sign(radsPerSec)
	if (signBefore != signAfter):
		radsPerSec = 0.0
	#FIXME break torque must be applied even if there is no contact
	breakTorque = 0.0
	#radsPerSec = sign(radsPerSec) * min( abs(radsPerSec)/TAU*60, 6000*0.1 )/60*TAU
	#debugString = str(snapped(radsPerSec, 1))+'/'+str(snapped(targetRPS, 1))

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
	var normalizedCompression = 1.0-abs(wheelPivotPositionY)/maxExtension
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
	suspensionForceMagnitude = max(0.0, suspensionForceMagnitude)
	
	var suspensionForce = suspensionForceMagnitude*contactTransform.basis.y
	
	vehicle.applyGlobalForceState(suspensionForce, contactTransform.origin, state, Color.GREEN)
	
	$wheelSteerPivot.position.y = wheelPivotPositionY
	
	previousCompression = compression
