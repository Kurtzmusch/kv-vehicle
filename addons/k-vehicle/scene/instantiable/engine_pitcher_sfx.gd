extends AudioStreamPlayer3D

@export var streamRevsPerMinute: float
var engine
# Called when the node enters the scene tree for the first time.
func _ready():
	engine = get_parent()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _physics_process(delta):
	pitch_scale = remap(engine.revsPerMinute,\
	0.0, streamRevsPerMinute,
	0.0, 1.0)
	pitch_scale = clamp(pitch_scale, 0.125, 1.5)
