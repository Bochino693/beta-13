class_name BattleAudioDirector
extends Node

## Audio exclusivo da batalha: ambiente, esquiva e voz individual das Beasts.

var _ambiente: AudioStreamPlayer
var _voz: AudioStreamPlayer
var _ativo := true


func _ready() -> void:
	_ambiente = AudioStreamPlayer.new()
	_ambiente.volume_db = -22.0
	add_child(_ambiente)
	var ambiente_path := "res://assets/audio/stadium_ambience.wav"
	if ResourceLoader.exists(ambiente_path):
		_ambiente.stream = load(ambiente_path) as AudioStream
		_ambiente.finished.connect(_reiniciar_ambiente)
		_ambiente.play()
	_voz = AudioStreamPlayer.new()
	_voz.volume_db = -5.0
	add_child(_voz)


func rugir(id_beast: String) -> void:
	if _voz == null or not GameState.sound_enabled:
		return
	_tocar_voz("res://assets/audio/beasts/%s_roar.wav" % id_beast)


func esquivar() -> void:
	if _voz == null or not GameState.sound_enabled:
		return
	_tocar_voz("res://assets/audio/dodge.wav")


func parar() -> void:
	_ativo = false
	if _ambiente != null:
		_ambiente.stop()


func _tocar_voz(caminho: String) -> void:
	if not ResourceLoader.exists(caminho):
		return
	_voz.stop()
	_voz.stream = load(caminho) as AudioStream
	_voz.pitch_scale = 1.0
	_voz.play()


func _reiniciar_ambiente() -> void:
	if _ambiente != null and _ativo:
		_ambiente.play()
