@tool

extends RigidBody3D
## rigid body for ground vehicles.[br] [b]do not add this node directly, add a KVVehicleInstantiator instead[/b]
##
## you can add KVComponent nodes as child of this node to extend its behaviour.
## [br][b]_integrate_forces loop:[/b]
## [codeblock]
## update [KVWheel]s with this tick relevant data like normal load, local velocity, etc
## apply suspension force
## call registered preSubstep functions
## repeat for substeps:
##     call _integrate on [KVComponents] like engine, drivetrain, breaks, etc
##     accumulate friction and reaction torques to [KVWheel]s
## apply accumulated fricion and torques to wheels
## call registered postSubstep functions
## [/codeblock]
## [br]see [KVComponent] for writing custom components that receive the _integrate callback
class_name KVVehicle

## [b]experimental[/b]
##[br]creates a cilinder collider for each wheel at
## their position (where the suspension is under maximum compression)
##[br]prevents the wheel from going inside the ground under extreme load,
## but can cause odd collisions agains the ground under certain circumstances
@export var createWheelMinimumColliders = false
## substeps for the friction torque feedback calculations.
## [br][br]
## it improves engine and wheel fidgeting/oscilations without needing to increase the engine physics ticks/second
@export var substeps = 1

## read by wheels that steer.
## [br]
## steering assisters or custom input methods should set this variable
var normalizedSteering = 0.0
var break2Input = 0.0
var accelerationInput = 0.0
## true when any break input is > 0.0
## [br]
## used for anti-slide system on slopes
var breaking = false
## input is read by child nodes.
## [br]
## custom input methods should set this variable
var clutchInput = 0.0

## array containing the wheels. it gets populated by children wheels when they _enter_tree
var wheels = []

## if the vehicle gets teleported manually, this delta must be set
## [br]
## wheels will read this when they _integrate
## gets reset to Vector3.ZERO at the end of _integrate_forces
var teleportDelta = Vector3.ZERO

## speed in meters/second
var speedMS = 0.0

## read at initialization from project settings 'physics/3d/default_gravity'
var globalGravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
# Called when the node enters the scene tree for the first time.

## linear velocity in meter/second in local space
var localLinearVelocity = Vector3.ZERO

var localAngularVelocity = Vector3.ZERO

## will be read by a 3DLabel every frame. can be set to anything to help with debugging
var debugString: String

var componentIntegrateFunctions = []
var componentPreSubstepIntegrateFunctions = []
var componentPostSubstepIntegrateFunctions = []

## [PhysicsDirectBodyState3D] of the vehicle
var directState: PhysicsDirectBodyState3D

func _get_configuration_warnings():
	if scene_file_path == '':
		return['KVVehicle is meant to be instantiated as a child(Ctrl+Shift+A) or inherited(Ctrl+Shift+N) scene.']

func _enter_tree():
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
	if scene_file_path == '':
		printerr('KVVehicle is meant to be instantiated as a child or inherited scene.')
	update_configuration_warnings()
	if Engine.is_editor_hint(): return

func _ready():
	
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		get_parent().set_editable_instance(self, true)
		return
	#TODO maybe use same shape resource as shapecaster
	if createWheelMinimumColliders:
		for wheel in wheels:
			var collisionShape = CollisionShape3D.new()
			var shape = CylinderShape3D.new()
			shape.radius = wheel.radius+wheel.radius*0.05#.get_node('wheelSteerPivot/wheelRollPivot/wheelMesh').mesh.get_aabb().size.y*0.5+0.05
			shape.height = wheel.width#get_node('wheelSteerPivot/wheelRollPivot/wheelMesh').mesh.get_aabb().size.x
			collisionShape.shape = shape
			
			#FIXME wheel.position assumes wheel is a direct child
			collisionShape.position = wheel.position
			collisionShape.rotation.z = PI*0.5 + wheel.get_node('wheelSteerPivot').rotation.z
			call_deferred("add_child", collisionShape)

func _process(delta):
	pass

func _physics_process(delta):
	speedMS = linear_velocity.length()
	if Input.is_action_pressed('slowmo'):
		Engine.time_scale = 0.125
	else:
		Engine.time_scale = 1.0


## register a function to be run before the substeps.
##[br] see [KVVehicle] _integrate_forces loop
func register(funcRef):
	componentIntegrateFunctions.append(funcRef)

## register a function to be run on each substep
## [br] [KVComponent]s automatically register their _integrate functions here
##[br] see [KVVehicle] _integrate_forces loop
func registerPreSubstep(funcRef):
	componentPreSubstepIntegrateFunctions.addpend(funcRef)

## register a function to be run after the substeps 
##[br] see [KVVehicle] _integrate_forces loop
func registerPostSubstep(funcRef):
	componentPostSubstepIntegrateFunctions.addpend(funcRef)

func _integrate_forces(state):
	# state.transform.origin == global_position
	# state.center_of_mass == center_of_mass
	localLinearVelocity = state.linear_velocity*global_transform.basis
	localAngularVelocity = state.angular_velocity*global_transform.basis
	#debugString = str( localLinearVelocity.snapped(Vector3.ONE*0.1) )
	if inertia.is_equal_approx(Vector3.ZERO):
		inertia = state.inverse_inertia.inverse()
	if !directState:
		directState = state
	var contribution = 1.0/wheels.size()
	var delta = state.step
	var oneByDelta = 1.0/delta
	var oneBySubstep = 1.0/substeps
	var modDelta = delta
	if substeps > 1:
		modDelta /= substeps
	
	$debugVectors.clear()
	
	for wheel in wheels:
		wheel.updateCasts(state, delta, oneByDelta, contribution)
	var totalSuspensionForce = Vector3.ZERO
	for wheel in wheels:
		wheel.applySuspensionForce(state, delta, oneByDelta, contribution)
		if wheel.grounded:
			totalSuspensionForce += wheel.suspensionForceApplied
	for f in componentPreSubstepIntegrateFunctions:
		f.call(delta, oneByDelta, modDelta, oneBySubstep)
	for i in range(substeps):
		#$engine._integrate(delta, oneByDelta, modDelta, oneBySubstep)
		#$handbreak._integrate(delta, oneByDelta, modDelta, oneBySubstep)
		for f in componentIntegrateFunctions:
			f.call(delta, oneByDelta, modDelta, oneBySubstep)
		#$breakFront._integrate(delta, oneByDelta, modDelta, oneBySubstep)
		#$breakRear._integrate(delta, oneByDelta, modDelta, oneBySubstep)
		#$lsd._integrate(delta, oneByDelta, modDelta, oneBySubstep)
		#$drivetrain._integrate(delta, oneByDelta, modDelta, oneBySubstep)
		#$"k-swayBarFront"._integrate(delta, oneByDelta, modDelta, oneBySubstep)
		#$"k-swayBarRear"._integrate(delta, onebByDelta, modDelta, oneBySubstep)
		
		for wheel in wheels:
			wheel.applyFrictionForces(state, delta, oneByDelta, modDelta, oneBySubstep, contribution)
			wheel.applyTorqueFromFriction(delta, oneByDelta, modDelta, oneBySubstep)
	
	for wheel in wheels:
		wheel.applyAccumulatedFrictionForces(state)
	#$drivetrain.clutch(delta, oneByDelta)
	
	for f in componentPostSubstepIntegrateFunctions:
		f.call(delta, oneByDelta, modDelta, oneBySubstep)
	
	# there is room for improvement here
	# perhaps feeding slopeResultingForce vector into each wheel as vehicle motion 
	var gravityForce = Vector3.DOWN*globalGravity*gravity_scale*mass
	var slopeResultingForce = gravityForce + totalSuspensionForce
	$debugVectors.addVector(global_position, slopeResultingForce/mass, Color.BLACK)
	var requiredXFriction = -(slopeResultingForce.project(global_transform.basis.x))
	var requiredZFriction = -(slopeResultingForce.project(global_transform.basis.z))
	#if abs(localLinearVelocity.z) < 0.125 and breaking:
	var groundedWheels = 0
	for wheel in wheels:
		if wheel.grounded:
			groundedWheels += 1
	if groundedWheels >= 2:
		if breaking and ((requiredZFriction.normalized().dot(linear_velocity.normalized())<0.0)\
		or abs(localLinearVelocity.z) < 0.0625):
			applyCentralGlobalForceState(requiredZFriction,  state, Color.LIGHT_SKY_BLUE)
		if abs(localLinearVelocity.x) < 0.125:
			applyCentralGlobalForceState(requiredXFriction,  state, Color.LIGHT_PINK)
	
	for wheel in wheels:
		wheel.animate(delta, oneByDelta)
	#$drivetrain.clutch(delta, oneByDelta)
	teleportDelta = Vector3.ZERO

func accelerateYaw(delta, oneByDelta, acceleration):
	applyYawTorque(acceleration*inertia.y)

func applyYawTorque(torqueMagnitude):
	apply_torque(global_transform.basis.x*torqueMagnitude)

func acceleratePitch(delta, oneByDelta, acceleration):
	applyPitchTorque(acceleration*inertia.x)

func applyPitchTorque(torqueMagnitude):
	apply_torque(global_transform.basis.x*torqueMagnitude)

func accelerateRoll(acceleration):
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
