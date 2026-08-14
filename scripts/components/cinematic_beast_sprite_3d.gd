class_name CinematicBeastSprite3D
extends Node3D

## Ator 2.5D V4: atlas 8x8 com sequencias temporais no mundo 3D.
## 0..31 = costas; 32..63 = frente.

signal animacao_terminou(nome: String)

const ATLAS_COLUNAS := 8
const ATLAS_LINHAS := 8
const QUADROS_POR_VISTA := 32

const SEQUENCIAS: Dictionary = {
	"idle": {"inicio": 0, "quantidade": 8, "fps": 9.0, "loop": true},
	"light": {"inicio": 8, "quantidade": 4, "fps": 15.0, "loop": false},
	"heavy_charge": {"inicio": 12, "quantidade": 3, "fps": 9.0, "loop": false},
	"heavy_release": {"inicio": 15, "quantidade": 3, "fps": 13.0, "loop": false},
	"damage": {"inicio": 18, "quantidade": 3, "fps": 14.0, "loop": false},
	"dodge_left": {"inicio": 21, "quantidade": 3, "fps": 16.0, "loop": false},
	"dodge_right": {"inicio": 24, "quantidade": 3, "fps": 16.0, "loop": false},
	"victory": {"inicio": 27, "quantidade": 2, "fps": 6.0, "loop": true},
	"ko": {"inicio": 29, "quantidade": 2, "fps": 5.0, "loop": false},
	"guard": {"inicio": 31, "quantidade": 1, "fps": 1.0, "loop": true},
}

const PERFIS: Dictionary = {
	"ave": {"idle_speed": 1.38, "flutua": 0.090, "ritmo": 3.8, "roll": 1.25, "ataque": 1.10, "esquiva": 1.18},
	"dragao": {"idle_speed": 0.96, "flutua": 0.042, "ritmo": 2.3, "roll": 0.72, "ataque": 1.00, "esquiva": 0.96},
	"felpudo": {"idle_speed": 0.82, "flutua": 0.020, "ritmo": 1.8, "roll": 0.48, "ataque": 0.92, "esquiva": 0.88},
	"reptil": {"idle_speed": 0.74, "flutua": 0.010, "ritmo": 1.5, "roll": 0.28, "ataque": 0.96, "esquiva": 0.84},
	"planta": {"idle_speed": 0.68, "flutua": 0.014, "ritmo": 1.2, "roll": 0.62, "ataque": 0.84, "esquiva": 0.76},
	"mineral": {"idle_speed": 0.56, "flutua": 0.006, "ritmo": 0.9, "roll": 0.15, "ataque": 0.78, "esquiva": 0.68},
	"aquatico": {"idle_speed": 1.12, "flutua": 0.096, "ritmo": 2.2, "roll": 1.02, "ataque": 1.04, "esquiva": 1.10},
	"espectro": {"idle_speed": 1.25, "flutua": 0.112, "ritmo": 2.8, "roll": 1.18, "ataque": 1.12, "esquiva": 1.20},
	"padrao": {"idle_speed": 0.88, "flutua": 0.028, "ritmo": 1.8, "roll": 0.42, "ataque": 0.94, "esquiva": 0.90},
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

const CODIGO_SOMBRA := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never;
uniform float alpha = 0.36;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 2.55);
	float mask = 1.0 - smoothstep(0.15, 0.50, length(p));
	ALBEDO = vec3(0.003, 0.005, 0.016);
	ALPHA = mask * alpha;
}
"""

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
var _ataque_pesado_pendente := false
var _sombra: MeshInstance3D
var _material_sombra: ShaderMaterial
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
	return str(FAMILIA_POR_ID.get(str(dados.get("id", "")), "padrao"))


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
	if textura == null or textura.get_width() != 3072 or textura.get_height() != 3072:
		push_error("CinematicBeastSprite3D: atlas V4 invalido: " + caminho)
		return false

	_de_costas = de_costas
	_altura_mundo = altura_mundo
	_cor_elemento = cor_elemento
	_perfil = PERFIS.get(familia, PERFIS["padrao"]) as Dictionary
	_quadros = _construir_quadros(textura, 0 if de_costas else QUADROS_POR_VISTA)
	_sprite_ativo = _criar_sprite()
	_sprite_reserva = _criar_sprite()
	_sprite_reserva.modulate.a = 0.0
	add_child(_sprite_ativo)
	add_child(_sprite_reserva)

	var altura_celula := textura.get_height() / float(ATLAS_LINHAS)
	var pixel_size := altura_mundo / maxf(1.0, altura_celula)
	for sprite in [_sprite_ativo, _sprite_reserva]:
		sprite.pixel_size = pixel_size
		sprite.position.y = altura_mundo * 0.5
	_sprite_ativo.play("idle")
	_sprite_reserva.play("idle")
	_criar_presenca_3d(altura_mundo)
	_origem = position
	_escala_base = scale
	return true


func _construir_quadros(textura: Texture2D, offset_vista: int) -> SpriteFrames:
	var recurso := SpriteFrames.new()
	if recurso.has_animation("default"):
		recurso.remove_animation("default")
	var largura := textura.get_width() / float(ATLAS_COLUNAS)
	var altura := textura.get_height() / float(ATLAS_LINHAS)
	for nome_variante in SEQUENCIAS.keys():
		var nome: String = str(nome_variante)
		var contrato: Dictionary = SEQUENCIAS[nome]
		recurso.add_animation(nome)
		recurso.set_animation_loop(nome, bool(contrato["loop"]))
		var fps := float(contrato["fps"])
		if nome == "idle":
			fps *= float(_perfil["idle_speed"])
		recurso.set_animation_speed(nome, fps)
		var inicio := int(contrato["inicio"])
		var quantidade := int(contrato["quantidade"])
		for local_index in range(inicio, inicio + quantidade):
			var indice: int = offset_vista + int(local_index)
			var atlas := AtlasTexture.new()
			atlas.atlas = textura
			atlas.region = Rect2(
				float(indice % ATLAS_COLUNAS) * largura,
				floorf(float(indice) / float(ATLAS_COLUNAS)) * altura,
				largura,
				altura
			)
			atlas.filter_clip = true
			recurso.add_frame(nome, atlas)
	return recurso


func _criar_sprite() -> AnimatedSprite3D:
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = _quadros
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.no_depth_test = false
	sprite.render_priority = 4
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.modulate = Color.WHITE
	return sprite


func _process(delta: float) -> void:
	_tempo += delta
	if _sprite_ativo == null:
		return
	if not _ocupado:
		var ritmo := float(_perfil["ritmo"])
		var pulso := sin(_tempo * ritmo)
		var alvo_y := _altura_mundo * 0.5 + pulso * float(_perfil["flutua"])
		_sprite_ativo.position.y = lerpf(_sprite_ativo.position.y, alvo_y, minf(1.0, delta * 5.0))
		_sprite_reserva.position.y = _sprite_ativo.position.y
		var respiracao := Vector3(1.0 - pulso * 0.003, 1.0 + pulso * 0.005, 1.0)
		_sprite_ativo.scale = _sprite_ativo.scale.lerp(respiracao, minf(1.0, delta * 5.5))
		_sprite_reserva.scale = _sprite_ativo.scale
		var roll := sin(_tempo * ritmo * 0.53) * float(_perfil["roll"])
		_sprite_ativo.rotation_degrees.z = roll
		_sprite_reserva.rotation_degrees.z = roll
	_atualizar_presenca(delta)


func _trocar_animacao(nome: String, duracao: float = 0.07) -> void:
	if _sprite_ativo == null or _sprite_reserva == null or not _quadros.has_animation(nome):
		return
	_sprite_reserva.play(nome)
	_sprite_reserva.frame = 0
	_sprite_reserva.position = _sprite_ativo.position
	_sprite_reserva.scale = _sprite_ativo.scale
	_sprite_reserva.rotation = _sprite_ativo.rotation
	_sprite_reserva.modulate = _sprite_ativo.modulate
	_sprite_reserva.modulate.a = 0.0
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
	_sprite_reserva.stop()
	_sprite_reserva.modulate.a = 0.0


func _novo_tween() -> Tween:
	if _tween_ativo != null and _tween_ativo.is_valid():
		_tween_ativo.kill()
	_tween_ativo = create_tween()
	_tween_ativo.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return _tween_ativo


func repousar() -> void:
	_ocupado = false
	_ataque_pesado_pendente = false
	position = _origem
	rotation = Vector3.ZERO
	scale = _escala_base
	for sprite in [_sprite_ativo, _sprite_reserva]:
		sprite.modulate = Color.WHITE
		sprite.scale = Vector3.ONE
		sprite.rotation = Vector3.ZERO
	_trocar_animacao("idle", 0.10)
	_definir_intensidade_presenca(1.0)


func entrar(duracao: float = 0.70) -> void:
	_ocupado = true
	_trocar_animacao("idle", 0.02)
	scale = _escala_base * 0.62
	_sprite_ativo.modulate.a = 0.0
	var tween := _novo_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", _escala_base, duracao).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_sprite_ativo, "modulate:a", 1.0, duracao * 0.68)
	tween.chain().tween_callback(_finalizar_estado.bind("entrar", true))


func carregar(duracao: float = 0.85) -> void:
	_ocupado = true
	_ataque_pesado_pendente = true
	_trocar_animacao("heavy_charge", 0.06)
	_definir_intensidade_presenca(4.8)
	var tween := _novo_tween()
	tween.tween_property(self, "scale", Vector3(1.07, 0.90, 1.05), duracao * 0.40)
	tween.parallel().tween_property(self, "position:y", _origem.y - 0.07, duracao * 0.40)
	tween.tween_property(self, "scale", Vector3(0.98, 1.06, 1.0), duracao * 0.34).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(self, "position:y", _origem.y + 0.04, duracao * 0.34)
	tween.tween_callback(_finalizar_estado.bind("carregar", false))


func atacar(duracao: float = 0.62) -> void:
	_ocupado = true
	var pesado := _ataque_pesado_pendente
	var total := duracao / maxf(0.45, float(_perfil["ataque"]))
	var direcao_z := -1.0 if _de_costas else 1.0
	var inicio := _origem
	_trocar_animacao("heavy_release" if pesado else "light", 0.055)
	var tween := _novo_tween()
	tween.tween_property(self, "position:z", inicio.z - direcao_z * 0.18, total * 0.19)
	tween.parallel().tween_property(self, "scale", Vector3(1.06, 0.92, 1.0), total * 0.19)
	tween.tween_property(self, "position:z", inicio.z + direcao_z * (1.02 if pesado else 0.82), total * 0.22).set_trans(Tween.TRANS_EXPO)
	tween.parallel().tween_property(self, "scale", Vector3(0.95, 1.08, 1.0), total * 0.22)
	tween.tween_callback(_emitir_impacto.bind(pesado))
	tween.tween_interval(total * (0.16 if pesado else 0.10))
	tween.tween_property(self, "position", inicio, total * 0.39).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(self, "scale", _escala_base, total * 0.39)
	tween.tween_callback(_finalizar_estado.bind("atacar", true))


func _emitir_impacto(pesado: bool) -> void:
	for indice in range(4 if pesado else 2):
		_criar_rastro(float(indice) * 0.035, 0.34 if pesado else 0.24)
	_definir_intensidade_presenca(6.2 if pesado else 4.1)
	animacao_terminou.emit("impacto")


func levar_dano(cor: Color = Color(1.0, 0.35, 0.35), duracao: float = 0.42) -> void:
	_ocupado = true
	_trocar_animacao("damage", 0.035)
	_definir_intensidade_presenca(3.5)
	var inicio := _origem
	var recuo_z := 0.17 if _de_costas else -0.17
	var tween := _novo_tween()
	tween.tween_property(self, "position:z", inicio.z + recuo_z, duracao * 0.22).set_trans(Tween.TRANS_EXPO)
	tween.parallel().tween_property(_sprite_ativo, "modulate", cor.lightened(0.48), duracao * 0.10)
	for indice in range(3):
		var sinal := -1.0 if indice % 2 == 0 else 1.0
		tween.tween_property(self, "position:x", inicio.x + sinal * 0.10, duracao * 0.10)
	tween.tween_property(self, "position", inicio, duracao * 0.30)
	tween.parallel().tween_property(_sprite_ativo, "modulate", Color.WHITE, duracao * 0.24)
	tween.tween_callback(_finalizar_estado.bind("dano", true))


func esquivar(direcao: int, duracao: float = 0.38) -> void:
	_ocupado = true
	var sinal := signi(direcao)
	_trocar_animacao("dodge_left" if sinal < 0 else "dodge_right", 0.035)
	var inicio_x := position.x
	var destino_x := inicio_x + float(sinal) * 0.72
	var tempo := duracao / maxf(0.45, float(_perfil["esquiva"]))
	_criar_rastro(0.0, 0.22)
	_criar_rastro(0.045, 0.16)
	var tween := _novo_tween()
	tween.tween_property(self, "position:x", inicio_x - float(sinal) * 0.08, tempo * 0.18)
	tween.tween_property(self, "position:x", destino_x, tempo * 0.47).set_trans(Tween.TRANS_EXPO)
	tween.parallel().tween_property(self, "rotation_degrees:z", -5.5 * float(sinal), tempo * 0.47)
	tween.tween_property(self, "rotation_degrees:z", 0.0, tempo * 0.24)
	tween.tween_callback(_fixar_nova_origem.bind(destino_x))


func _fixar_nova_origem(novo_x: float) -> void:
	position.x = novo_x
	_origem.x = novo_x
	_finalizar_estado("esquiva", true)


func comemorar(duracao: float = 1.05) -> void:
	_ocupado = true
	_trocar_animacao("victory", 0.09)
	var tween := _novo_tween()
	tween.tween_property(self, "position:y", _origem.y + 0.22, duracao * 0.28).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", _origem.y, duracao * 0.24)
	tween.tween_interval(duracao * 0.28)
	tween.tween_callback(_finalizar_estado.bind("comemorar", true))


func tombar(duracao: float = 0.95) -> void:
	_ocupado = true
	_trocar_animacao("ko", 0.10)
	var tween := _novo_tween()
	tween.tween_interval(duracao * 0.46)
	tween.tween_property(_sprite_ativo, "modulate:a", 0.0, duracao * 0.42)
	tween.parallel().tween_property(self, "position:y", _origem.y - 0.12, duracao * 0.42)
	tween.tween_callback(_finalizar_estado.bind("tombar", false))


func guardar(rodadas: int = 1) -> void:
	_ocupado = true
	_trocar_animacao("guard", 0.07)
	_definir_intensidade_presenca(4.6)
	var tween := _novo_tween()
	tween.tween_property(self, "scale", _escala_base * 1.045, 0.14).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", _escala_base, 0.18)
	tween.tween_callback(_emitir_guarda_pronta.bind(rodadas))


func _emitir_guarda_pronta(rodadas: int) -> void:
	animacao_terminou.emit("guardar_%d" % rodadas)


func encerrar_guarda() -> void:
	_ocupado = false
	_trocar_animacao("idle", 0.10)
	_definir_intensidade_presenca(1.0)


func definir_cor_elemento(cor: Color) -> void:
	_cor_elemento = cor
	if _luz_presenca != null:
		_luz_presenca.light_color = cor
	if _material_anel_interno != null:
		_material_anel_interno.emission = cor
	if _material_anel_externo != null:
		_material_anel_externo.emission = cor


func definir_contraluz(_valor: float) -> void:
	pass


func _criar_presenca_3d(altura: float) -> void:
	_sombra = MeshInstance3D.new()
	var malha_sombra := PlaneMesh.new()
	malha_sombra.size = Vector2(altura * 0.74, altura * 0.25)
	_sombra.mesh = malha_sombra
	_sombra.position = Vector3(0.0, 0.018, 0.0)
	var shader_sombra := Shader.new()
	shader_sombra.code = CODIGO_SOMBRA
	_material_sombra = ShaderMaterial.new()
	_material_sombra.shader = shader_sombra
	_material_sombra.set_shader_parameter("alpha", 0.36)
	_sombra.material_override = _material_sombra
	add_child(_sombra)

	_anel_externo = _criar_anel(altura * 0.40, altura * 0.018, 0.14)
	_material_anel_externo = _anel_externo.material_override as StandardMaterial3D
	_anel_externo.position.y = 0.026
	add_child(_anel_externo)
	_anel_interno = _criar_anel(altura * 0.28, altura * 0.010, 0.28)
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


func _atualizar_presenca(delta: float) -> void:
	if _anel_externo == null:
		return
	var pulso := 0.5 + sin(_tempo * 2.2) * 0.5
	_impulso_presenca = move_toward(_impulso_presenca, 1.0, delta * 4.2)
	_anel_externo.rotation.y = _tempo * 0.34
	_anel_interno.rotation.y = -_tempo * 0.58
	_material_anel_externo.emission_energy_multiplier = (0.65 + pulso * 1.20) * _impulso_presenca
	_material_anel_interno.emission_energy_multiplier = (0.92 + pulso * 1.58) * _impulso_presenca
	_luz_presenca.light_energy = (0.27 + pulso * 0.21) * _impulso_presenca
	if _material_sombra != null:
		var sombra_alpha := 0.34 - absf(sin(_tempo * float(_perfil["ritmo"]))) * 0.07
		_material_sombra.set_shader_parameter("alpha", sombra_alpha)


func _definir_intensidade_presenca(valor: float) -> void:
	_impulso_presenca = maxf(1.0, valor)


func _criar_rastro(atraso: float, alpha: float) -> void:
	if _sprite_ativo == null:
		return
	var fantasma := AnimatedSprite3D.new()
	fantasma.sprite_frames = _quadros
	fantasma.play(_sprite_ativo.animation)
	fantasma.frame = _sprite_ativo.frame
	fantasma.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fantasma.shaded = false
	fantasma.transparent = true
	fantasma.no_depth_test = true
	fantasma.render_priority = 3
	fantasma.pixel_size = _sprite_ativo.pixel_size
	fantasma.position = _sprite_ativo.position
	fantasma.scale = _sprite_ativo.scale
	fantasma.modulate = Color(_cor_elemento.r, _cor_elemento.g, _cor_elemento.b, alpha)
	add_child(fantasma)
	var tween := create_tween()
	if atraso > 0.0:
		tween.tween_interval(atraso)
	tween.set_parallel(true)
	tween.tween_property(fantasma, "modulate:a", 0.0, 0.22)
	tween.tween_property(fantasma, "scale", fantasma.scale * 1.10, 0.22)
	tween.chain().tween_callback(fantasma.queue_free)


func _finalizar_estado(nome: String, voltar_ao_idle: bool = true) -> void:
	if nome == "atacar":
		_ataque_pesado_pendente = false
	if voltar_ao_idle:
		position = _origem
		scale = _escala_base
		_trocar_animacao("idle", 0.09)
	_ocupado = false
	_definir_intensidade_presenca(1.0)
	animacao_terminou.emit(nome)
