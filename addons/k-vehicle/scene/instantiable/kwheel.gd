@icon("res://addons/k-vehicle/car-wheel.svg")


extends Node3D
## implements a vehicle wheel and its suspension.
## 
## must be a direct child of a [KVVehicle]. variables get updated in the [KVVehicle]'s _integrate_forces() method
class_name KVWheel

#@export_category('Wheel and Tire')
## wheel radius can be calculated automatically from the mesh AABB if [b]getRadiusFromMeshAABB[/b] is enabled
@export var radius = 0.27
## wheel width, can be calculated automatically from the mesh AABB if [b]getRadiusFromMeshAABB[/b] is enabled
@export var width = 0.17

## momentOfInertia is how diffcult an object is to rotate.
## [br]the angular acceleration of the wheel is appliedTorque/momentOfInerta
## [br]approximation for a solid cilinder: 0.5*wheelMass*radius^2
## [br]because the tire forces are a feeback system, the moment of inertia influences the accuracy of the simulation,
## increasing it can massively reduce engine and wheel oscilation
## [br]for drifting cars it's good to stick to realistic values, otherwise
## 1% of the vehicle mass seems to work well
@export var momentOfInertia = 1.0

## overwrites [b]radius[/b] and [b]width[/b] from the computed mesh bounding box
@export var getDimensionsFromMeshAABB = false

## [TireResponse] resources for surfaces, see [TireResponse] 
@export var tireResponses: Array[TireResponse]

## dictionary built from the [TireResponse]s array. idexed by their material
var tireResponseDictionary: Dictionary

#@export_category('Steering')

## enables steering for this wheel. can be toggled at runtime
@export var steer = false

#@export var inverseSteering = false

## maximum steering angle, use negative value if you need to reverse steering, like for off-road vehicles that steer the rear wheels
## [br] see [KVA
@export var maxSteerAngle = PI/3.0

#@export var useAckermanSteering = true

## [url=https://en.wikipedia.org/wiki/Ackermann_steering_geometry]ackerman steering[/url] ratio, see [KVAckerman] to calculate automatically.
@export var ackermanRatio = 1.0

#@export_category('Suspension')

## suspension stiffness: maximum force applied as a coeficient of vehicle mass*gravity/wheelCount
@export var stiffness = 4.0

## damp when the suspension is compressing
@export_range(0.0,1.0) var compressionDamp = 0.1

## damp when the suspension is relaxing
@export_range(0.0,1.0) var relaxationDamp = 0.9


#@export_category('Physics Tweaking')

## reduces wheel fidgeting/oscilating
@export var fidgetFix = true
## threshold for the fidget fix in radinas/second
@export var rpsDeltaThreshold = 1.0

## additional fricion/grip coeficient multiplier to be used on the tires.
## can be used to modify a tire response under arbitrary circumstances without
## the need to create additional [TireResponse]. Y component is not used.
## [br] x: sideways
## [br] z: longitudinal
@export var gripMultiplier = Vector3.ONE

## if true, use shapecast collision data for physics. raycasting is used otherwise.[br]
## [b]shapcasting is currently unstable in godot[/b]: shapecasting will sometimes not report collisions or penetrate other objects. it also suffers extremely from lack of precision when far from the world origin. this can be mitigated by keeping the vehicle close to the origin while shifting the world.
@export var useShapecastForPhysics = false

## usefull for smoothing abrubt changes in normal collision, for example, going up a sidewalk.
## [br]
## 0.0: no bias [br]
## 1.0: collision normal always points to suspension local UP
@export_range(0.0, 1.0) var normalDirectionBias = 0.0

## When false, the suspension can apply a force 'downwards'.
## This is unrealistic and can cause the vehicle to 'stick' more to the terrain
## instead of jumping naturally
@export var clampSuspensionForce = true

var debugString: String

var vehicle: KVVehicle

var ackermanSide = 1.0
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

## update every frame
var suspensionForceMagnitude = 0.0
## ratio of 1.0/totalWheels
var wheelContribution = 0.25

## vehicle mass/totalWheels
var massPerWheel = 0.0

## tire force feedback on the steering wheel
var feedback = 0.0

var globalGravity = ProjectSettings.get_setting("physics/3d/default_gravity")

## transform representing the tire contact patch position and orientation in global space
var contactTransform

## linearVelocity in local space
var localVelocity = Vector3.ZERO

## wheel angular velocity in radians per second
var radsPerSec = 0.0

var relativeZSpeed = 0.0

## total break torque for a physics tick, gets applied after other torques and set to 0
var breakTorque = 0.0

## the wheel is powered by a drivetrain
var powered = false


var frictionTorque = 0.0
var prevFrictionTorque = 0.0
var appliedZFriction = 0.0

## the name of the contact surface, taken by doing a get_meta('material') on the collider
var surfaceMaterial: StringName = 'tarmac'

var normalizedCompression = 0.0

## force applied by the suspension, updated every tick
var suspensionForce = Vector3.ZERO

## relative velocity of the contact patch to the ground in the contact patch local space(contactTransform)
var contactRelativeVelocity = Vector3.ZERO

## current [TireResponse]
var tireResponse: TireResponse

## the angularVelocity(radians/second) this wheel should have if were rolling without longitudinal slip
var targetRPS = 0.0


var traveled = 0.0
var maxTraveled = 8.0

var xFrictionAccumulated = 0.0
var zFrictionAccumulated = 0.0
var frictionColor = Color.RED
var substepZFriction = 0.0

var wheelVisualPositionYOffset = 0.0


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
	
	if getDimensionsFromMeshAABB:
		var aabb = $wheelSteerPivot/wheelRollPivot/wheelMesh.mesh.get_aabb()
		radius = aabb.size.y*0.5
		width = aabb.size.x
	
	createShapecastShape()

func createShapecastShape():
	var shape = CylinderShape3D.new()
	shape.radius = radius
	shape.height = width
	$shapecastPivot/ShapeCast3D.shape = shape

func updateAckerman(newRatio):
	ackermanRatio = newRatio
	updateMaxSteering()

func validateSubTree():
	if !OS.has_feature("editor"): return
	assert($wheelSteerPivot/wheelRollPivot.rotation.is_equal_approx(Vector3.ZERO),\
	"wheelRollPivot rotation must be 0. change wheelSteerPivot.rotation.z to adjust camber" )
	assert(is_zero_approx($wheelSteerPivot.rotation.y) and is_zero_approx($wheelSteerPivot.rotation.x), "wheelSteerPivot rotation x and y must be 0. only change rotation.z to adjust camber")
	assert($wheelSteerPivot/wheelRollPivot.position.is_equal_approx(Vector3.ZERO), "wheelRollPivot position must be 0")
	if !is_zero_approx($wheelSteerPivot.position.x) or !is_zero_approx($wheelSteerPivot.position.z):
		push_error('wheelSteerPivot.position will be ignored')
		$wheelSteerPivot.position.x = 0.0
		$wheelSteerPivot.position.y = 0.0
	if !$RayCast3D.position.is_zero_approx():
		print_rich('[color=orange] Raycast3D.position is not meant to be changed and will be ignored [/color]')
		$RayCast3D.position = Vector3.ZERO
	if !$shapecastPivot.position.is_zero_approx():
		print_rich('[color=orange] shapecastPivot.position is not meant to be changed and will be  will be ignored  [/color]')
		$shapecastPivot.position = Vector3.ZERO
	if !$shapecastPivot/ShapeCast3D.position.is_zero_approx():
		print_rich('[color=orange] ShapeCast3D.position is not meant to be changed and will be  will be ignored  [/color]')
		$shapecastPivot/ShapeCast3D.position = Vector3.ZERO
	if !$wheelSteerPivot/wheelRollPivot/wheelMesh.position.is_zero_approx():
		print_rich('[color=orange] wheelMesh.position is not meant to be changed and will be  will be ignored  [/color]')
		$wheelSteerPivot/wheelRollPivot/wheelMesh.position = Vector3.ZERO

func _ready():
	validateSubTree()
	updateMaxSteering()
	
	$shapecastPivot/ShapeCast3D.enabled = useShapecastForPhysics
	
	previousGlobalPosition = global_position
	restExtension = abs($wheelSteerPivot.restExtension)#+.2
	maxExtension = abs($wheelSteerPivot.maxExtension)#+.2
	restRatio = restExtension/maxExtension
	wheelContribution = 1.0/vehicle.wheels.size()
	massPerWheel = wheelContribution*vehicle.mass
	normalForceAtRest = vehicle.mass*vehicle.gravity_scale*globalGravity*wheelContribution
	$RayCast3D.target_position.y = -maxExtension-radius
	#$shapecastPivot/ShapeCast3D.target_position.z = -maxExtension
	$shapecastPivot/ShapeCast3D.add_exception(get_parent())

func updateMaxSteering():
	ackermanSide = sign(position.x)
	ackerman = ackermanRatio*ackermanSide
	maxSteerAngleActual = -ackerman*maxSteerAngle

func _physics_process(delta):
	if steer:
		var steerAngleActual = maxSteerAngle
		#var ackermanActual = lerp(1.0, ackermanRatio,\
		#sin( abs(vehicle.normalizedSteering)*PI*0.5 ) )
		var ackermanActual = lerp(1.0, ackermanRatio,abs(vehicle.normalizedSteering) )
		if is_equal_approx( sign(vehicle.normalizedSteering), ackermanSide):
			steerAngleActual = ackermanActual*maxSteerAngle
		$wheelSteerPivot.rotation.y = -vehicle.normalizedSteering*steerAngleActual
	$shapecastPivot/ShapeCast3D.target_position = (Vector3.DOWN*abs(maxExtension))*$shapecastPivot/ShapeCast3D.global_transform.basis

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
		#$shapecastPivot/ShapeCast3D.force_shapecast_update()
		grounded = $shapecastPivot/ShapeCast3D.is_colliding()
		if grounded:
			collider = $shapecastPivot/ShapeCast3D.get_collider(0)
			collisionNormal = $shapecastPivot/ShapeCast3D.get_collision_normal(0)
			globalCollisionPoint = $shapecastPivot/ShapeCast3D.get_collision_point(0)
	
	
	"""
	if collisionNormal.dot(global_transform.basis.y) < normalDirectionLimit:
		collisionNormal = collisionNormal.slerp(global_transform.basis.y, 0.9)
	"""
	collisionNormal = collisionNormal.slerp(global_transform.basis.y, normalDirectionBias)
	#var collider = $RayCast3D.get_collider()
	
	
	var globalVelocity = oneByDelta*(global_position-previousGlobalPosition+vehicle.teleportDelta)
	traveled+=globalVelocity.length()*delta
	traveled = fmod(traveled , maxTraveled)
	if grounded:
		var preContactTransform = Transform3D()
		preContactTransform.basis.y = collisionNormal
		#var basisZ = collisionNormal.cross($wheelSteerPivot.global_transform.basis.x).normalized()
		var preContactTransformBasisZ = $wheelSteerPivot.global_transform.basis.x.cross(collisionNormal).normalized()
		var preContactTransformBasisX = collisionNormal.cross(preContactTransformBasisZ)
		preContactTransform.basis.z = preContactTransformBasisZ
		preContactTransform.basis.x = preContactTransformBasisX
		preContactTransform.origin = globalCollisionPoint
		
		surfaceMaterial = StringName('tarmac')
		if collider.has_meta('material'):
			var surfaceMaterialString = collider.get_meta('material')
			surfaceMaterial = surfaceMaterialString
		tireResponse = tireResponseDictionary[surfaceMaterial] 
		var bumpHeight = tireResponse.sampleBumpHeight(traveled/maxTraveled)
		var bumpNormal = tireResponse.sampleBumpNormal(traveled/maxTraveled)
		var newNormal = bumpNormal*preContactTransform.basis.inverse()
		bumpHeight = 0.0
		globalCollisionPoint += lerp( bumpHeight, 0.0, tireResponse.bumpVisualBias )*collisionNormal
		collisionNormal = collisionNormal.slerp(newNormal, 1.0-tireResponse.bumpVisualBias)
		#wheelVisualPositionYOffset = bumpStrength*tireResponse.bumpVisualBias
		wheelVisualPositionYOffset = bumpHeight
		#debugString = str( snapped( bumpStrength, 0.01) )
		contactTransform = Transform3D()
		
		contactTransform.basis.y = collisionNormal
		#var basisZ = collisionNormal.cross($wheelSteerPivot.global_transform.basis.x).normalized()
		var basisZ = $wheelSteerPivot.global_transform.basis.x.cross(collisionNormal).normalized()
		var basisX = collisionNormal.cross(basisZ)
		contactTransform.basis.z = basisZ
		contactTransform.basis.x = basisX
		contactTransform.origin = globalCollisionPoint
		
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
	
	var xFriction = min(abs(necessaryXFriction), coeficients.x*gripMultiplier.x*suspensionForceMagnitude)
	var zFriction = min(abs(necessaryZFriction), coeficients.z*gripMultiplier.z*suspensionForceMagnitude)
	#zFriction = coeficients.z*gripMultiplier.x*suspensionForceMagnitude
	#xFriction = coeficients.x*suspensionForceMagnitude
	zFriction *= sign(necessaryZFriction)
	xFriction *= sign(necessaryXFriction)
	frictionColor = Color.RED
	#debugString = str( snapped(coeficients.x, 0.1)
	var frictionFraction = coeficients.x/tireResponse.coeficientOfFriction
	#debugString = str( snapped(frictionFraction, 0.1 ) )
	if coeficients.x < tireResponse.coeficientOfFriction:
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
		applyTorque(frictionTorque*1.0, delta) #delta because already using the substep torque
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
	applyTorque(abs(breakTorque)*-sign(radsPerSec), modDelta)
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
	var fsafe = $shapecastPivot/ShapeCast3D.get_closest_collision_safe_fraction()
	var funsafe = $shapecastPivot/ShapeCast3D.get_closest_collision_unsafe_fraction()
	var fraction = (fsafe+funsafe)*0.5
	var wheelPivotPositionY
	if useShapecastForPhysics:
		wheelPivotPositionY = -fraction*maxExtension#-radius
	else:
		wheelPivotPositionY = to_local(contactTransform.origin).y+radius
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
	
	$wheelSteerPivot.position.y = wheelPivotPositionY+wheelVisualPositionYOffset
	previousCompression = compression
