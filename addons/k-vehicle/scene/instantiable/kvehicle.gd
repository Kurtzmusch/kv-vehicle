extends RigidBody3D

class_name KVVehicle

## if true, creates a cilinder collider for each wheel
@export var createWheelMinimumColliders = true

var normalizedSteering = 0.0
var break2Input = 0.0
var accelerationInput = 0.0
var breaking = false
var clutchInput = 0.0

var wheels = []

var speedMS = 0.0
var globalGravity = ProjectSettings.get_setting("physics/3d/default_gravity")
# Called when the node enters the scene tree for the first time.
var localLinearVelocity = Vector3.ZERO

var debugString: String

func _ready():
	
	if createWheelMinimumColliders:
		for wheel in wheels:
			var collisionShape = CollisionShape3D.new()
			var shape = CylinderShape3D.new()
			shape.radius = wheel.get_node('wheelSteerPivot/wheelRollPivot/wheelMesh').mesh.get_aabb().size.y*0.5-0.001
			shape.height = wheel.get_node('wheelSteerPivot/wheelRollPivot/wheelMesh').mesh.get_aabb().size.x
			collisionShape.shape = shape
			#FIXME wheel.position assumes wheel is a direct child
			collisionShape.position = wheel.position
			collisionShape.rotation.z = PI*0.5
			call_deferred("add_child", collisionShape)

func _process(delta):
	pass

func _physics_process(delta):
	speedMS = linear_velocity.length()
	if Input.is_action_pressed('slowmo'):
		Engine.time_scale = 0.125
	else:
		Engine.time_scale = 1.0

func _integrate_forces(state):
	# state.transform.origin == global_position
	# state.center_of_mass == center_of_mass
	var localLinearVelocity = state.linear_velocity*global_transform.basis
	debugString = str( localLinearVelocity.snapped(Vector3.ONE*0.1) )
	inertia = state.inverse_inertia.inverse()
	var contribution = 1.0/wheels.size()
	var delta = state.step
	var oneByDelta = 1.0/delta
	$debugVectors.clear()
	#apply_central_force(Input.get_axis("acceleration+", "acceleration-")*mass*global_transform.basis.z*4.0)
	#applyGlobalForceState(Input.get_axis("acceleration+", "acceleration-")*mass*global_transform.basis.z*4.0, to_global(Vector3.DOWN*0.5), state, Color.AQUA)
	$engine._integrate(delta, oneByDelta)
	$handbreak._integrate(delta, oneByDelta)
	$breakFront._integrate(delta, oneByDelta)
	$breakRear._integrate(delta, oneByDelta)
	$lsd._integrate(delta, oneByDelta)
	$drivetrain._integrate(delta, oneByDelta)
	$"k-swayBarFront"._integrate(delta, oneByDelta)
	$"k-swayBarRear"._integrate(delta, oneByDelta)
	for wheel in wheels:
		#wheel.force_update_transform()
		wheel.updateCasts(state, delta, oneByDelta, contribution)
	var totalSuspensionForce = Vector3.ZERO
	for wheel in wheels:
		wheel.applySuspensionForce(state, delta, oneByDelta, contribution)
		if wheel.grounded:
			totalSuspensionForce += wheel.suspensionForce
		if !wheel.steer:
			pass
			#wheel.applyTorque(Input.get_axis("acceleration+", "acceleration-")*1200.0,delta)
		wheel.applyFrictionForces(state, delta, oneByDelta, contribution)
		wheel.applyTorqueFromFriction(delta, oneByDelta)
	#$drivetrain.clutch(delta, oneByDelta)
	# there is room for improvement here
	# perhaps feeding slopeResultingForce vector into each wheel as vehicle motion 
	var gravityForce = Vector3.DOWN*globalGravity*gravity_scale*mass
	var slopeResultingForce = gravityForce + totalSuspensionForce
	$debugVectors.addVector(global_position, slopeResultingForce/mass, Color.BLACK)
	var requiredXFriction = -(slopeResultingForce.project(global_transform.basis.x))
	var requiredZFriction = -(slopeResultingForce.project(global_transform.basis.z))
	#if abs(localLinearVelocity.z) < 0.125 and breaking:
	if breaking and ((requiredZFriction.normalized().dot(linear_velocity.normalized())<0.0)\
	or abs(localLinearVelocity.z) < 0.0625):
		applyCentralGlobalForceState(requiredZFriction,  state, Color.LIGHT_SKY_BLUE)
	if abs(localLinearVelocity.x) < 0.125:
		applyCentralGlobalForceState(requiredXFriction,  state, Color.LIGHT_PINK)
	
	for wheel in wheels:
		wheel.animate(delta, oneByDelta)
	#$drivetrain.clutch(delta, oneByDelta)

func accelerateYaw(delta, oneByDelta, acceleration):
	applyYawTorque(acceleration*inertia.y)

func applyYawTorque(torqueMagnitude):
	apply_torque(global_transform.basis.x*torqueMagnitude)

func acceleratePitch(delta, oneByDelta, acceleration):
	applyPitchTorque(acceleration*inertia.x)

func applyPitchTorque(torqueMagnitude):
	apply_torque(global_transform.basis.x*torqueMagnitude)

func accelerateRoll(delta, oneByDelta, acceleration):
	applyRollTorque(acceleration*inertia.z)

func applyRollTorque(torqueMagnitude):
	apply_torque(global_transform.basis.z*torqueMagnitude)

func applyCentralGlobalForceState(globalForce, state:PhysicsDirectBodyState3D, color=Color.MAGENTA):
	#var forcePosition = globalPosition-state.transform.origin
	state.apply_central_force(globalForce)
	$debugVectors.addVector(state.transform.origin+(state.center_of_mass*state.transform.basis), globalForce*state.inverse_mass, color)

func applyGlobalForceState(globalForce, globalPosition, state:PhysicsDirectBodyState3D, color=Color.MAGENTA):
	var forcePosition = globalPosition-state.transform.origin
	state.apply_force(globalForce, forcePosition)
	$debugVectors.addVector(globalPosition, globalForce*state.inverse_mass, color)
