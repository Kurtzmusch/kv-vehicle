@tool
@icon("res://addons/k-vehicle/car-wheel.svg")


extends Node3D
## implements a vehicle wheel and its suspension.[br] [b]do not add this node directly, add a KVWheelInstantiator instead[/b]
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

## tire response to be used if the collider has no 'material' meta set
@export var defaultTireResponse: TireResponse

## dictionary built from the [TireResponse]s array. idexed by their material
var tireResponseDictionary: Dictionary

#@export_category('Steering')

## enables steering for this wheel. can be toggled at runtime
@export var steer = false

#@export var inverseSteering = false

## maximum steering angle(radians), use negative value if you need to reverse steering, like for off-road vehicles that steer the rear wheels
## [br] see [KVAckerman]
@export var maxSteerAngle = PI/3.0

#@export var useAckermanSteering = true

## [url=https://en.wikipedia.org/wiki/Ackermann_steering_geometry]ackerman steering[/url] ratio, see [KVAckerman] to calculate automatically.
@export var ackermanRatio = 1.0

#@export_category('Suspension')

## suspension stiffness: maximum force applied as a coeficient of vehicle mass*gravity/wheelCount
@export var stiffness = 4.0

## suspension preload: minimum force(when its at maximum extension) applied as a coeficient of vehicle mass*gravity/wheelCount
@export_range(0.0, 0.95) var preloadCoeficient = 0.0

## damp when the suspension is compressing
@export_range(0.0,1.0) var compressionDamp = 0.1

## damp when the suspension is relaxing
@export_range(0.0,1.0) var relaxationDamp = 0.9

#@export_category('Physics Tweaking')

## for the purposes of calculating friction, bias the normal load towards the load at rest.
## [br] 0.0: no biasing, behaves physically
## [br] 1.0: full biasing, fricting will be the same no matter how much compressed the suspension is
## overall, makes the grip response to be more similar to a stiffer suspension/ strong sway bars
@export_range(0.0, 1.0) var normalLoadRestBias = 0.0

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

## multiplies with the [member TireResponse.maxNormalLoadCoeficient]
@export_range(1.0, 10.0, 0.001, 'or_greater') var maxNormalLoadCoeficientMultiplier = 1.0

## if true, use shapecast collision data for physics. raycasting is used otherwise.[br]
## [b]shapcasting is currently unstable in godot[/b]:
## shapecasting will sometimes not report collisions or penetrate other objects. it also suffers extremely from lack of precision when far from the world origin. this can be mitigated by keeping the vehicle close to the origin while shifting the world.
## see [member KVVehicle.teleportDelta]
@export var useShapecastForPhysics = false

## threshold angle(radians) for considering the shapecast collision to be in the center of the shape
##[br] this is necessary because when near perpendicular to surfaces, shapecasts won't be able to accurately tell the collision point
var shapeCastAngleThreshold = deg_to_rad(5.0)

## usefull for smoothing abrubt changes in normal collision, for example, going up a sidewalk.
## [br]
## 0.0: no bias [br]
## 1.0: collision normal always points to suspension local UP
@export_range(0.0, 1.0) var normalDirectionBias = 0.0

## When false, the suspension can apply a force 'downwards'.
## This is unrealistic and can cause the vehicle to 'stick' more to the terrain
## instead of jumping naturally
@export var clampSuspensionForce = true

## multiplier for the suspension force, in vehicles local space.
## can be used to disable or reduce some force component of the suspension force
## [br]example: to disable the lateral force set to Vector3(0.0,1.0,1.0)
@export var suspensionForceMult = Vector3.ONE

## clamps the net friction instead of it's individual components
##[br] more realistic, prevents breaking steering the vehicle in the opposite direction when using a lot of maxSteerAngle
##[br] makes drifting easier
@export var clampFricionAfterCombining = true
## angle (radians) between the direction the wheel is pointg and the direction it is moving 
var slipAngle = 0.0

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

## additional force exerted by the suspension on this frame. (N)
## [br] usefull for adding forces that would stiffen/soften the suspension, like sway bars.
## [br] can be negative.
## [br] does not get reset to 0.0
var additionalSuspensionForceMagnitude = 0.0 

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

## suspension spring compression in meters
var compressionM = 0.0

## suspension change in compression in meters/second.
## [br] negative values means it is compressing
var compressionDeltaMS = 0.0

var previousCompressionMS = 0.0

## force to be applied by the suspension
var suspensionForce = Vector3.ZERO

## suspensionForce in vehicles local space
var localSuspensionForce = Vector3.ZERO

## force applied by the suspension, after multiplying [member suspensionForceMult]
var suspensionForceApplied = Vector3.ZERO

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

var collider = null


func _get_configuration_warnings():
	if scene_file_path == '':
		return['KVVehicle is meant to be instantiated as a child or inherited scene.']

func findVehicle():
	var parent = get_parent()
	while !(parent is KVVehicle):
		parent = parent.get_parent()
	vehicle = parent

func _enter_tree():
	update_configuration_warnings()
	
	assert(scene_file_path != '',\
	'KVWheel is not meant to be instanced by itself. Use a KVWheelInstancer to create the correct node tree structure for the wheel.')
	if Engine.is_editor_hint(): return
	
	
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
		if $wheelSteerPivot/wheelRollPivot/wheelMesh.mesh:
			var aabb = $wheelSteerPivot/wheelRollPivot/wheelMesh.mesh.get_aabb()
			aabb.size *= $wheelSteerPivot/wheelRollPivot/wheelMesh.scale
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
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		get_parent().set_editable_instance(self, true)
		return
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
	#$shapecastPivot/ShapeCast3D.rotation.z *= sign(position.x)

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
	$shapecastPivot/ShapeCast3D.target_position = (-global_transform.basis.y*abs(maxExtension))*$shapecastPivot/ShapeCast3D.global_transform.basis

func biasShapecastCollision(preContactTransform):
	var normal = preContactTransform.basis.y
	var point = preContactTransform.origin
	var shapecastUP = $shapecastPivot/ShapeCast3D.global_transform.basis.x

	var angle = normal.angle_to(shapecastUP)
	
	"""
	var dot = normal.dot(shapecastUP)
	var s = 1/2.0
	#dot = 1.0 - pow(dot*s-1.0*s, 2.0)
	dot = pow(dot, 6.0)
	dot = min(dot, 1.0)
	"""
	if angle < shapeCastAngleThreshold:
		var anglePercent = (shapeCastAngleThreshold-angle)/shapeCastAngleThreshold
		# $wheelSteerPivot will use position from previous frame at this point
		var pointLocal = $wheelSteerPivot.to_local(point)
		pointLocal.x = lerp(pointLocal.x, 0.0, anglePercent)
		#pointLocal.x = 0.0
		point =  $wheelSteerPivot.to_global(pointLocal)
	return point

func updateCasts(state, delta, oneByDelta, contribution):
	contactTransform = null
	
	
	var collisionNormal: Vector3
	var globalCollisionPoint: Vector3
	#var rayCollisionPoint = $RayCast3D.get_collision_point()
	#var shapecastCollisionPoint = $shapecastPivot/ShapeCast3D.get_collision_point(0)
	collider = null
	if !useShapecastForPhysics:
		$RayCast3D.force_raycast_update()
		grounded = $RayCast3D.is_colliding()
		if grounded:
			collider = $RayCast3D.get_collider()
			globalCollisionPoint = $RayCast3D.get_collision_point()
			collisionNormal = $RayCast3D.get_collision_normal()
	else:
		var shapecastTargetPosition = $shapecastPivot/ShapeCast3D.target_position
		$shapecastPivot/ShapeCast3D.target_position = Vector3.ZERO
		$shapecastPivot/ShapeCast3D.force_shapecast_update()
		if !$shapecastPivot/ShapeCast3D.is_colliding():
			$shapecastPivot/ShapeCast3D.target_position = shapecastTargetPosition
			$shapecastPivot/ShapeCast3D.force_shapecast_update()
		grounded = $shapecastPivot/ShapeCast3D.is_colliding()
		#debugString = str(grounded)
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
		
		if useShapecastForPhysics:
			globalCollisionPoint = biasShapecastCollision( preContactTransform )
		
		
		surfaceMaterial = StringName('none')
		if collider.has_meta('material'):
			var surfaceMaterialString = collider.get_meta('material')
			surfaceMaterial = surfaceMaterialString
		
		tireResponse = tireResponseDictionary.get(surfaceMaterial, defaultTireResponse)
		wheelVisualPositionYOffset = 0.0
		if tireResponse:
			var bumpHeight = tireResponse.sampleBumpHeight(traveled/maxTraveled)
			var bumpNormal = tireResponse.sampleBumpNormal(traveled/maxTraveled)
			var newNormal = bumpNormal*preContactTransform.basis.inverse()
			#bumpHeight = 0.0
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
		#var slipAngleDeg = rad_to_deg(localVelocity.signed_angle_to(Vector3.FORWARD, Vector3.UP))
		var relativeZSpeed = (radsPerSec*radius)-localVelocity.z
		contactRelativeVelocity = Vector3(localVelocity.x, 0.0, relativeZSpeed)
		
		$Particles.global_transform = contactTransform
		
		$contactTransform.clear()
		$contactTransform.addVector(contactTransform.origin, contactTransform.basis.y, Color.GREEN_YELLOW)
		$contactTransform.addVector(contactTransform.origin, contactTransform.basis.x, Color.INDIAN_RED)
		$contactTransform.addVector(contactTransform.origin, contactTransform.basis.z, Color.SKY_BLUE)
	else:
		tireResponse = null
		feedback = 0.0
		normalizedCompression = 0.0
		compressionM = 0.0
		suspensionForceMagnitude = 0.0
		$wheelSteerPivot.position.y = -maxExtension
		$RollingAudioStreamPlayer3D.volume_db = linear_to_db(0.0)
		$SlippingAudioStreamPlayer3D.volume_db = linear_to_db(0.0)
		# for getting slip angle when jumping
		localVelocity = global_transform.basis.inverse() * globalVelocity
	
	previousGlobalPosition = global_position
	xFrictionAccumulated = 0.0
	zFrictionAccumulated = 0.0
	slipAngle = localVelocity.signed_angle_to(Vector3.FORWARD, Vector3.UP)
	#debugString = str( snapped(slipAngle, 0.1) )
func applyAccumulatedFrictionForces(state):
	if !grounded: return
	var lerpAmount = abs(zFrictionAccumulated)/(tireResponse.coeficientOfFriction*suspensionForceMagnitude)
	var zFrictionColor = Color.BLUE_VIOLET.lerp(Color.AQUA, lerpAmount)
	#debugString = str( snapped(abs(lerpAmount), 0.1 ) )
	vehicle.applyGlobalForceState(xFrictionAccumulated*-contactTransform.basis.x, contactTransform.origin, state, frictionColor)
	vehicle.applyGlobalForceState(zFrictionAccumulated*contactTransform.basis.z, contactTransform.origin, state, zFrictionColor)
	
	debugString = str(int(radsPerSec))

func applyFrictionForces(state, delta, oneByDelta, modDelta, oneBySubstep, contribution):
	if !grounded: return
	if !tireResponse: return
	var oneByModDelta = 1.0/modDelta
	var necessaryXFriction = localVelocity.x*oneByDelta*massPerWheel*0.9
	relativeZSpeed = (radsPerSec*radius)-(localVelocity.z)
	
	var necessaryZFriction = relativeZSpeed*oneByDelta*massPerWheel*0.9
	#var necessaryZFriction = -localVelocity.z*oneByDelta*massPerWheel*0.9
	#debugString = str( snapped( relativeZSpeed, 0.1 ) )
	
	#var coeficients = tireResponse.getCoeficients(localVelocity, radsPerSec, radius)
	
	#var stream = tireResponse.slippingStream
	
	
	var loadFactor = suspensionForceMagnitude/normalForceAtRest
	var maxedMagnitude = tireResponse.maxNormalLoadCoeficient\
		*maxNormalLoadCoeficientMultiplier*(normalForceAtRest)
	var biasedMagnitude = lerp(suspensionForceMagnitude, normalForceAtRest, normalLoadRestBias)
	var maxedSuspensionForce = min(biasedMagnitude, maxedMagnitude)
	
	var desiredFricionVec = Vector3(necessaryXFriction, 0.0, necessaryZFriction)
	var friction = tireResponse.getFrictionForces(localVelocity, radsPerSec, radius, slipAngle, desiredFricionVec, gripMultiplier, maxedSuspensionForce, loadFactor, normalForceAtRest)
	feedback = friction.y
	var zFriction = friction.z
	var xFriction = friction.x
	
	frictionColor = Color.RED
	#debugString = str( snapped(coeficients.x, 0.1)
	if tireResponse.coeficientOfFriction > 0.0:
		var frictionFraction = abs(friction.x)/suspensionForceMagnitude
		#debugString = str( snapped(frictionFraction, 0.1 ) )
		if abs(friction.x) < suspensionForceMagnitude:
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
	if grounded and tireResponse:
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
	#debugString = str( str( snapped(fsafe, 0.1) ) + '/'+str(snapped(funsafe, 0.1) ) )
	var wheelPivotPositionY
	if useShapecastForPhysics:
		wheelPivotPositionY = -fraction*maxExtension#-radius
	else:
		wheelPivotPositionY = to_local(contactTransform.origin).y+radius
	wheelPivotPositionY = min(wheelPivotPositionY, 0.0)
	compressionM = maxExtension-wheelPivotPositionY
	compressionDeltaMS = (compressionM-previousCompressionMS)*oneByDelta
	normalizedCompression = 1.0-abs(wheelPivotPositionY)/maxExtension
	var compression = remap(normalizedCompression,\
	(1.0-restRatio), 1.0,\
	1.0, stiffness)
	compression = clamp(compression, 0.0, stiffness)
	
	if abs(wheelPivotPositionY) > abs(restExtension):
		var d = abs(wheelPivotPositionY)-abs(restExtension)
		var t = abs(maxExtension)-abs(restExtension)
		compression = 1.0-remap(d, 0.0, t, 0.0, 1.0)
		compression = remap(compression, 1.0, 0.0, 1.0, preloadCoeficient)
	var compressionDelta = compression-previousCompression
	compressionDelta*=oneByDelta
	var damp = 0.0
	if compressionDeltaMS > 0.0:
		damp = compressionDamp
	else:
		damp = relaxationDamp
	# *60.0 here instead of oneByTimestep so it is consistent for different timesteps
	damp *= compressionDeltaMS*vehicle.mass*wheelContribution*60.0
	suspensionForceMagnitude = compression*normalForceAtRest
	suspensionForceMagnitude += additionalSuspensionForceMagnitude
	suspensionForceMagnitude -= damp
	if clampSuspensionForce:
		suspensionForceMagnitude = max(0.0, suspensionForceMagnitude)
	
	suspensionForce = suspensionForceMagnitude*contactTransform.basis.y
	suspensionForceApplied = suspensionForce
	
	localSuspensionForce = vehicle.global_transform.basis.inverse()*suspensionForce
	
	if suspensionForceMult != Vector3.ONE:
		localSuspensionForce *= suspensionForceMult
		suspensionForceApplied = vehicle.global_transform.basis*localSuspensionForce
	
	vehicle.applyGlobalForceState(suspensionForceApplied, contactTransform.origin, state, Color.GREEN)
	
	$wheelSteerPivot.position.y = wheelPivotPositionY+wheelVisualPositionYOffset
	previousCompression = compression
	previousCompressionMS = compressionM
