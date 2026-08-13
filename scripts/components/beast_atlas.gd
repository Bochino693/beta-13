extends RefCounted
class_name BeastAtlas

# ---------------------------------------------------------------------------
# BeastAtlas — corte correto dos atlas de combate.
#
# Substitui a divisao rigida 4x4 de cinematic_beast_sprite_3d.gd, que assume
# celulas de largura/4 por altura/4. Os 30 atlas tem 11 resolucoes diferentes
# e as poses nao estao alinhadas numa grade matematica: medindo o arcdrake,
# as colunas reais tem 333, 304, 345 e 320 px, e a grade assume 350 fixo.
# Por isso aparece pedaco da pose vizinha dentro do quadro.
#
# Aqui as poses vem de assets/sprites_combat/<id>.poses.json, gerado por
# tools/mapear_poses.py a partir da transparencia real de cada imagem.
#
# COMO TROCAR em cinematic_beast_sprite_3d.gd:
#
#   func _construir_quadros(textura: Texture2D) -> SpriteFrames:
#       return BeastAtlas.quadros_de(_id_beast, textura)
#
# Apague o corpo antigo da funcao. O resto do arquivo continua igual: os nomes
# de animacao "pose_00".."pose_15" sao mantidos, entao POSE_ATAQUE e companhia
# seguem valendo.
# ---------------------------------------------------------------------------

const PASTA := "res://assets/sprites_combat/"
const LINHAS := 4
const COLUNAS := 4

# Nomes legiveis. ATENCAO a ordem do atlas do beta-13:
#   0..7  = COSTAS (Beast do jogador)
#   8..15 = FRENTE (oponente)
const NOMES := [
	"repouso_a_costas", "repouso_b_costas", "carga_costas", "ataque_costas",
	"dano_costas", "esquiva_costas", "vitoria_costas", "ko_costas",
	"repouso_a", "repouso_b", "carga", "ataque",
	"dano", "esquiva", "vitoria", "ko"
]

static var _cache: Dictionary = {}


## Le o manifesto de poses da Beast. Devolve {} se nao existir.
static func manifesto(id_beast: String) -> Dictionary:
	if _cache.has(id_beast):
		return _cache[id_beast]

	var caminho := PASTA + id_beast + ".poses.json"
	var dados: Dictionary = {}

	if FileAccess.file_exists(caminho):
		var arquivo := FileAccess.open(caminho, FileAccess.READ)
		if arquivo != null:
			var lido = JSON.parse_string(arquivo.get_as_text())
			arquivo.close()
			if lido is Dictionary:
				dados = lido
			else:
				push_warning("BeastAtlas: manifesto invalido -> " + caminho)

	_cache[id_beast] = dados
	return dados


## Retangulo real de uma pose. Cai na grade 4x4 se nao houver manifesto.
static func retangulo(id_beast: String, indice: int, textura: Texture2D) -> Rect2:
	var dados := manifesto(id_beast)
	var poses: Array = dados.get("poses", [])

	if indice >= 0 and indice < poses.size():
		var pose: Dictionary = poses[indice]
		if not bool(pose.get("vazia", false)) and pose.has("rect"):
			var r: Array = pose["rect"]
			return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))

	# Sem manifesto: comportamento antigo, para nao quebrar nada.
	var largura := textura.get_width() / float(COLUNAS)
	var altura := textura.get_height() / float(LINHAS)
	return Rect2(
		float(indice % COLUNAS) * largura,
		float(indice / COLUNAS) * altura,
		largura,
		altura
	)


## Monta o SpriteFrames com uma animacao por pose, cortada no lugar certo.
static func quadros_de(id_beast: String, textura: Texture2D) -> SpriteFrames:
	var recurso := SpriteFrames.new()
	if recurso.has_animation("default"):
		recurso.remove_animation("default")

	for indice in LINHAS * COLUNAS:
		var animacao := "pose_%02d" % indice
		recurso.add_animation(animacao)
		recurso.set_animation_loop(animacao, false)
		recurso.set_animation_speed(animacao, 1.0)

		var atlas := AtlasTexture.new()
		atlas.atlas = textura
		atlas.region = retangulo(id_beast, indice, textura)
		# filter_clip evita puxar pixel do vizinho na borda da regiao.
		atlas.filter_clip = true
		recurso.add_frame(animacao, atlas)

		# Alias legivel: "ataque" aponta para o mesmo quadro de "pose_03".
		if indice < NOMES.size():
			var apelido := String(NOMES[indice])
			recurso.add_animation(apelido)
			recurso.set_animation_loop(apelido, false)
			recurso.set_animation_speed(apelido, 1.0)
			recurso.add_frame(apelido, atlas)

	return recurso


## Altura util da pose em pixels. Serve para escalar a Beast no mundo 3D sem
## que uma pose deitada (o KO) fique do mesmo tamanho de uma em pe.
static func altura_da_pose(id_beast: String, indice: int, textura: Texture2D) -> float:
	return retangulo(id_beast, indice, textura).size.y


## Altura da pose de repouso: e ela que deve definir a escala da Beast.
static func altura_base(id_beast: String, textura: Texture2D) -> float:
	return altura_da_pose(id_beast, 0, textura)


## Quanto o corte antigo errava, em pixels. Util em log de diagnostico.
static func erro_da_grade(id_beast: String, textura: Texture2D) -> float:
	var dados := manifesto(id_beast)
	if dados.is_empty():
		return 0.0

	var largura := textura.get_width() / float(COLUNAS)
	var altura := textura.get_height() / float(LINHAS)
	var pior := 0.0

	var poses: Array = dados.get("poses", [])
	for indice in poses.size():
		var pose: Dictionary = poses[indice]
		if not pose.has("rect"):
			continue
		var r: Array = pose["rect"]
		var gx := float(indice % COLUNAS) * largura
		var gy := float(indice / COLUNAS) * altura
		pior = maxf(pior, absf(float(r[0]) - gx))
		pior = maxf(pior, absf(float(r[1]) - gy))
		pior = maxf(pior, absf(float(r[0]) + float(r[2]) - (gx + largura)))
		pior = maxf(pior, absf(float(r[1]) + float(r[3]) - (gy + altura)))

	return pior
