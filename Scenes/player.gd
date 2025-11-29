class_name Player extends CharacterBody2D

var cardinal_direction : Vector2 = Vector2.DOWN
var direction : Vector2 = Vector2.ZERO
var interact_target: Interactable = null
var can_interact: bool = true

@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var sprite : Sprite2D = $Sprite2D
@onready var state_machine : PlayerStateMachine = $StateMachine
@onready var interaction_cooldown: Timer = Timer.new()

func _on_area_entered(area):
	if area is Interactable:
		interact_target = area


func _on_area_exited(area):
	if area == interact_target:
		interact_target = null

func _ready():
	$InteractArea.connect("area_entered", _on_area_entered)
	$InteractArea.connect("area_exited", _on_area_exited)
	DialogManager.dialog_finished.connect(_on_dialog_finished)
	InventoryUI.menu_closed.connect(_on_menu_closed)
	EquipmentMenu.menu_closed.connect(_on_menu_closed)
	interaction_cooldown.one_shot = true
	interaction_cooldown.wait_time = 0.2
	interaction_cooldown.timeout.connect(func(): can_interact = true)
	add_child(interaction_cooldown)
	state_machine.Initialize(self)
	add_to_group("player")

func _on_dialog_finished():
	can_interact = false
	interaction_cooldown.start()

func _on_menu_closed():
	can_interact = false
	interaction_cooldown.start()

func _process(delta):
	if DialogManager.dialog_active or InventoryUI.menu_active or EquipmentMenu.menu_active or UIManager.quest_log_active:
		direction = Vector2.ZERO
		velocity = Vector2.ZERO
		UpdateAnimation("idle")
		return
	#direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	#direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	direction = Vector2(
		Input.get_axis("left","right"),
		Input.get_axis("up","down")
	).normalized()
	# Check for interaction
	if Input.is_action_just_pressed("interact") and interact_target and can_interact:
		interact_target.interact()
	pass

func _physics_process(delta):
	move_and_slide()

func SetDirection() -> bool:
	var new_dir : Vector2 = cardinal_direction
	if direction == Vector2.ZERO:
		return false
	
	if direction.y == 0:
		new_dir = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
	elif direction.x == 0:
		new_dir = Vector2.UP if direction.y < 0 else Vector2.DOWN
	
	if new_dir == cardinal_direction:
		return false
		
	cardinal_direction = new_dir
	sprite.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	return true
	
func UpdateAnimation(state : String) -> void:
	animation_player.play( state + "_" + AnimDirection())
	pass

func AnimDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return "side"
