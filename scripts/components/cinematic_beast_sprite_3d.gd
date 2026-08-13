class_name CinematicBeastSprite3D
extends Node3D

## Beast animada por quadros-chave dentro do mundo 3D.
##
## Atlas 4x4:
##   0..7  = costas (jogador)
##   8..15 = frente (oponente)
## Em cada vista: repouso A/B, carga, ataque, dano, esquiva, vitoria e KO.
## Duas AnimatedSprite3D fazem crossfade entre poses; tweens de posicao,
## rotacao e escala completam a continuidade do movimento.

signal animacao_terminou(nome: String)

const ATLAS_COLUNAS := 4
const ATLAS_LINHAS := 4
const QUADROS_POR_VISTA := 8

const POSE_REPOUSO_A := 0
const POSE_REPOUSO_B := 1
const POSE_CARGA := 2
const POSE_ATAQUE := 3
const POSE_DANO := 4
const POSE_ESQUIVA := 5
const POSE_VITORIA := 6
const POSE_KO := 7

const PERFIS: Dictionary = {
	"ave": {"idle": 0.42, "flutua": 0.075, "ataque": 0.95, "esquiva": 1.10, "ritmo": 3.6, "respira": 0.024, "balanco": 2.5},
	"dragao": {"idle": 0.68, "flutua": 0.036, "ataque": 0.86, "esquiva": 0.88, "ritmo": 2.2, "respira": 0.032, "balanco": 1.6},
	"felpudo": {"idle": 0.82, "flutua": 0.014, "ataque": 0.78, "esquiva": 0.80, "ritmo": 1.7, "respira": 0.042, "balanco": 1.2},
	"reptil": {"idle": 0.88, "flutua": 0.007, "ataque": 0.82, "esquiva": 0.74, "ritmo": 1.45, "respira": 0.027, "balanco": 0.8},
	"planta": {"idle": 1.00, "flutua": 0.012, "ataque": 0.70, "esquiva": 0.62, "ritmo": 1.15, "respira": 0.038, "balanco": 1.8},
	"mineral": {"idle": 1.15, "flutua": 0.004, "ataque": 0.64, "esquiva": 0.55, "ritmo": 0.85, "respira": 0.014, "balanco": 0.35},
	"aquatico": {"idle": 0.62, "flutua": 0.086, "ataque": 0.88, "esquiva": 0.96, "ritmo": 2.0, "respira": 0.032, "balanco": 2.0},
	"espectro": {"idle": 0.48, "flutua": 0.105, "ataque": 1.00, "esquiva": 1.12, "ritmo": 2.7, "respira": 0.048, "balanco": 2.8},
	"padrao": {"idle": 0.75, "flutua": 0.022, "ataque": 0.80, "esquiva": 0.80, "ritmo": 1.7, "respira": 0.030, "balanco": 1.1},
}

const FAMILIA_POR_ID: Dictionary = {
	"lumari": "espectro", "helionce": "felpudo", "prismara": "ave",
	"impavor": "espectro", "nocturna": "espectro", "abissarca": "dragao",
	"brasalam": "reptil", "vulcora": "mineral", "cinzibora": "espectro",
	"pyrocondor": "ave", "voltalho": "felpudo", "raiarraia": "aquatico",
	"teslouro": "mineral", "arcdrake": "dragao", "pedrilho": "felpudo",
	"geodrilo": "reptil", "monolito": "mineral", "fossatroz": "reptil",
	"medulux": "aquatico", "crustarka": "aquatico", "torpescama": "aquatico",
	"marevante": "dragao", "floraphex": "ave", "brotoxi": "planta",
	"musgurso": "felpudo", "arborion": "planta", "brispulo": "felpudo",
	"nimbaleia": "aquatico", "ciclorn": "ave", "tempestral": "dragao",
}

var _sprite_ativo: AnimatedSprite3D
var _sprite_reserva: AnimatedSprite3D
var _quadros: SpriteFrames
var _perfil: Dictionary = PERFIS["padrao"]
var _tween_ativo: Tween
var _tween_crossfade: Tween
var _origem := Vector3.ZERO
var _escala_base := Vector3.ONE
var _altura_mundo := 2.0
var _cor_elemento := Color("6ef8ff")
var _de_costas := false
var _ocupado := false
var _tempo := 0.0
var _tempo_idle := 0.0
var _pose_idle := POSE_REPOUSO_A
var _offset_vista := 0
var _sombra: MeshInstance3D
var _anel_interno: MeshInstance3D
var _anel_externo: MeshInstance3D
var _material_anel_interno: StandardMaterial3D
var _material_anel_externo: StandardMaterial3D
var _luz_presenca: OmniLight3D
var _impulso_presenca := 1.0


func _ready() -> void:
	set_process(true)


static func familia_de(dados: Dictionary) -> String:
	var explicita: String = str(dados.get("familia_anim", ""))
	if PERFIS.has(explicita):
		return explicita
	var id_beast: String = str(dados.get("id", ""))
	return str(FAMILIA_POR_ID.get(id_beast, "padrao"))


func configurar(
	id_beast: String,
	altura_mundo: float,
	familia: String,
	de_costas: bool,
	cor_elemento: Color
) -> bool:
	var caminho := "res://assets/sprites_combat/%s.png" % id_beast
	if not ResourceLoader.exists(caminho):
		push_error("CinematicBeastSprite3D: atlas ausente: " + caminho)
		return false
	var textura: Texture2D = load(caminho) as Texture2D
	if textura == null:
		push_error("CinematicBeastSprite3D: atlas invalido: " + caminho)
		return false

	_de_costas = de_costas
	_altura_mundo = altura_mundo
	_offset_vista = 0 if de_costas else QUADROS_POR_VISTA
	_cor_elemento = cor_elemento
	_perfil = PERFIS.get(familia, PERFIS["padrao"]) as Dictionary
	_quadros = _construir_quadros(textura)

	_sprite_ativo = _criar_sprite(altura_mundo, textura)
	_sprite_reserva = _criar_sprite(altura_mundo, textura)
	_sprite_reserva.modulate.a = 0.0
	add_child(_sprite_ativo)
	add_child(_sprite_reserva)
	_definir_pose_imediata(POSE_REPOUSO_A)

	# O centro do plano fica acima da origem, mantendo a base no piso.
	var altura_celula := textura.get_height() / float(ATLAS_LINHAS)
	var pixel_size := altura_mundo / maxf(1.0, altura_celula)
	_sprite_ativo.pixel_size = pixel_size
	_sprite_reserva.pixel_size = pixel_size
	_sprite_ativo.position.y = altura_mundo * 0.5
	_sprite_reserva.position.y = altura_mundo * 0.5
	_criar_presenca_3d(altura_mundo)
	_origem = position
	_escala_base = scale
	_tempo_idle = randf_range(0.05, float(_perfil["idle"]))
	return true


func _construir_quadros(textura: Texture2D) -> SpriteFrames:
	var recurso := SpriteFrames.new()
	if recurso.has_animation("default"):
		recurso.remove_animation("default")
	var largura := textura.get_width() / float(ATLAS_COLUNAS)
	var altura := textura.get_height() / float(ATLAS_LINHAS)
	for indice in range(ATLAS_COLUNAS * ATLAS_LINHAS):
		var animacao := "pose_%02d" % indice
		recurso.add_animation(animacao)
		recurso.set_animation_loop(animacao, false)
		recurso.set_animation_speed(animacao, 1.0)
		var atlas := AtlasTexture.new()
		atlas.atlas = textura
		atlas.region = Rect2(
			float(indice % ATLAS_COLUNAS) * largura,
			float(indice / ATLAS_COLUNAS) * altura,
			largura,
			altura
		)
		atlas.filter_clip = true
		recurso.add_frame(animacao, atlas)
	return recurso


func _criar_sprite(_altura_mundo: float, _textura: Texture2D) -> AnimatedSprite3D:
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = _quadros
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.no_depth_test = false
	sprite.render_priority = 4
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	sprite.modulate = Color.WHITE
	return sprite


func _process(delta: float) -> void:
	_tempo += delta
	if _sprite_ativo == null:
		return
	if not _ocupado:
		var flutuacao := float(_perfil["flutua"])
		var ritmo := float(_perfil["ritmo"])
		var respira := float(_perfil["respira"])
		var balanco := float(_perfil["balanco"])
		var pulso := sin(_tempo * ritmo)
		var deslocamento := pulso * flutuacao
		var atual := _sprite_ativo.position.y - _altura_visual()
		_sprite_ativo.position.y += (deslocamento - atual) * minf(1.0, delta * 4.0)
		_sprite_reserva.position.y = _sprite_ativo.position.y
		var escala_x := 1.0 - pulso * respira * 0.52
		var escala_y := 1.0 + pulso * respira
		var escala_viva := Vector3(escala_x, escala_y, 1.0)
		_sprite_ativo.scale = _sprite_ativo.scale.lerp(escala_viva, minf(1.0, delta * 5.5))
		_sprite_reserva.scale = _sprite_ativo.scale
		_sprite_ativo.rotation_degrees.z = sin(_tempo * ritmo * 0.58) * balanco
		_sprite_reserva.rotation_degrees.z = _sprite_ativo.rotation_degrees.z
		_tempo_idle -= delta
		if _tempo_idle <= 0.0:
			_pose_idle = POSE_REPOUSO_B if _pose_idle == POSE_REPOUSO_A else POSE_REPOUSO_A
			_crossfade(_pose_idle, 0.18)
			_tempo_idle = float(_perfil["idle"])
	_atualizar_presenca()


func _criar_presenca_3d(altura: float) -> void:
	_sombra = MeshInstance3D.new()
	var malha_sombra := PlaneMesh.new()
	malha_sombra.size = Vector2(altura * 0.72, altura * 0.25)
	_sombra.mesh = malha_sombra
	_sombra.position = Vector3(0.0, 0.018, 0.0)
	var material_sombra := StandardMaterial3D.new()
	material_sombra.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_sombra.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_sombra.albedo_color = Color(0.0, 0.0, 0.0, 0.38)
	material_sombra.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
	_sombra.material_override = material_sombra
	add_child(_sombra)

	_anel_externo = _criar_anel(altura * 0.40, altura * 0.018, 0.16)
	_material_anel_externo = _anel_externo.material_override as StandardMaterial3D
	_anel_externo.position.y = 0.026
	add_child(_anel_externo)
	_anel_interno = _criar_anel(altura * 0.28, altura * 0.010, 0.30)
	_material_anel_interno = _anel_interno.material_override as StandardMaterial3D
	_anel_interno.position.y = 0.032
	add_child(_anel_interno)

	_luz_presenca = OmniLight3D.new()
	_luz_presenca.omni_range = maxf(2.0, altura * 1.6)
	_luz_presenca.light_color = _cor_elemento
	_luz_presenca.light_energy = 0.42
	_luz_presenca.shadow_enabled = false
	_luz_presenca.position.y = altura * 0.52
	add_child(_luz_presenca)


func _criar_anel(raio: float, espessura: float, alpha: float) -> MeshInstance3D:
	var instancia := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = maxf(0.03, raio - espessura)
	toro.outer_radius = raio
	toro.rings = 32
	toro.ring_segments = 6
	instancia.mesh = toro
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(_cor_elemento.r, _cor_elemento.g, _cor_elemento.b, alpha)
	material.emission_enabled = true
	material.emission = _cor_elemento
	material.emission_energy_multiplier = 1.4
	instancia.material_override = material
	return instancia


func _atualizar_presenca() -> void:
	if _anel_externo == null:
		return
	var pulso := 0.5 + sin(_tempo * 2.2) * 0.5
	_impulso_presenca = move_toward(_impulso_presenca, 1.0, get_process_delta_time() * 4.2)
	_anel_externo.rotation.y = _tempo * 0.34
	_anel_interno.rotation.y = -_tempo * 0.58
	_material_anel_externo.emission_energy_multiplier = (0.65 + pulso * 1.25) * _impulso_presenca
	_material_anel_interno.emission_energy_multiplier = (0.95 + pulso * 1.65) * _impulso_presenca
	_luz_presenca.light_energy = (0.28 + pulso * 0.22) * _impulso_presenca
	var alpha_sombra := 0.34 - absf(sin(_tempo * float(_perfil["ritmo"]))) * 0.08
	var material_sombra := _sombra.material_override as StandardMaterial3D
	material_sombra.albedo_color.a = alpha_sombra


func _definir_intensidade_presenca(valor: float) -> void:
	if _material_anel_externo == null:
		return
	_impulso_presenca = maxf(1.0, valor)


func _altura_visual() -> float:
	if _sprite_ativo == null or _sprite_ativo.sprite_frames == null:
		return 1.0
	var textura: Texture2D = _sprite_ativo.sprite_frames.get_frame_texture("pose_00", 0)
	return textura.get_height() * _sprite_ativo.pixel_size * 0.5


func _nome_pose(pose: int) -> String:
	return "pose_%02d" % (_offset_vista + pose)


func _definir_pose_imediata(pose: int) -> void:
	var animacao := _nome_pose(pose)
	_sprite_ativo.play(animacao)
	_sprite_reserva.play(animacao)
	_sprite_ativo.modulate.a = 1.0
	_sprite_reserva.modulate.a = 0.0


func _crossfade(pose: int, duracao: float = 0.12) -> void:
	if _sprite_ativo == null or _sprite_reserva == null:
		return
	_sprite_reserva.play(_nome_pose(pose))
	_sprite_reserva.modulate = _sprite_ativo.modulate
	_sprite_reserva.modulate.a = 0.0
	_sprite_reserva.position = _sprite_ativo.position
	_sprite_reserva.scale = _sprite_ativo.scale
	var anterior := _sprite_ativo
	var proximo := _sprite_reserva
	if _tween_crossfade != null and _tween_crossfade.is_valid():
		_tween_crossfade.kill()
	_tween_crossfade = create_tween()
	_tween_crossfade.set_parallel(true).set_trans(Tween.TRANS_SINE)
	_tween_crossfade.tween_property(anterior, "modulate:a", 0.0, duracao)
	_tween_crossfade.tween_property(proximo, "modulate:a", 1.0, duracao)
	_tween_crossfade.chain().tween_callback(_concluir_crossfade.bind(anterior, proximo))


func _concluir_crossfade(anterior: AnimatedSprite3D, proximo: AnimatedSprite3D) -> void:
	if not is_instance_valid(anterior) or not is_instance_valid(proximo):
		return
	_sprite_ativo = proximo
	_sprite_reserva = anterior
	_sprite_reserva.modulate.a = 0.0


func _novo_tween() -> Tween:
	if _tween_ativo != null and _tween_ativo.is_valid():
		_tween_ativo.kill()
	_tween_ativo = create_tween()
	_tween_ativo.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return _tween_ativo


func definir_cor_elemento(cor: Color) -> void:
	_cor_elemento = cor


func definir_contraluz(_valor: float) -> void:
	# Compatibilidade com o rig anterior. A arte de costas agora e real.
	pass


func repousar() -> void:
	_ocupado = false
	position = _origem
	rotation = Vector3.ZERO
	scale = _escala_base
	_sprite_ativo.modulate = Color.WHITE
	_sprite_ativo.scale = Vector3.ONE
	_sprite_reserva.scale = Vector3.ONE
	_sprite_ativo.rotation_degrees.z = 0.0
	_sprite_reserva.rotation_degrees.z = 0.0
	_definir_intensidade_presenca(1.0)
	_crossfade(POSE_REPOUSO_A, 0.16)


func entrar(duracao: float = 0.70) -> void:
	_ocupado = true
	_definir_pose_imediata(POSE_REPOUSO_A)
	scale = _escala_base * 0.68
	_sprite_ativo.modulate.a = 0.0
	var tween := _novo_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", _escala_base, duracao).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_sprite_ativo, "modulate:a", 1.0, duracao * 0.72)
	tween.chain().tween_callback(_finalizar_estado.bind("entrar"))


func carregar(duracao: float = 0.85) -> void:
	_ocupado = true
	_definir_intensidade_presenca(4.6)
	_crossfade(POSE_CARGA, 0.14)
	var tween := _novo_tween()
	tween.tween_property(self, "scale", Vector3(1.08, 0.88, 1.08), duracao * 0.58)
	var inclinacao := -3.0 if _de_costas else 3.0
	tween.parallel().tween_property(
		self, "rotation_degrees:z", inclinacao, duracao * 0.58
	)
	tween.tween_property(self, "scale", _escala_base, duracao * 0.30).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(self, "rotation_degrees:z", 0.0, duracao * 0.30)
	tween.tween_callback(_finalizar_estado.bind("carregar", false))


func atacar(pesado: bool = false, duracao: float = 0.62) -> void:
	_ocupado = true
	var multiplicador := float(_perfil["ataque"])
	var tempo_total := duracao / maxf(0.35, multiplicador)
	var direcao_z := -1.0 if _de_costas else 1.0
	var inicio := position
	# Golpes leves não passam pela pose de carga. Isso dá resposta imediata e
	# reserva a antecipação longa, aura e leitura de peso para o golpe pesado.
	if not pesado:
		_crossfade(POSE_ATAQUE, 0.055)
	var tween := _novo_tween()
	var antecipacao := 0.24 if pesado else 0.11
	tween.tween_property(self, "position:z", inicio.z - direcao_z * (0.16 if pesado else 0.07), tempo_total * antecipacao)
	tween.parallel().tween_property(
		self,
		"scale",
		Vector3(1.08, 0.91, 1.0) if pesado else Vector3(1.035, 0.97, 1.0),
		tempo_total * antecipacao
	)
	if pesado:
		tween.tween_callback(_crossfade.bind(POSE_ATAQUE, 0.075))
	tween.tween_property(
		self,
		"position:z",
		inicio.z + direcao_z * (1.02 if pesado else 0.64),
		tempo_total * (0.20 if pesado else 0.17)
	).set_trans(Tween.TRANS_EXPO)
	tween.parallel().tween_property(
		self,
		"scale",
		Vector3(0.95, 1.10, 1.0) if pesado else Vector3(0.98, 1.055, 1.0),
		tempo_total * (0.20 if pesado else 0.17)
	)
	tween.tween_callback(_emitir_impacto)
	tween.tween_interval(tempo_total * (0.12 if pesado else 0.06))
	tween.tween_property(self, "position", inicio, tempo_total * (0.36 if pesado else 0.30))
	tween.parallel().tween_property(self, "scale", _escala_base, tempo_total * (0.36 if pesado else 0.30))
	tween.tween_callback(_finalizar_estado.bind("atacar"))


func _emitir_impacto() -> void:
	for atraso in range(3):
		_criar_rastro(float(atraso) * 0.045)
	_definir_intensidade_presenca(5.8)
	animacao_terminou.emit("impacto")


func levar_dano(cor: Color = Color(1.0, 0.35, 0.35), duracao: float = 0.42) -> void:
	_ocupado = true
	_definir_intensidade_presenca(3.2)
	_crossfade(POSE_DANO, 0.055)
	var inicio := position
	var tween := _novo_tween()
	for indice in range(5):
		var sinal := -1.0 if indice % 2 == 0 else 1.0
		tween.tween_property(self, "position:x", inicio.x + sinal * 0.14, duracao * 0.10)
		tween.parallel().tween_property(_sprite_ativo, "modulate", cor.lightened(0.55), duracao * 0.08)
	tween.tween_property(self, "position", inicio, duracao * 0.30)
	tween.parallel().tween_property(_sprite_ativo, "modulate", Color.WHITE, duracao * 0.30)
	tween.tween_callback(_finalizar_estado.bind("dano"))


func esquivar(direcao: int, duracao: float = 0.38) -> void:
	_ocupado = true
	_crossfade(POSE_ESQUIVA, 0.045)
	var inicio_x := position.x
	var destino_x := inicio_x + float(signi(direcao)) * 0.72
	var velocidade := float(_perfil["esquiva"])
	var tween := _novo_tween()
	tween.tween_callback(_gerar_rastros_esquiva.bind(signi(direcao)))
	tween.tween_property(
		self, "position:x", destino_x, duracao / maxf(0.4, velocidade)
	).set_trans(Tween.TRANS_EXPO)
	tween.parallel().tween_property(
		self, "rotation_degrees:z", -9.0 * float(signi(direcao)), duracao * 0.50
	)
	tween.parallel().tween_property(
		self, "scale", Vector3(0.93, 1.04, 1.0), duracao * 0.44
	)
	tween.tween_callback(_crossfade.bind(POSE_REPOUSO_A, 0.075))
	tween.tween_property(self, "rotation_degrees:z", 0.0, duracao * 0.22)
	tween.parallel().tween_property(self, "scale", _escala_base, duracao * 0.22)
	tween.tween_callback(_fixar_nova_origem.bind(destino_x))


func _fixar_nova_origem(novo_x: float) -> void:
	position.x = novo_x
	_origem.x = novo_x
	_finalizar_estado("esquiva")


func comemorar(duracao: float = 1.05) -> void:
	_ocupado = true
	_crossfade(POSE_VITORIA, 0.14)
	var inicio_y := position.y
	var tween := _novo_tween()
	tween.tween_property(
		self, "position:y", inicio_y + 0.20, duracao * 0.35
	).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", inicio_y, duracao * 0.30)
	tween.tween_interval(duracao * 0.20)
	tween.tween_callback(_finalizar_estado.bind("comemorar"))


func tombar(duracao: float = 0.95) -> void:
	_ocupado = true
	_crossfade(POSE_KO, 0.16)
	var tween := _novo_tween()
	tween.tween_interval(duracao * 0.55)
	tween.tween_property(_sprite_ativo, "modulate:a", 0.0, duracao * 0.45)
	tween.parallel().tween_property(self, "position:y", position.y - 0.12, duracao * 0.45)
	tween.tween_callback(_finalizar_estado.bind("tombar", false))


func _criar_rastro(atraso: float = 0.0) -> void:
	if _sprite_ativo == null:
		return
	var fantasma := AnimatedSprite3D.new()
	fantasma.sprite_frames = _quadros
	fantasma.play(_nome_pose(POSE_ATAQUE))
	fantasma.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fantasma.shaded = false
	fantasma.transparent = true
	fantasma.no_depth_test = true
	fantasma.pixel_size = _sprite_ativo.pixel_size
	fantasma.position = _sprite_ativo.position
	fantasma.position.z += atraso * (-2.2 if _de_costas else 2.2)
	fantasma.modulate = Color(_cor_elemento.r, _cor_elemento.g, _cor_elemento.b, 0.34)
	add_child(fantasma)
	var tween := create_tween()
	if atraso > 0.0:
		tween.tween_interval(atraso)
	tween.set_parallel(true)
	tween.tween_property(fantasma, "modulate:a", 0.0, 0.24)
	tween.tween_property(fantasma, "scale", Vector3(1.14, 1.14, 1.14), 0.24)
	tween.chain().tween_callback(fantasma.queue_free)


func _criar_rastro_esquiva(atraso: float, direcao: int) -> void:
	if _sprite_ativo == null:
		return
	var fantasma := AnimatedSprite3D.new()
	fantasma.sprite_frames = _quadros
	fantasma.play(_nome_pose(POSE_ESQUIVA))
	fantasma.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fantasma.shaded = false
	fantasma.transparent = true
	fantasma.no_depth_test = true
	fantasma.render_priority = 3
	fantasma.pixel_size = _sprite_ativo.pixel_size
	fantasma.position = _sprite_ativo.position
	fantasma.position.x -= float(direcao) * atraso * 5.0
	fantasma.modulate = Color(_cor_elemento.r, _cor_elemento.g, _cor_elemento.b, 0.27)
	add_child(fantasma)
	var tween := create_tween()
	if atraso > 0.0:
		tween.tween_interval(atraso)
	tween.set_parallel(true)
	tween.tween_property(fantasma, "modulate:a", 0.0, 0.20)
	tween.tween_property(fantasma, "position:x", fantasma.position.x - float(direcao) * 0.18, 0.20)
	tween.chain().tween_callback(fantasma.queue_free)


func _gerar_rastros_esquiva(direcao: int) -> void:
	for atraso in range(3):
		_criar_rastro_esquiva(float(atraso) * 0.035, direcao)


func _finalizar_estado(nome: String, voltar_ao_idle: bool = true) -> void:
	if voltar_ao_idle:
		_crossfade(POSE_REPOUSO_A, 0.16)
	_ocupado = false
	_definir_intensidade_presenca(1.0)
	animacao_terminou.emit(nome)
