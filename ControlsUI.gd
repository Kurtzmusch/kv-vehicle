extends Control

func _ready():
	pass

func _process(delta):
	pass

func _on_button_toggled(button_pressed):
	$VBoxContainer/PanelContainer.visible = button_pressed
