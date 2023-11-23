extends RigidBody3D

class_name KVehicle

## if true, creates a cilinder collider for each wheel
@export var createWheelMinimumColliders = true

var normalizedSteering = 0.0
var break2Input = 0.0
var accelerationInput = 0.0
var breaking = false

var wheels = []

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

func _integrate_forces(state):
	var contribution = 1.0/wheels.size()
	$debugVectors.clear()
	apply_central_force(accelerationInput*mass*global_transform.basis.z)
	for wheel in wheels:
		wheel.updateCasts()
		wheel.applySuspensionForce(state, state.step, 1.0/state.step, contribution)

func applyGlobalForceState(globalForce, globalPosition, state:PhysicsDirectBodyState3D, color=Color.MAGENTA):
	var forcePosition = globalPosition-state.transform.origin
	state.apply_force(globalForce, forcePosition)
	$debugVectors.addVector(globalPosition, globalForce*state.inverse_mass, color)
