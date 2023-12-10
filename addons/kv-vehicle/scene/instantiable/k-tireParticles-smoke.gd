extends GPUParticles3D
## particles emitter logic for smoke-like effects

class_name KVTireParticlesSmoke

@export var slippingEmitThreshold = 2.0

var wheel: KVWheel
# Called when the node enters the scene tree for the first time.
func _ready():
	wheel = get_parent().get_parent()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if !wheel.grounded: emitting = false; return
	if !wheel.tireResponse: emitting = false; return
	if wheel.tireResponse.materialName != name: emitting = false; return
	emitting = wheel.contactRelativeVelocity.length() > slippingEmitThreshold
