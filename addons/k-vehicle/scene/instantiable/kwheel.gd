extends Node3D

class_name KWheel

@export_category('Wheel and Tire')
@export var radius = 0.2
## overwrites [b]radius[/b] from the computed mesh bounding box
@export var getRadiusFromMeshAABB = false

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

var forceAtRest = 0.0
var suspensionForceMagnitude = 0.0
var wheelContribution = 0.25

var globalGravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var contactTransform

func findVehicle():
	var parent = get_parent()
	while !(parent is KVehicle):
		parent = parent.get_parent()
	vehicle = parent

func _enter_tree():
	findVehicle()
	vehicle.wheels.append(self)
	$RayCast3D.add_exception(vehicle)
	$ShapeCast3D.add_exception(vehicle)
	
	if getRadiusFromMeshAABB:
		radius = $wheelSteerPivot/wheelRollPivot/wheelMesh.mesh.get_aabb().size.y*0.5
		print('radius: ' + str(radius))

func _ready():
	calculateAckerman()
	maxSteerAngleActual = -ackerman*maxSteerAngle
	previousGlobalPosition = global_position
	restExtension = abs($wheelSteerPivot.restExtension)+.2
	maxExtension = abs($wheelSteerPivot.maxExtension)+.2
	restRatio = restExtension/maxExtension
	wheelContribution = 1.0/vehicle.wheels.size()
	forceAtRest = vehicle.mass*vehicle.gravity_scale*globalGravity*wheelContribution
	print(forceAtRest)
	$RayCast3D.target_position.y = -maxExtension-radius
	$ShapeCast3D.target_position.z = -maxExtension

func calculateAckerman():
	ackerman = ackermanRatio*ackermanSide

func _physics_process(delta):
	if steer:
		$wheelSteerPivot.rotation.y = vehicle.normalizedSteering*maxSteerAngleActual

func updateCasts():
	contactTransform = null
	$RayCast3D.force_raycast_update()
	$ShapeCast3D.force_shapecast_update()
	var collisionNormal
	var globalCollisionPoint
	if !useShapecastForPhysics:
		globalCollisionPoint = $RayCast3D.get_collision_point()
		collisionNormal = $RayCast3D.get_collision_normal()
	grounded = $RayCast3D.is_colliding()
	if grounded:
		contactTransform = Transform3D()
		contactTransform.origin = globalCollisionPoint
		contactTransform.basis.y = collisionNormal
		#var basisZ = collisionNormal.cross($wheelSteerPivot.global_transform.basis.x).normalized()
		var basisZ = $wheelSteerPivot.global_transform.basis.x.cross(collisionNormal).normalized()
		var basisX = collisionNormal.cross(basisZ)
		contactTransform.basis.z = basisZ
		contactTransform.basis.x = basisX
		$contactTransform.clear()
		$contactTransform.addVector(contactTransform.origin, contactTransform.basis.y, Color.GREEN_YELLOW)
		$contactTransform.addVector(contactTransform.origin, contactTransform.basis.x, Color.INDIAN_RED)
		$contactTransform.addVector(contactTransform.origin, contactTransform.basis.z, Color.SKY_BLUE)

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
		#print('compression')
	else:
		damp = relaxationDamp
	damp *= compressionDelta*vehicle.mass*wheelContribution
	suspensionForceMagnitude = compression*forceAtRest
	suspensionForceMagnitude += damp
	suspensionForceMagnitude = max(0.0, suspensionForceMagnitude)
	
	var suspensionForce = suspensionForceMagnitude*contactTransform.basis.y
	
	vehicle.applyGlobalForceState(suspensionForce, contactTransform.origin, state, Color.GREEN)
	
	$wheelSteerPivot.position.y = wheelPivotPositionY
	
	previousCompression = compression
