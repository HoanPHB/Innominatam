# SoundManager.gd
extends Node

var _sfx_streams: Dictionary = {} # Stores sound streams by name
var _player_pool: Array = [] # Stores generic AudioStreamPlayer nodes

func _ready() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			if child.stream:
				_sfx_streams[child.name] = child.stream # Store the stream resource
				_player_pool.append(child) # Add to the pool of players
				child.stream = null # Clear the stream from the original player
			else:
				# If no stream is set, treat it as a generic player for the pool
				_player_pool.append(child)
			child.stop()
		else:
			push_warning("Child node '%s' is not an AudioStreamPlayer or AudioStreamPlayer2D. Only audio player nodes are managed by SoundManager." % child.name)

func play_sfx(sfx_name: String) -> void:
	if _sfx_streams.has(sfx_name):
		var stream_to_play: AudioStream = _sfx_streams[sfx_name]
		var available_player = _get_available_player()

		if available_player:
			available_player.stream = stream_to_play
			available_player.play()
		else:
			push_warning("No available AudioStreamPlayer in the pool to play '%s'. Consider adding more players to SoundManager." % sfx_name)
	else:
		push_error("Sound effect '%s' not found in SoundManager. Make sure an audio player node with this name and a stream exists as a child." % sfx_name)

func _get_available_player() -> AudioStreamPlayer2D:
	for player in _player_pool:
		if not player.playing:
			return player
	return null
