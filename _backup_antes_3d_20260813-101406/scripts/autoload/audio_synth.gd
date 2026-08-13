extends Node

const MUSIC_PATHS := {
	"intro": "res://assets/audio/intro_theme.wav",
	"menu": "res://assets/audio/menu_loop.wav",
	"battle": "res://assets/audio/battle_loop.wav",
	"victory": "res://assets/audio/victory_theme.wav"
}

const SFX_PATHS := {
	"move": "res://assets/audio/ui_move.wav",
	"confirm": "res://assets/audio/confirm.wav",
	"cancel": "res://assets/audio/cancel.wav",
	"coin": "res://assets/audio/coin.wav",
	"hit": "res://assets/audio/hit.wav",
	"special": "res://assets/audio/special.wav",
	"guard": "res://assets/audio/guard.wav",
	"knockout": "res://assets/audio/knockout.wav",
	"victory": "res://assets/audio/victory.wav"
}

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _music_theme := ""


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -10.0
	_music_player.finished.connect(_restart_music)
	add_child(_music_player)
	for _index in 8:
		var player := AudioStreamPlayer.new()
		player.volume_db = -4.0
		add_child(player)
		_sfx_players.append(player)


func start_music(theme: String) -> void:
	if not MUSIC_PATHS.has(theme):
		push_warning("Tema de música inexistente: %s" % theme)
		return
	if _music_theme == theme and _music_player.playing:
		return
	_music_theme = theme
	_play_current_music()


func stop_music() -> void:
	_music_theme = ""
	_music_player.stop()


func set_enabled(enabled: bool) -> void:
	if not enabled:
		_music_player.stop()
		for player in _sfx_players:
			player.stop()
	elif not _music_theme.is_empty():
		_play_current_music()


func ui_move() -> void:
	_play_sfx("move")


func ui_confirm() -> void:
	_play_sfx("confirm")


func ui_cancel() -> void:
	_play_sfx("cancel")


func coin() -> void:
	_play_sfx("coin")


func hit(power: float = 1.0) -> void:
	_play_sfx("hit", clampf(0.88 + power * 0.12, 0.9, 1.08), linear_to_db(clampf(power, 0.65, 1.25)))


func special_hit() -> void:
	_play_sfx("special")


func guard() -> void:
	_play_sfx("guard")


func knockout() -> void:
	_play_sfx("knockout")


func victory() -> void:
	_play_sfx("victory")


func _play_current_music() -> void:
	if not GameState.sound_enabled or _music_theme.is_empty():
		return
	var path: String = MUSIC_PATHS[_music_theme]
	if not ResourceLoader.exists(path):
		push_error("Música não encontrada: %s" % path)
		return
	_music_player.stream = load(path) as AudioStream
	_music_player.play()


func _restart_music() -> void:
	if not _music_theme.is_empty() and GameState.sound_enabled:
		_music_player.play()


func _play_sfx(effect_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not GameState.sound_enabled or not SFX_PATHS.has(effect_name) or _sfx_players.is_empty():
		return
	var path: String = SFX_PATHS[effect_name]
	if not ResourceLoader.exists(path):
		push_error("Efeito de áudio não encontrado: %s" % path)
		return
	var player := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stop()
	player.stream = load(path) as AudioStream
	player.pitch_scale = pitch
	player.volume_db = -4.0 + volume_db
	player.play()
