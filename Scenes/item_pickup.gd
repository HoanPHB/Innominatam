extends Interactable

@export var item_name: String = "Diamond Sword"
@export var amount: int = 1
@export var auto_pickup: bool = false  # Optional: auto pickup when touched

@onready var sprite = $Sprite2D

var player_in_range := false

func on_area_enter(area):
	if area.is_in_group("player_interact_zone"):
		player_in_range = true
		if auto_pickup:
			_collect_item(area.get_parent())

func on_area_exit(area):
	if area.is_in_group("player_interact_zone"):
		player_in_range = false

func interact():
	if player_in_range:
		_collect_item(get_tree().get_first_node_in_group("player"))

func _collect_item(player):
	print("Picked up:", item_name, "x", amount)
	SoundManager.play_sfx("Pick_up")
	InventoryManager.add_item(item_name, amount)
	$Sprite2D.visible = false
	_show_pickup_popup()

func _show_pickup_popup():
	var label = Label.new()
	label.text = "+%d %s" % [amount, item_name]
	
	var label_settings = LabelSettings.new()
	label_settings.font = load("res://fonts/PixelSerif_16px_v02.ttf")
	label_settings.font_size = 16
	label.label_settings = label_settings
	
	label.modulate = Color(1, 1, 1)
	get_parent().add_child(label)
	label.position = position - Vector2(label.get_size().x / 2, 16)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position - Vector2(0, 32), 1.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	label.queue_free()
	queue_free() # Remove from world after collecting
