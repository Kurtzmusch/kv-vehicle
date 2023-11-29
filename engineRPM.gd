extends ProgressBar

@export var engine: Node
@export var drivetrain: Node


func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	value = engine.revsPerMinute/engine.maxRevsPerMinute
	var gearUINumber = drivetrain.currentGearIndex-drivetrain.neutralGearIndex#*sign(drivetrain.gearRatio)
	if gearUINumber == 0:
		gearUINumber = 'N'
	$HBoxContainer/LabelGearValue.text = str(drivetrain.gearRatio)#str(gearUINumber)
