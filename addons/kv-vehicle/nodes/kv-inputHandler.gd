extends Node

@export var vehicle: KVVehicle

## transmission or drivetrain: must contain a gearRatio property
@export var transmission: Node

## sensitivity curve. higher values make low inputs even lower
@export var mouseSteerNonLinearity = 1.25
## sensitivity curve. higher values make low inputs even lower
@export var gPadSteerNonLinearity = 1.25

## decay rate of breaking when not using gpad
@export var breakDecay = 10.0
## break increase speed when not using gpad
@export var breakSensitivity = 15.0

## decay rate of the accelerator when not using gpad
@export var acceleratorDecay = 0.25
## accelerator increase speed when not using gpad
@export var acceleratorSensitivity = 5.0


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

## if true, enabled assist for gpad and mouse inputs, the variables below affect this assist
@export var assisted = true

## slip angle threshold(degress) to consider the rear to be sliding
@export var rearDriftingThresholdDeg = 10.0

## amount of steering to counter rear slip
@export var antiRearSlip = 0.5

@export var rearWheels: Array[KVWheel]

var steeringFunctions = [
	steerMouse,
	steerKeyboard,
	steerGpad
]

var steeringFunction = steerMouse

var steeringWheels = Array()

var oneByWheelCount = 0.0


func steerAssisted(delta, steeringInput, steerNonLinearity):
	
	var avgSlipAngle = 0.0
	var avgTargetAngle = 0.0
	var avgAngleActual = 0.0
	for wheel in steeringWheels:
		var currentAngle = wheel.get_node('wheelSteerPivot').rotation.y
		avgSlipAngle += wheel.slipAngle*oneByWheelCount
		avgAngleActual += (currentAngle)*oneByWheelCount
		avgTargetAngle += (currentAngle-wheel.slipAngle)*oneByWheelCount
	var tireResponse = steeringWheels[0].tireResponse as TireResponse
	var avgTargetAngleNormalized = avgTargetAngle/steeringWheels[0].maxSteerAngle
	var maxSteerNromalizedRelative = deg_to_rad(16.0)/steeringWheels[0].maxSteerAngle
	var max = -avgTargetAngleNormalized+maxSteerNromalizedRelative
	var min = -avgTargetAngleNormalized-maxSteerNromalizedRelative
	
	#reduces the assist at low speeds, since the assits have a tendecy of keeping the vehicle turning to keep a good slip angle
	var adjustedVelocity = pow(0.125*vehicle.linear_velocity.length(), 2.0)
	var inputWeight = maxSteerNromalizedRelative + ( (1.0-maxSteerNromalizedRelative)/(adjustedVelocity+1.0) )
	
	var modMouseX =sign(steeringInput) * pow(abs(steeringInput), steerNonLinearity)
	
	var clampedInput = clamp(modMouseX*inputWeight, min, max)
	
	var rearDrifting = abs(rearWheels[0].slipAngle) > deg_to_rad(rearDriftingThresholdDeg)
	
	if rearDrifting:
		var lerpBegin = lerp(0.0,-avgTargetAngleNormalized, antiRearSlip)
		clampedInput = lerp(lerpBegin, -avgTargetAngleNormalized, -sign(avgTargetAngleNormalized)*steeringInput)
	
	
	vehicle.normalizedSteering = clamp(clampedInput, -1.0,1.0)
	if -vehicle.localLinearVelocity.z < 1.0:
		vehicle.normalizedSteering = steeringInput

func steerGpad(delta):
	#mouse emulation
	
	"""
	printerr('mouse emulation is on')
	var viewport = get_viewport()
	var normalizedMouseX = viewport.get_mouse_position()/viewport.get_visible_rect().size
	normalizedMouseX = normalizedMouseX.x
	normalizedMouseX = (normalizedMouseX-0.5)*2.0
	if normalizedMouseX < 0.0:
		Input.action_press('steer-',abs(normalizedMouseX))
	if normalizedMouseX > 0.0:
		Input.action_press('steer+',abs(normalizedMouseX))
	"""
	
	var steeringInput = Input.get_axis('steer-', 'steer+')
	
	if assisted:
		steerAssisted(delta, steeringInput, gPadSteerNonLinearity)
		return
	steeringInput = sign(steeringInput) * pow(abs(steeringInput), gPadSteerNonLinearity)
	vehicle.normalizedSteering = steeringInput

func steerMouse(delta):
	
	#print(get_viewport().get_mouse_position())
	var viewport = get_viewport()
	var normalizedMouseX = viewport.get_mouse_position()/viewport.get_visible_rect().size
	normalizedMouseX = normalizedMouseX.x
	normalizedMouseX = (normalizedMouseX-0.5)*2.0
	
	if assisted:
		steerAssisted(delta, normalizedMouseX, mouseSteerNonLinearity)
		return
	
	normalizedMouseX = sign(normalizedMouseX) * pow(abs(normalizedMouseX), mouseSteerNonLinearity)
	vehicle.normalizedSteering = normalizedMouseX
"""
func steerMouse(delta):
	#print(get_viewport().get_mouse_position())
	var viewport = get_viewport()
	var normalizedMouseX = viewport.get_mouse_position()/viewport.get_visible_rect().size
	normalizedMouseX = normalizedMouseX.x
	normalizedMouseX = (normalizedMouseX-0.5)*2.0
	normalizedMouseX = sign(normalizedMouseX) * pow(abs(normalizedMouseX), mouseSteerNonLinearity)
	vehicle.normalizedSteering = normalizedMouseX
"""
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

func _enter_tree():
	if !vehicle:
		vehicle = get_parent()

func _ready():
	updateSteeringWheels()

func _process(delta):
	if Input.is_action_just_pressed('enable-gpad'):
		steeringMethod = steeringMethods.Gpad
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
	var targetBreak = 0.0
	var targetAccelerator = 0.0
	if transmission:
		
		if sign( transmission.getGearRatio() ) >= 0:
			
			targetAccelerator = Input.get_action_strength('acceleration+')
			targetBreak = Input.get_action_strength('acceleration-')
		else:
			targetAccelerator = Input.get_action_strength('acceleration-')
			targetBreak = Input.get_action_strength('acceleration+')
	else:
		targetAccelerator = Input.get_action_strength('acceleration+')
		targetBreak = Input.get_action_strength('acceleration-')
	vehicle.break2Input = move_toward(vehicle.break2Input,\
	0.0, delta*breakDecay)
	vehicle.break2Input = move_toward(vehicle.break2Input,\
	targetBreak, delta*breakSensitivity)
	vehicle.accelerationInput = move_toward(vehicle.accelerationInput,\
	0.0, delta*acceleratorDecay)
	vehicle.accelerationInput = move_toward(vehicle.accelerationInput,\
	targetAccelerator, delta*acceleratorSensitivity)
	
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
