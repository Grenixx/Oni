extends CharacterBody2D

@onready var AttackSprite = $AttackSprite

var isAttacking = false
var attackDuration = 0.2 # durée de l’attaque en secondes
var attackTimer = 0.0

func start_attack():
	isAttacking = true
	attackTimer = 0.0
	AttackSprite.visible = true
	$HitBox.monitoring = true
	$HitBox.monitorable = true

func player():
	pass

#State Vars
var states = ["idle", "run", "dash", "fall", "jump", "double_jump"] #list of all states
var currentState = states[0] #what state's d qlogic is being called every frame
var previousState = null #last state that was being calles

#Nodes & paths
@onready var PlayerSprite = $Sprite2D #path to the player's sprite
@onready var Anim = $AnimationPlayer #path to animation player

@onready var RightRaycast = $RightRaycast #path to the right raycast
@onready var LeftRaycast = $LeftRaycast  #path to the left raycast

var isJumping = false      # vrai tant que la touche est maintenue
var jumpHoldTime = 0.0     # temps écoulé depuis le début du saut
var maxJumpHold = 0.5   # durée max du saut tenu (en SECONDES, typiquement entre 0.2 et 0.35)

#Squash & Stretch
var recoverySpeed = 0.03 #how fast you recover from squashes, and stretches

var landingSquash = 1.2 #x scale of PlayerSprite when you land
var landingStretch = 0.8 #y scale of PlayerSprite when you land

var jumpingSquash = 0.8 #x scale of PlayerSprite when you jump
var jumpingStretch = 1.2 #y scale of PlayerSprite when you jump

#Input Vars
var movementInput = 0 #will be 1, -1, 0 depending on if you are holding right, left, or nothing
var lastDirection = 1 #last direction pressed that is not 0

var isJumpPressed = 0 #will be 1 on the frame that the jump button was pressed
var isJumpReleased #will be 1 on the frame that the jump button was released

var coyoteStartTime = 0.2 #ticks when you pressed jump button
var elapsedCoyoteTime = 0 #elapsed time since you last clicked jump
var coyoteDuration = 0.20 #how many miliseconds to remember a jump press

var jumpInput = 0 #jump press with coyote time

var isDashPressed #will be 1 on the frame that the dash button was pressed

#Movement Vars

var currentSpeed = 0 #how much you add to x velocity when moving horizontally
var maxSpeed = 190 #maximum current speed can reach when moving horizontally
var acceleration = 25 #by how much does current speed approach max speed when moving
var decceleration = 40 #by how much does velocity approach when you stop moving horizontally

var airFriction = 60 #how much you subtract velocity when you start moving horizontally in the air

#dash
var dashSpeed = 200 #how fast you dash
var dashDurration = 100  #how long you dash for (in milisecconds)

var canDash = true #can the character dash
var dashStartTime #how many miliseconds passed when you started dashing 
var elapsedDashTime #how many milisecconds elapsed since you started dashing
var dashDirection = 1 #direction of dash will be 1 or -1 if you are dashing left or right

#fall
var gravity = 700 #how much is added to y velocity constantly

var jumpBufferStartTime  = 0 #ticks when you ran of the platform
var elapsedJumpBuffer = 0 #how many seconds passed in the jump nuffer
var jumpBuffer = 100 #how many miliseconds allowance you give jumps after you run of an edge

#jump
var jumpHeight = 100  #How high the peak of the jump is in pixels
var jumpVelocity #how much to apply to velocity.y to reach jump height

#double jump
var doubleJumpHeight = 50 #How high the peak of the double jump is in pixels
var doubleJumpVelocity #how much to apply to velocity.y to reach double jump height

#pogo
#var pogoJumpHeight = 50
#var pogoJumpVelocity 

var isDoubleJumped = false #if you have double jumped

#wall slide
var wallSlideSpeed = 50 #how fast you slide on a wll

#wall jump
var wallJumpHeight = 50 #how high you want the peak of your wall jump to be in pixels
var wallJumpVelocity #how much to apply to velocity.y to reach wall jump height

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready():
	if is_multiplayer_authority():
		#use kin functions to set jump velocites
		jumpVelocity = -sqrt(2 * gravity * jumpHeight) 
		doubleJumpVelocity = -sqrt(2 * gravity * doubleJumpHeight) 
		
		wallJumpVelocity = -sqrt(2 * gravity * jumpHeight)
		
var syncPosition : Vector2
@export var lerp_speed_syncPosition := 0.2
func _physics_process(delta):
	if not is_multiplayer_authority():
		global_position = global_position.lerp(syncPosition,lerp_speed_syncPosition)
	if is_multiplayer_authority():
		syncPosition = global_position 
		get_input()
		
		apply_gravity(delta)
		
		call(currentState + "_logic", delta) #call the current states main method
		
		set_velocity(velocity)
		set_up_direction(Vector2.UP)
		move_and_slide()
		velocity = velocity #aply velocity to movement
		
		recover_sprite_scale()
		
		PlayerSprite.flip_h = (lastDirection == -1)
		AttackSprite.flip_h = lastDirection == -1

		
		if isAttacking:
			attackTimer += delta
			if attackTimer >= attackDuration:
				isAttacking = false
				AttackSprite.visible = false
				$HitBox.monitoring = false
				$HitBox.monitorable = false

var input_vector : Vector2
func get_input():
	# Attaque
	var isAttackPressed = Input.is_action_just_pressed("attack")
	if isAttackPressed and not isAttacking:
		start_attack()

	# Mouvement horizontal
	var move_x = Input.get_action_strength("right") - Input.get_action_strength("left")
	var move_y = Input.get_action_strength("down") - Input.get_action_strength("up")
	
	input_vector = Vector2(move_x, move_y)

	# On garde movementInput pour le reste du code
	if move_x != 0:
		movementInput = sign(move_x)
	else:
		movementInput = 0
	
	# Garder lastDirection pour le dash ou flip
	if movementInput != 0:
		lastDirection = movementInput

	# Saut
	isJumpPressed = Input.is_action_just_pressed("jump")
	isJumpReleased = Input.is_action_just_released("jump")

	if jumpInput == 0 and isJumpPressed:
		jumpInput = 1
		coyoteStartTime = Time.get_ticks_msec()

	elapsedCoyoteTime = Time.get_ticks_msec() - coyoteStartTime
	if jumpInput != 0 and elapsedCoyoteTime > coyoteDuration:
		jumpInput = 0
		coyoteStartTime = 0

	# Dash
	isDashPressed = Input.is_action_just_pressed("dash")

func apply_gravity(delta):
	#apply gravity in every state except dash
	if currentState != "dash":
		velocity.y += gravity * delta


func recover_sprite_scale():
	#make sprite scale approach 0
	PlayerSprite.scale.x = move_toward(PlayerSprite.scale.x, 1, recoverySpeed)
	PlayerSprite.scale.y = move_toward(PlayerSprite.scale.y, 1, recoverySpeed)


func set_state(new_state : String):
	#update state values
	previousState = currentState
	currentState = new_state
	
	#call enter/exit methods
	if previousState != null:
		call(previousState + "_exit_logic")
	if currentState != null:
		call(currentState + "_enter_logic")

#Functions used across multiple states

func move_horizontally(subtractor):
	currentSpeed = move_toward(currentSpeed, maxSpeed, acceleration) #accelerate current speed
	
	velocity.x = currentSpeed * movementInput #apply curent speed to velocity and multiply by direction

func squash_stretch(squash, stretch):
	#set Sprite scale to squash and stretch
	PlayerSprite.scale.x = squash
	PlayerSprite.scale.y = stretch

func jump(jumpVelocity):
	velocity.y = 0 #reset velocity
	velocity.y = jumpVelocity #apply velocity
	canDash = true #allow the player to dash when they jump
	
	squash_stretch(jumpingSquash, jumpingStretch) #set squaash and stretch
#State Functions

func idle_enter_logic():
	Anim.play("Idle") #play the idle animation

func idle_logic(delta):
	if jumpInput:
		#jump if you press button
		jump(jumpVelocity)
		set_state("jump")
	
	if isDashPressed:
		#dash if you press button
		set_state("dash")
	
	if movementInput != 0:
		#start running if you press a movement button
		set_state("run")
	velocity.x = move_toward(velocity.x, 0, decceleration) #deccelerate


func idle_exit_logic():
	currentSpeed = 0 #reset current speed (we do this here to keep momentum on run jumps)



func run_enter_logic():
	Anim.play("Run") #play the run animation

func run_logic(delta):
	if jumpInput:
		#jump if you press the jump button
		jump(jumpVelocity)
		set_state("jump")
		
	if isDashPressed:
		#dash if you press the dash button
		set_state("dash")
	
	if !is_on_floor():
		#if your not on a floor, start falling and set jumpbuffer start time
		jumpBufferStartTime = Time.get_ticks_msec()
		set_state("fall")
		
	
	if movementInput == 0:
		#if your not pressing a move button go idle
		set_state("idle")
	else:
		#if pressing move button start moving
		move_horizontally(0)
	
func run_exit_logic():
	pass



func fall_enter_logic():
	Anim.play("Fall") #play the fall animation

func fall_logic(delta):
	move_horizontally(airFriction) #move horizontally
	elapsedJumpBuffer = Time.get_ticks_msec() - jumpBufferStartTime #set elapsed time for jump buffer
	
	if isJumpPressed:
		#if you press jump
		if !isDoubleJumped && elapsedJumpBuffer > jumpBuffer:
			#and jump is pressed outside the jump buffer window, and this is your first double jump
			jump(doubleJumpVelocity) #apply double jump velocity
			set_state("double_jump") #set state to double jump
		
		if elapsedJumpBuffer < jumpBuffer:
			#if your in the jump buffer window
			if previousState == "run":
				#and your previpus state is run
				jump(jumpVelocity) #jump with ground velocity
				set_state("jump") #set state to jump
			if previousState == "wall_slide":
				#and your previous state is wall slide
				jump(wallJumpVelocity) #jump with wall jump velocity
				set_state("wall_jump") #set state to wall jump
	
	if isDashPressed && canDash:
		#dash if you press dash button
		set_state("dash")
	
	if is_on_floor():
		#if player is on a floor
		set_state("run") #set state to run (we set to run to keep momentum)
		isDoubleJumped = false #reset is double jumped
		
		squash_stretch(landingSquash, landingStretch) #apply squash and stretch
		
	if LeftRaycast.is_colliding() && movementInput == -1 || RightRaycast.is_colliding() && movementInput == 1:
		#if your raycast is coliding and you are trying to move in that direction
		set_state("wall_slide")
	

func fall_exit_logic():
	jumpBufferStartTime = 0 #reset jump buffer start time

func dash_enter_logic():
	var dir = input_vector
	
	# Si aucune entrée, garder la dernière direction connue
	if dir == Vector2.ZERO:
		dir = Vector2(lastDirection,0)
	
	# 🔹 On ne garde qu’un axe cardinal (nord, sud, est, ouest)
	if abs(dir.x) > abs(dir.y):
		dir = Vector2(sign(dir.x), 0)
	else:
		dir = Vector2(0, sign(dir.y))
	
	dashDirection = dir
	
	#dashDirection = input_vector # lastDirection set dash direction (we use lastDirection to make sure we dash even when idle)
	dashStartTime = Time.get_ticks_msec() #set dash start time to total ticks since the game started
	
	velocity = Vector2.ZERO #set velocity to zero
	
	Anim.play("Idle") #play the idle animation (I also use it for the dash)
	PlayerSprite.modulate = Color.PURPLE #tint the player sprite purple

func dash_logic(delta):
	elapsedDashTime = Time.get_ticks_msec() - dashStartTime #set elapsed dash time
	
	velocity += Vector2(dashDirection.x*dashSpeed,dashDirection.y*dashSpeed) #add dash speed to velocity and multiply by dash direction
	
	if elapsedDashTime > dashDurration: 
		#if elapsed dash time is greater then the dash durration
		set_state(previousState) #go back to the previous state

func dash_exit_logic():
	velocity = Vector2.ZERO  #reset velocity to zero
	if !is_on_floor():
		canDash = false #limit the amount of air dashes someone can do
	
	PlayerSprite.modulate = Color.WHITE #untint the sprite


func jump_enter_logic():
	Anim.play("Jump") #play jump animation
	isJumping = true
	jumpHoldTime = 0.0

func jump_logic(delta):
	move_horizontally(airFriction)

	if velocity.y < 0:
		
		# si on est en montée
		if isJumping:
			print("enter")
			jumpHoldTime += delta
			print(jumpHoldTime)
			if jumpHoldTime > maxJumpHold:
				isJumping = false  # on arrête d'appliquer le "bonus de saut"
		
		if isJumpReleased:
			print("relese")
			isJumping = false  # relâchement stoppe immédiatement la montée
		
		# Applique gravité réduite si encore en saut
		#if isJumping:
		#	velocity.y += gravity * 0.7 * delta  # gravité plus faible
		#else:
		#	velocity.y += gravity * delta        # gravité normale

		# Double jump
		if isJumpPressed and not isDoubleJumped:
			jump(doubleJumpVelocity)
			set_state("double_jump")
		
		# Dash en l'air
		if isDashPressed and canDash:
			set_state("dash")
		
		# Si plafond touché
		if is_on_ceiling():
			set_state("fall")
	else:
		set_state("fall")

func jump_exit_logic():
	isJumping = false
	jumpHoldTime = 0.0


func double_jump_enter_logic():
	isDoubleJumped = true #make sure you can only double jump once
	
	Anim.play("Double Jump") #play double jump animation

func double_jump_logic(delta):
	move_horizontally(airFriction) #move horizontally and subtract airfriction from max speed
	
	if velocity.y < 0:
		#if you are rising
		if isJumpReleased:
			#and you release jump button lower velocity
			velocity.y /= 2
		
		if isDashPressed && canDash:
			#and you press dash button and you can dash
			set_state("dash") #dash
		
		if is_on_ceiling():
			#and you hit a ceiling 
			set_state("fall") #fall
	else:
		#if you are no longer rising
		set_state("fall") #fall

func double_jump_exit_logic():
	pass



func wall_slide_enter_logic():
	velocity = Vector2.ZERO #reset velocity to stop all momentum
	
	Anim.play("Wall Slide") #play wall slide animation

func wall_slide_logic(delta):
	velocity.y = wallSlideSpeed #override apply_gravity and apply a constant slide speed
	
	if LeftRaycast.is_colliding() && movementInput != -1 || RightRaycast.is_colliding() && movementInput != 1:
		#if your raycast is coliding and you are trying to move in that direction
		jumpBufferStartTime = Time.get_ticks_msec() #start jump buffer timer
		set_state("fall") #set state to fall
	#this could be done in one long if statement but I split it up to make it easiar to read
	if !LeftRaycast.is_colliding() && movementInput == -1 || !RightRaycast.is_colliding() && movementInput == 1:
		#if you are holding in a direction but no longer coliding with a wall in that direction
		set_state("fall")
	
	if is_on_floor():
		#if you hit the floor set state to idle
		jumpBufferStartTime = Time.get_ticks_msec() #start jump buffer timer
		set_state("idle")
		
	
	if isDashPressed:
		#dash if you press dash button
		set_state("dash")
	
	if isJumpPressed:
		jump(wallJumpVelocity) #jump with walljump y velocity
		set_state("wall_jump")

func wall_slide_exit_logic():
	isDoubleJumped = false #allow you to double jump again when you wall jump 

func wall_jump_enter_logic():
	currentSpeed = 0 #erase momentum form run
	
	Anim.play("Jump") #play jump animation

func wall_jump_logic(delta):
	move_horizontally(airFriction) #move horizontally
	
	#if you want to add a wall jump thrust you can do so by:
	#deifining a wallJumpThrust variable
	#and putting velocity.x += wallJumpThrust * lastDirection here
	
	if velocity.y < 0:
		#if you are rising
		if isJumpReleased:
			#and you release jump button lower velocity
			velocity.y /= 2
			
		if isJumpPressed && !isDoubleJumped:
			#doublejump if you press button and its your first timme double jumping
			#we use isJumpPressed here instead of jumpInput so we dont imeadiatly double jump when we originaly jump
			jump(doubleJumpVelocity) 
			set_state("double_jump")
		
		if isDashPressed:
			set_state("dash")
			
		if is_on_ceiling():
			#and you hit a ceiling fall
			set_state("fall")
	else:
		#if your not rising
		set_state("fall")

func wall_jump_exit_logic():
	canDash = true #allow the players to dash again if they wall jump


func _on_hit_box_area_entered(area: Area2D) -> void:
	if area.get_parent().has_method("enemy"):
		jump(doubleJumpVelocity)
