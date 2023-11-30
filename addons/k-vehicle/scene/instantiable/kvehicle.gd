extends RigidBody3D

class_name KVehicle

## if true, creates a cilinder collider for each wheel
@export var createWheelMinimumColliders = true

var normalizedSteering = 0.0
var break2Input = 0.0
var accelerationInput = 0.0
var breaking = false
var clutchInput = 0.0

var wheels = []

var speedMS = 0.0

# Called when the node enters the scene tree for the first time.
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
	for wheel in wheels:
		#wheel.force_update_transform()
		wheel.updateCasts(state, delta, oneByDelta, contribution)
	for wheel in wheels:
		wheel.applySuspensionForce(state, delta, oneByDelta, contribution)
		if !wheel.steer:
			pass
			#wheel.applyTorque(Input.get_axis("acceleration+", "acceleration-")*1200.0,delta)
		wheel.applyFrictionForces(state, delta, oneByDelta, contribution)
		
	
	for wheel in wheels:
		wheel.animate(delta)
	#$drivetrain.clutch(delta, oneByDelta)

func applyGlobalForceState(globalForce, globalPosition, state:PhysicsDirectBodyState3D, color=Color.MAGENTA):
	var forcePosition = globalPosition-state.transform.origin
	state.apply_force(globalForce, forcePosition)
	$debugVectors.addVector(globalPosition, globalForce*state.inverse_mass, color)
