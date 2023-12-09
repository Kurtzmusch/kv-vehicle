extends Node

@export var vehicle: KVVehicle

## transmission or drivetrain: must contain a gearRatio property
@export var transmission: Node

## sensitivity curve. higher values make low inputs even lower
@export var mouseSteerNonLinearity = 1.25
## sensitivity curve. higher values make low inputs even lower
@export var gPadSteerNonLinearity = 1.25

## decay rate of steering when using keyboard steering
@export var steeringDecay = 2.0
## steer speed when using keyboard steering
@export var steeringSensitivity = 3.0
 
@export var steerMaxSlipAngle = deg_to_rad(10.0)
## moves the steering input to minimize slip, pointing the steering tires towards the direction they are moving
## [br] does nothing when using mouse steering
@export var antiSlip = 1.0


## reduces steering sensitivity as the vehicle gets faster
@export var inverseSpeedScale = 0.02

enum steeringMethods {
	Mouse,
	Keyboard,
	Gpad
}
@export var steeringMethod = steeringMethods.Mouse

var steeringFunctions = [
	steerMouse,
	steerKeyboard,
	steerGpad
]

var steeringFunction = steerMouse

var steeringWheels = Array()

var oneByWheelCount = 0.0

func steerMouse(delta):
	#print(get_viewport().get_mouse_position())
	var viewport = get_viewport()
	var normalizedMouseX = viewport.get_mouse_position()/viewport.get_visible_rect().size
	normalizedMouseX = normalizedMouseX.x
	normalizedMouseX = (normalizedMouseX-0.5)*2.0
	normalizedMouseX = sign(normalizedMouseX) * pow(abs(normalizedMouseX), mouseSteerNonLinearity)
	vehicle.normalizedSteering = normalizedMouseX

func steerKeyboard(delta):
	var inverseSpeed = 1.0/(1.0 + (abs(vehicle.localLinearVelocity.z)*inverseSpeedScale))
	vehicle.normalizedSteering += Input.get_axis('steer-', 'steer+')*delta*steeringSensitivity*inverseSpeed
	#vehicle.normalizedSteering += Input.get_axis('throtle-increase', 'throtle-decrease')*delta*steeringSensitivity*3.0
	vehicle.normalizedSteering = move_toward(vehicle.normalizedSteering, 0.0, delta*steeringDecay)#*inverseSpeed)
	vehicle.normalizedSteering = clamp(vehicle.normalizedSteering, -1.0, 1.0)
	var avgSlipAngle = 0.0
	for wheel in steeringWheels:
		avgSlipAngle += wheel.slipAngle*oneByWheelCount
	var modAntiSlip = antiSlip
	if abs(avgSlipAngle) > steerMaxSlipAngle:
		modAntiSlip = 10.0+abs(avgSlipAngle)
	if vehicle.linear_velocity.length_squared() > .125 and vehicle.localLinearVelocity.z < 0.0:
		vehicle.normalizedSteering = move_toward(vehicle.normalizedSteering, sign(avgSlipAngle), delta*abs(avgSlipAngle)*modAntiSlip)

func steerGpad(delta):
	var steeringInput = Input.get_axis('steer-', 'steer+')
	steeringInput = sign(steeringInput) * pow(abs(steeringInput), gPadSteerNonLinearity)
	vehicle.normalizedSteering = steeringInput

func _enter_tree():
	if !vehicle:
		vehicle = get_parent()

func _ready():
	updateSteeringWheels()

func _process(delta):
	if Input.is_action_just_pressed('enable-gpad'):
		steeringFunction = steeringMethod.Gpad
	if Input.is_action_just_pressed('toggle-mouse-steering'):
		if steeringMethod == steeringMethods.Keyboard:
			steeringMethod = steeringMethods.Mouse
		elif steeringMethod == steeringMethods.Mouse:
			steeringMethod = steeringMethods.Keyboard
func _physics_process(delta):
	handleInput(delta)

func handleInput(delta):
	if vehicle.freeze: return
	steeringFunction = steeringFunctions[steeringMethod]
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
	vehicle.clutchInput = Input.get_action_strength('clutch')
	steeringFunction.call(delta)

func updateSteeringWheels():
	steeringWheels.clear()
	for wheel in vehicle.wheels:
		if wheel.steer:
			steeringWheels.append(wheel)
	oneByWheelCount = 1.0/steeringWheels.size()
