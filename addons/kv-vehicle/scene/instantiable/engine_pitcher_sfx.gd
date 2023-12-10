extends AudioStreamPlayer3D
## basic sfx logic for scaling in pitch and volume

class_name KVEngineSFX

@export var streamRevsPerMinute: float
@export var engine: Node

## loudness of this player relative to throtle input
##[br] 2 KVEngineSFX can be used as a crossfader if you have audio different audio samples
## for on/off throtle
@export var volumeThrotleCurve: Curve

var vehicle

# Called when the node enters the scene tree for the first time.
func _ready():
	vehicle = get_parent()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _physics_process(delta):
	pitch_scale = remap(engine.revsPerMinute,\
	0.0, streamRevsPerMinute,
	0.0, 1.0)
	volume_db = linear_to_db( volumeThrotleCurve.sample(max(vehicle.accelerationInput, 0.0)) )
