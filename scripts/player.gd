extends CharacterBody3D

#Player nodes
@onready var neck: Node3D = $neck
@onready var head: Node3D = $neck/head
@onready var eyes: Node3D = $neck/head/eyes


@onready var camera_3d: Camera3D = $neck/head/eyes/Camera3D
@onready var standing_collider: CollisionShape3D = $StandingCollider
@onready var crouching_collider: CollisionShape3D = $CrouchingCollider
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var animation_player: AnimationPlayer = $neck/head/eyes/AnimationPlayer


#Movement variables
var currentSpeed = 5.0
@export var walkSpeed = 5.0
@export var sprintSpeed = 8.0
@export var crouchSpeed = 3.0
@export var lerpSpeed = 10.0
@export var airLerpSpeed = 3.0
@export var freeLookLerpSpeed = 5.0
@export var freeLookTiltAmount = 6
var lastVelocity = Vector3.ZERO

@export var enableHeadBobbing = false

#Player States
var walking = false
var sprinting = false
var crouching = false
var freelooking = false
var sliding = false


#Head Bobbing variables
const headBobSprintingSpeed = 22.0
const headBobWalkingSpeed = 14.0
const headBobCrouchingSpeed = 10.0

const headBobCrouchingIntensity = 0.05
const headBobSprintingIntensity = 0.2
const headBobWalkingIntensity = 0.1

var headBobCurrentIntensity = 0.05
var headBobbingVector = Vector2.ZERO
var headBobbingIndex = 0.0

#Stair Movement
const MAX_STEP_HEIGHT = 0.5
var _snapped_to_stairs_last_frame := false
var _last_frame_was_on_floor = -INF

#Input variables
@export var mouseSens = 0.4
var direction = Vector3.ZERO
var cursorLock = true

#Constants:
const JUMP_VELOCITY = 4.5
var crouchDepth = -0.6

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _process(_delta: float) -> void:
	if (Input.is_action_just_pressed("quit")) :
		get_tree().quit()
	if (Input.is_action_just_pressed("cursor_unlock")) :
		cursorLock = !cursorLock
		if (!cursorLock):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if cursorLock:
			if freelooking:
				neck.rotate_y(deg_to_rad(-event.relative.x*mouseSens))
				neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-100), deg_to_rad(100))
			else :
				rotate_y(deg_to_rad(-event.relative.x*mouseSens))
			head.rotate_x(deg_to_rad(-event.relative.y*mouseSens))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		
func is_surface_too_steep(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle

func _snap_down_to_stairs_check() -> void:
	var did_snap := false
	var was_on_floor_last_frame = Engine.get_physics_frames() - _last_frame_was_on_floor == 1
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame):
		var body_test_result = PhysicsTestMotionResult3D.new()	
		if run_body_test_motion(self.global_transform, Vector3(0, -MAX_STEP_HEIGHT, 0), body_test_result):
			var translate_y = body_test_result.get_travel().y;
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_snapped_to_stairs_last_frame = did_snap
func run_body_test_motion(from : Transform3D, motion: Vector3, result=null) -> bool:
		if not result: result = PhysicsTestMotionResult3D.new()
		var params = PhysicsTestMotionParameters3D.new()
		params.from = from
		params.motion = motion
		return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)
func _physics_process(delta: float) -> void:
	if is_on_floor(): _last_frame_was_on_floor = Engine.get_physics_frames()
	#Get input
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	
	#Handling movement states
	if Input.is_action_pressed("crouch"): #Crouch
		currentSpeed = lerp(currentSpeed, crouchSpeed, delta*lerpSpeed)
		head.position.y = lerp(head.position.y, crouchDepth, delta*lerpSpeed)
		
		standing_collider.disabled = true
		crouching_collider.disabled = false
		
		walking = false
		sprinting = false
		crouching = true
		
	elif !ray_cast_3d.is_colliding(): #Stand
		standing_collider.disabled = false
		crouching_collider.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta*lerpSpeed)
		
		if Input.is_action_pressed("sprint"):
			#Sprinting
			currentSpeed = lerp(currentSpeed, sprintSpeed, delta*lerpSpeed)
			walking = false
			sprinting = true
			crouching = false
		else:
			#Walking
			currentSpeed = lerp(currentSpeed, walkSpeed, delta*lerpSpeed)
			walking = true
			sprinting = false
			crouching = false
		
	#Handle freelook
	if (Input.is_action_pressed("freelook")) :
		freelooking =true
		eyes.rotation.z = deg_to_rad(neck.rotation.y*freeLookTiltAmount)
		
	else:
		freelooking = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta*freeLookLerpSpeed)
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, freeLookLerpSpeed*delta)
		
	#Handle Headbob
	if enableHeadBobbing == true:	
		if sprinting:
			headBobCurrentIntensity = headBobSprintingIntensity
			headBobbingIndex += headBobSprintingSpeed*delta
		elif walking:
			headBobCurrentIntensity = headBobWalkingIntensity
			headBobbingIndex += headBobWalkingSpeed*delta
		elif crouching:
			headBobCurrentIntensity = headBobCrouchingIntensity
			headBobbingIndex += headBobCrouchingSpeed*delta
			
		if is_on_floor() && input_dir != Vector2.ZERO:
			headBobbingVector.y = sin(headBobbingIndex)
			headBobbingVector.x = sin(headBobbingIndex/2)+0.5
			
			eyes.position.y = lerp(eyes.position.y, headBobbingVector.y*(headBobCurrentIntensity/2.0), delta*lerpSpeed)
			eyes.position.x = lerp(eyes.position.x, headBobbingVector.x*(headBobCurrentIntensity), delta*lerpSpeed)
		else:
			eyes.position.y = lerp(eyes.position.y, 0.0, delta*lerpSpeed)
			eyes.position.x = lerp(eyes.position.x, 0.0, delta*lerpSpeed)
		
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump
	var jumpAnimations = ["jump_1", "jump_2"]
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		animation_player.play(jumpAnimations[randi_range(0,1)])
	
	#Handle landing
	var landingAnimations = ["landing_1", "landing_2"]
	if is_on_floor():
		if lastVelocity.y < 0.0:
			animation_player.play(landingAnimations[randi_range(0,1)])
	
	# Get the input direction and handle the movement/deceleration.
	if is_on_floor():
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*lerpSpeed)
	else :
		if input_dir != Vector2.ZERO:
			direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*airLerpSpeed)
		
	#Handle stairs movement : 
	
	if direction:
		velocity.x = direction.x * currentSpeed
		velocity.z = direction.z * currentSpeed
	else:
		velocity.x = move_toward(velocity.x, 0, currentSpeed)
		velocity.z = move_toward(velocity.z, 0, currentSpeed)

	lastVelocity = velocity
	move_and_slide()
	_snap_down_to_stairs_check()
