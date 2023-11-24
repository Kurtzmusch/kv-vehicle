extends Label

@export var unit = 'ms'

var convertionTable = { 'ms': 1.0, 'kmh': 3.6, 'mph': 2.23694 }

func _ready():
	if !convertionTable.has(unit): unit = 'ms'

func _process(delta):
	text = str( get_parent().speedMS*convertionTable[unit] )
