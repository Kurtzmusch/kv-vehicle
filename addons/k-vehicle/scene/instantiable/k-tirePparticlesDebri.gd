extends GPUParticles3D

class_name KVTireParticlesDebri
@export var slippingEmitThreshold = 1.0
@export var velocityMultiplier = Vector3.ONE
@export var velocityY = 0.25

var wheel: KVWheel
var processMaterial: ParticleProcessMaterial
# Called when the node enters the scene tree for the first time.
func _ready():
	wheel = get_parent().get_parent()
	processMaterial = process_material

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if !wheel.grounded: emitting = false; return
	if !wheel.tireResponse: emitting = false; return
	if wheel.tireResponse.materialName != name: emitting = false; return
	emitting = wheel.contactRelativeVelocity.length() > slippingEmitThreshold
	var velocity = wheel.contactRelativeVelocity
	velocity.z *= -1.0
	velocity *= velocityMultiplier
	velocity.y = 0.25
	var dir = velocity.normalized()
	var vel = velocity.length()
	processMaterial.direction = dir
	processMaterial.initial_velocity_min = vel
	processMaterial.initial_velocity_max = vel
