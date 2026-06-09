extends CharacterBody3D

const SPEED = 5.0
const FLY_SPEED = 6.0  # Separate speed for flying if you want it faster/slower
const JUMP_VELOCITY = 4.5

var fly: bool = false

func _physics_process(delta: float) -> void:

	# Toggle fly mode
	if Input.is_action_just_pressed("Fly"):
		fly = !fly
		# Optional: Reset vertical velocity when toggling so you don't suddenly plunge or rocket up
		velocity.y = 0 

	# --- 1. HANDLE VERTICAL MOVEMENT (FLYING vs GRAVITY) ---
	if fly:
		var vertical_direction := 0.0
		
		# Read up/down inputs
		# Make sure "fly_up" (Space) and "fly_down" (Shift) are defined in Project Settings -> Input Map
		if Input.is_key_label_pressed(KEY_SPACE):
			vertical_direction += 1.0
		if Input.is_key_label_pressed(KEY_SHIFT):
			vertical_direction -= 1.0
			
		# Apply vertical movement directly
		velocity.y = vertical_direction * FLY_SPEED
	else:
		# Apply normal gravity if not flying
		if not is_on_floor():
			velocity += get_gravity() * delta

		# Handle normal jump only when on the ground and not flying
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	# --- 2. HANDLE HORIZONTAL MOVEMENT (X/Z Axis) ---
	var input_dir := Input.get_vector("Left", "Right", "Up", "Down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Determine current speed based on mode
	var current_speed = FLY_SPEED if fly else SPEED
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()