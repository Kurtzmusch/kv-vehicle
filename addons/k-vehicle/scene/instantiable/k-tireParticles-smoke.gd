extends GPUParticles3D

class_name KVTireParticlesSmoke

@export var slippingEmitThreshold = 2.0

var wheel: KWheel
# Called when the node enters the scene tree for the first time.
func _ready():
	wheel = get_parent().get_parent()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if wheel.surfaceMaterial != name:
		emitting = false
		return
	emitting = wheel.contactRelativeVelocity.length() > slippingEmitThreshold
