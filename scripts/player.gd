extends CharacterBody3D

# --- Player Nodes ---
@onready var neck: Node3D = $neck
@onready var head: Node3D = $neck/head
@onready var eyes: Node3D = $neck/head/eyes
@onready var camera_3d: Camera3D = $neck/head/eyes/Camera3D
@onready var standing_collider: CollisionShape3D = $StandingCollider
@onready var crouching_collider: CollisionShape3D = $CrouchingCollider
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var animation_player: AnimationPlayer = $neck/head/eyes/AnimationPlayer

# --- Wall Running Nodes ---
@onready var wall_ray_left = $player_ka_dil/WallRaycastLeft
@onready var wall_ray_right = $player_ka_dil/WallRaycastRight
@onready var wall_ray_front = $player_ka_dil/WallRaycastFront

# --- Movement Variables ---
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

# --- Player States ---
var walking = false
var sprinting = false
var crouching = false
var freelooking = false
var sliding = false

# --- Head Bobbing Variables ---
const headBobSprintingSpeed = 22.0
const headBobWalkingSpeed = 14.0
const headBobCrouchingSpeed = 10.0
const headBobCrouchingIntensity = 0.05
const headBobSprintingIntensity = 0.2
const headBobWalkingIntensity = 0.1
var headBobCurrentIntensity = 0.05
var headBobbingVector = Vector2.ZERO
var headBobbingIndex = 0.0

# --- Stair Movement ---
const MAX_STEP_HEIGHT = 0.5
var _snapped_to_stairs_last_frame := false
var _last_frame_was_on_floor = -INF

# --- Wall Run Variables ---
@export var wall_run_speed = 12.0
@export var wall_run_gravity = 9.8
@export var wall_jump_force = 8.0
@export var wall_camera_tilt = 15.0
@export var wall_run_time = 1.5
var wall_run_timer = 0.0
var is_wall_running = false
var current_wall_normal = Vector3.ZERO
var wall_side = 0  # -1 = left, 1 = right, 0 = front

# --- Camera FX Variables ---
@export var fov_sprint = 85.0
@export var fov_wallrun = 95.0
const FOV_CHANGE_SPEED = 8.0

# --- Input Variables ---
@export var mouseSens = 0.4
var direction = Vector3.ZERO
var cursorLock = true

# --- Constants ---
const JUMP_VELOCITY = 8
var crouchDepth = -0.6

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	if Input.is_action_just_pressed("cursor_unlock"):
		cursorLock = !cursorLock
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if !cursorLock else Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and cursorLock:
		if freelooking:
			neck.rotate_y(deg_to_rad(-event.relative.x * mouseSens))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-100), deg_to_rad(100))
		else:
			rotate_y(deg_to_rad(-event.relative.x * mouseSens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouseSens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	if is_on_floor(): 
		_last_frame_was_on_floor = Engine.get_physics_frames()
	
	handle_wall_run(delta)
	handle_camera_effects(delta)

	# --- Movement States ---
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	if Input.is_action_pressed("crouch"):
		currentSpeed = lerp(currentSpeed, crouchSpeed, delta * lerpSpeed)
		head.position.y = lerp(head.position.y, crouchDepth, delta * lerpSpeed)
		standing_collider.disabled = true
		crouching_collider.disabled = false
		walking = false
		sprinting = false
		crouching = true
	elif !ray_cast_3d.is_colliding():
		standing_collider.disabled = false
		crouching_collider.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta * lerpSpeed)
		if Input.is_action_pressed("sprint"):
			currentSpeed = lerp(currentSpeed, sprintSpeed, delta * lerpSpeed)
			walking = false
			sprinting = true
			crouching = false
		else:
			currentSpeed = lerp(currentSpeed, walkSpeed, delta * lerpSpeed)
			walking = true
			sprinting = false
			crouching = false

	# --- Freelook ---
	if Input.is_action_pressed("freelook"):
		freelooking = true
		eyes.rotation.z = deg_to_rad(neck.rotation.y * freeLookTiltAmount)
	else:
		freelooking = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * freeLookLerpSpeed)
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, freeLookLerpSpeed * delta)

	# --- Headbob ---
	if enableHeadBobbing:
		if sprinting:
			headBobCurrentIntensity = headBobSprintingIntensity
			headBobbingIndex += headBobSprintingSpeed * delta
		elif walking:
			headBobCurrentIntensity = headBobWalkingIntensity
			headBobbingIndex += headBobWalkingSpeed * delta
		elif crouching:
			headBobCurrentIntensity = headBobCrouchingIntensity
			headBobbingIndex += headBobCrouchingSpeed * delta
		if is_on_floor() and input_dir != Vector2.ZERO:
			headBobbingVector.y = sin(headBobbingIndex)
			headBobbingVector.x = sin(headBobbingIndex / 2) + 0.5
			eyes.position.y = lerp(eyes.position.y, headBobbingVector.y * (headBobCurrentIntensity / 2.0), delta * lerpSpeed)
			eyes.position.x = lerp(eyes.position.x, headBobbingVector.x * (headBobCurrentIntensity), delta * lerpSpeed)
		else:
			eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerpSpeed)
			eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerpSpeed)

	# --- Gravity ---
	if not is_on_floor() and !is_wall_running:
		velocity += get_gravity() * delta

	# --- Jump ---
	var jumpAnimations = ["jump_1", "jump_2"]
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		animation_player.play(jumpAnimations[randi_range(0, 1)])

	# --- Land Animation ---
	var landingAnimations = ["landing_1", "landing_2"]
	if is_on_floor():
		if lastVelocity.y < 0.0:
			animation_player.play(landingAnimations[randi_range(0, 1)])

	# --- Movement Direction ---
	if is_on_floor() or is_wall_running:
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerpSpeed)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * airLerpSpeed)

	if direction:
		velocity.x = direction.x * currentSpeed
		velocity.z = direction.z * currentSpeed
	else:
		velocity.x = move_toward(velocity.x, 0, currentSpeed)
		velocity.z = move_toward(velocity.z, 0, currentSpeed)

	lastVelocity = velocity
	move_and_slide()
	_snap_down_to_stairs_check()

# ---------------- WALL RUNNING SYSTEM ----------------
func handle_wall_run(delta):
	if is_on_floor():
		end_wall_run()
		return

	var can_wall_run = false
	current_wall_normal = Vector3.ZERO
	wall_side = 0

	if wall_ray_left.is_colliding():
		current_wall_normal = wall_ray_left.get_collision_normal()
		wall_side = -1
		can_wall_run = true
	elif wall_ray_right.is_colliding():
		current_wall_normal = wall_ray_right.get_collision_normal()
		wall_side = 1
		can_wall_run = true
	elif wall_ray_front.is_colliding():
		current_wall_normal = wall_ray_front.get_collision_normal()
		wall_side = 0
		can_wall_run = true

	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var wants_wall_run = can_wall_run and Input.is_action_pressed("forward") and velocity.y < 0

	if wants_wall_run:
		if !is_wall_running:
			start_wall_run()
		var wall_forward = current_wall_normal.cross(Vector3.UP)
		if wall_side == 1:
			wall_forward = -wall_forward
		if wall_side == 0:
			wall_forward = -transform.basis.z
		
		velocity.x = wall_forward.x * wall_run_speed
		velocity.z = wall_forward.z * wall_run_speed
		velocity.y = -wall_run_gravity * delta

		eyes.rotation.z = lerp_angle(eyes.rotation.z, deg_to_rad(wall_camera_tilt * wall_side), delta * 8)
		wall_run_timer += delta
		if wall_run_timer >= wall_run_time:
			end_wall_run()
	else:
		end_wall_run()

	if is_wall_running and Input.is_action_just_pressed("jump"):
		var jump_dir = current_wall_normal + Vector3.UP
		velocity = jump_dir.normalized() * wall_jump_force
		end_wall_run()
		apply_camera_jump_effect()

func start_wall_run():
	is_wall_running = true
	wall_run_timer = 0.0
	currentSpeed = wall_run_speed
	if animation_player.has_animation("wall_run_start"):
		animation_player.play("wall_run_start")

func end_wall_run():
	if is_wall_running:
		is_wall_running = false
		eyes.rotation.z = lerp_angle(eyes.rotation.z, 0.0, 0.2)
		if animation_player.has_animation("wall_run_end"):
			animation_player.play("wall_run_end")
		currentSpeed += 100

# ---------------- STAIR MOVEMENT SYSTEM ----------------
func _snap_down_to_stairs_check() -> void:
	var did_snap := false
	var was_on_floor_last_frame = Engine.get_physics_frames() - _last_frame_was_on_floor == 1
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame):
		var body_test_result = PhysicsTestMotionResult3D.new()	
		if run_body_test_motion(self.global_transform, Vector3(0, -MAX_STEP_HEIGHT, 0), body_test_result):
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_snapped_to_stairs_last_frame = did_snap

func run_body_test_motion(from : Transform3D, motion: Vector3, result=null) -> bool:
	if not result: 
		result = PhysicsTestMotionResult3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)

# ---------------- CAMERA EFFECTS ----------------
func handle_camera_effects(delta):
	var target_fov = fov_sprint if sprinting else 75.0
	target_fov = fov_wallrun if is_wall_running else target_fov
	camera_3d.fov = lerp(camera_3d.fov, target_fov, delta * FOV_CHANGE_SPEED)

func apply_camera_jump_effect():
	var jump_tilt = deg_to_rad(5.0)
	var tween = create_tween()
	tween.tween_property(eyes, "rotation:z", jump_tilt, 0.1)
	tween.tween_property(eyes, "rotation:z", 0.0, 0.3)
