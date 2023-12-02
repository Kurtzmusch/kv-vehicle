extends Node

@export var vehicle: Node
@export var transmission: Node
@export var mouseSteering = true

@export var mouseSteerNonLinearity = 1.25
@export var gPadSteerNonLinearity = 1.25

@export var steeringDecay = 2.0
@export var steeringSensitivity = 3.0

@export var skiddingCounterSteer = 1.0
@export var antiDrift = 1.0
@export var inverseSpeedScale = 0.04

## 0: mouse
## 1: keyboard
## 2: gpad
@export var steeringFunctionIndex = 1

var steeringFunctions = [
	steerMouse,
	steerKeyboard,
	steerGpad
]

var steeringFunction = steerMouse

func steerMouse(delta):
	#print(get_viewport().get_mouse_position())
	var viewport = get_viewport()
	var normalizedMouseX = viewport.get_mouse_position()/viewport.get_visible_rect().size
	normalizedMouseX = normalizedMouseX.x
	normalizedMouseX = (normalizedMouseX-0.5)*2.0
	normalizedMouseX = sign(normalizedMouseX) * pow(abs(normalizedMouseX), mouseSteerNonLinearity)
	vehicle.normalizedSteering = normalizedMouseX

func steerKeyboard(delta):
	vehicle.normalizedSteering += Input.get_axis('steer-', 'steer+')*delta*steeringSensitivity#*inverseSpeed
	vehicle.normalizedSteering += Input.get_axis('throtle-increase', 'throtle-decrease')*delta*steeringSensitivity*3.0
	vehicle.normalizedSteering = move_toward(vehicle.normalizedSteering, 0.0, delta*steeringDecay)#*inverseSpeed)

func steerGpad(delta):
	var steeringInput = Input.get_axis('steer-', 'steer+')
	steeringInput = sign(steeringInput) * pow(abs(steeringInput), gPadSteerNonLinearity)
	vehicle.normalizedSteering = steeringInput

func _enter_tree():
	if !vehicle:
		vehicle = get_parent()

func _ready():
	return

func _process(delta):
	if Input.is_action_just_pressed('enable-gpad'):
		steeringFunctionIndex = 2

func _physics_process(delta):
	handleInput(delta)

func handleInput(delta):
	if vehicle.freeze: return
	steeringFunction = steeringFunctions[steeringFunctionIndex]
	if transmission:
		if sign( transmission.getGearRatio() ) >= 0:
			vehicle.accelerationInput = Input.get_action_strength('acceleration+')
			vehicle.break2Input = Input.get_action_strength('acceleration-')
		else:
			vehicle.accelerationInput = Input.get_action_strength('acceleration-')
			vehicle.break2Input = Input.get_action_strength('acceleration+')
	else:
		vehicle.accelerationInput = Input.get_action_strength('acceleration+')
	if steeringFunction == steerGpad:
		vehicle.accelerationInput = Input.get_action_strength('acceleration+')
		vehicle.break2Input = Input.get_action_strength('acceleration-')
	vehicle.breaking = (Input.get_action_strength("handbreak") > 0.9) or (vehicle.break2Input > 0.9)
	
	steeringFunction.call(delta)
