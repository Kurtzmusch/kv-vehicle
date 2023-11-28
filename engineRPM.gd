extends ProgressBar

@export var engine: Node
@export var drivetrain: Node
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	value = engine.revsPerMinute/engine.maxRevsPerMinute
	var gearUINumber = drivetrain.currentGearIndex*sign(drivetrain.gearRatio)
	$HBoxContainer/LabelGearValue.text = str(gearUINumber)
