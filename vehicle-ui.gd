extends Control

@export var engine: Node
@export var drivetrain: Node
@export var vehicle: Node

@export var unit = 'ms'

var convertionTable = { 'ms': 1.0, 'kmh': 3.6, 'mph': 2.23694 }

func _ready():
	if !convertionTable.has(unit): unit = 'ms'

func setVehicle(node):
	vehicle = node
	engine = vehicle.get_node('engine')
	drivetrain = vehicle.get_node('drivetrain')
	$FeedbackIndicator.vehicle = vehicle

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !vehicle: return
	$bar.value = engine.revsPerMinute/engine.maxRevsPerMinute
	var gearUINumber = drivetrain.currentGearIndex-drivetrain.neutralGearIndex#*sign(drivetrain.gearRatio)
	if gearUINumber == 0:
		gearUINumber = 'N'
	#$bar/HBoxContainer/LabelGearValue.text = str(drivetrain.gearRatio)
	$bar/HBoxContainer/LabelGearValue.text = str(gearUINumber)
	$LabelSpeed.text = str( vehicle.speedMS*convertionTable[unit] )
