class_name BeastPoseAtlas
extends RefCounted

## Leitor do atlas de poses de combate da Beast.
##
## Esta e a UNICA porta de entrada para `assets/sprites_combat/<id>.png`.
## Nada no jogo calcula recorte de celula na mao: quem precisa de um quadro
## pergunta aqui e recebe um AtlasTexture ja cortado.
##
## O manifesto `<id>.poses.json` e a fonte de verdade. Linhas, colunas,
## tamanho da celula e nomes das poses saem DELE, nunca de constante no
## codigo. E por isso que o atlas V4 (8x8, 64 poses) entra sem reescrever
## nada: o manifesto novo descreve mais quadros e o resolvedor de sequencia
## abaixo simplesmente encontra mais quadros.
##
## Convencao de nome das poses:
##
##   <vista>_<estado>          uma pose unica          (ex.: back_guard)
##   <vista>_<estado>_<n>      sequencia de n quadros  (ex.: back_idle_0)
##
## `vista` e "back" para a Beast do jogador local (o jogador ve as costas
## dela) e "front" para a adversaria (encara o jogador). Essa e a leitura de
## camera do jogo e ela vem desenhada na arte, nao e espelhamento de UV.

const PASTA := "res://assets/sprites_combat/"

## Vistas validas. A Beast de baixo (jogador) usa COSTAS; a de cima (rival)
## usa FRENTE. Nunca as duas ao mesmo tempo.
const VISTA_COSTAS := "back"
const VISTA_FRENTE := "front"

## Estados pedidos pelo combate, em ordem de preferencia de fallback.
## Se o atlas nao tiver o estado exato, cai para o proximo da lista em vez
## de sumir com a Beast da tela.
const FALLBACK: Dictionary = {
	"idle": ["idle"],
	"light_charge": ["light_charge", "idle"],
	"light_impact": ["light_impact", "light_charge", "idle"],
	"heavy_charge": ["heavy_charge", "light_charge", "idle"],
	"heavy_release": ["heavy_release", "heavy_impact", "light_impact", "idle"],
	"heavy_impact": ["heavy_impact", "heavy_release", "light_impact", "idle"],
	"damage": ["damage", "idle"],
	"dodge_left": ["dodge_left", "idle"],
	"dodge_right": ["dodge_right", "idle"],
	"victory": ["victory", "idle"],
	"ko": ["ko", "damage", "idle"],
	"guard": ["guard", "idle"],
}

static var _cache_manifesto: Dictionary = {}
static var _cache_textura: Dictionary = {}

var id_beast := ""
var textura: Texture2D
var celula := Vector2(384.0, 384.0)
var _regioes: Dictionary = {}
var _ancoras: Dictionary = {}
var _sequencias: Dictionary = {}
var _valido := false


## Carrega o atlas e o manifesto da Beast. Devolve false quando falta arte:
## o chamador deve tratar isso como erro de conteudo, nunca desenhar um
## substituto generico.
static func abrir(creature_id: String) -> BeastPoseAtlas:
	var atlas := BeastPoseAtlas.new()
	atlas.id_beast = creature_id

	var caminho_png := PASTA + creature_id + ".png"
	var caminho_json := PASTA + creature_id + ".poses.json"

	if not ResourceLoader.exists(caminho_png):
		push_error("BeastPoseAtlas: atlas de combate ausente -> " + caminho_png)
		return atlas

	if _cache_textura.has(creature_id):
		atlas.textura = _cache_textura[creature_id]
	else:
		atlas.textura = load(caminho_png) as Texture2D
		_cache_textura[creature_id] = atlas.textura
	if atlas.textura == null:
		push_error("BeastPoseAtlas: textura invalida -> " + caminho_png)
		return atlas

	var manifesto := _ler_manifesto(creature_id, caminho_json)
	if manifesto.is_empty():
		push_error("BeastPoseAtlas: manifesto ausente ou invalido -> " + caminho_json)
		return atlas

	var celula_bruta: Variant = manifesto.get("cell", [384, 384])
	if celula_bruta is Array and (celula_bruta as Array).size() == 2:
		atlas.celula = Vector2(
			float((celula_bruta as Array)[0]), float((celula_bruta as Array)[1])
		)

	atlas._indexar(manifesto)
	atlas._valido = not atlas._regioes.is_empty()
	if not atlas._valido:
		push_error("BeastPoseAtlas: manifesto sem poses utilizaveis -> " + caminho_json)
	return atlas


static func _ler_manifesto(creature_id: String, caminho: String) -> Dictionary:
	if _cache_manifesto.has(creature_id):
		return _cache_manifesto[creature_id]

	var vazio: Dictionary = {}
	if not FileAccess.file_exists(caminho):
		_cache_manifesto[creature_id] = vazio
		return vazio

	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		_cache_manifesto[creature_id] = vazio
		return vazio

	var lido: Variant = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if not lido is Dictionary:
		_cache_manifesto[creature_id] = vazio
		return vazio

	_cache_manifesto[creature_id] = lido as Dictionary
	return lido as Dictionary


## Guarda o retangulo e a ancora de cada pose e ja agrupa as poses em
## sequencias por (vista, estado). O agrupamento acontece UMA vez, na
## abertura; durante a luta so se consulta dicionario.
func _indexar(manifesto: Dictionary) -> void:
	var poses: Variant = manifesto.get("poses", [])
	if not poses is Array:
		return

	## Sequencias em construcao: chave "<vista>|<estado>" -> Array de
	## {"ordem": int, "nome": String}. A ordem vem do sufixo numerico; pose
	## sem sufixo entra como ordem 0.
	var agrupado: Dictionary = {}

	for entrada in (poses as Array):
		if not entrada is Dictionary:
			continue
		var pose: Dictionary = entrada as Dictionary
		if bool(pose.get("vazia", false)):
			continue
		var nome := str(pose.get("name", ""))
		if nome.is_empty() or not pose.has("rect"):
			continue

		var r: Variant = pose["rect"]
		if not r is Array or (r as Array).size() != 4:
			continue
		var rect_array: Array = r as Array
		_regioes[nome] = Rect2(
			float(rect_array[0]),
			float(rect_array[1]),
			float(rect_array[2]),
			float(rect_array[3])
		)

		var a: Variant = pose.get("anchor", [0.5, 1.0])
		if a is Array and (a as Array).size() == 2:
			_ancoras[nome] = Vector2(float((a as Array)[0]), float((a as Array)[1]))
		else:
			_ancoras[nome] = Vector2(0.5, 1.0)

		var partes := _separar(nome)
		if partes.is_empty():
			continue
		var chave: String = "%s|%s" % [partes["vista"], partes["estado"]]
		if not agrupado.has(chave):
			agrupado[chave] = []
		(agrupado[chave] as Array).append(
			{"ordem": int(partes["ordem"]), "nome": nome}
		)

	for chave: String in agrupado.keys():
		var lista: Array = agrupado[chave]
		lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["ordem"]) < int(b["ordem"])
		)
		var nomes := PackedStringArray()
		for item: Dictionary in lista:
			nomes.append(str(item["nome"]))
		_sequencias[chave] = nomes


## Quebra "back_dodge_left" em vista=back, estado=dodge_left, ordem=0 e
## "front_idle_3" em vista=front, estado=idle, ordem=3.
##
## O sufixo so vira ordem quando e um numero puro. "dodge_left" continua
## sendo estado, nao "dodge" com ordem "left" — foi exatamente esse tipo de
## suposicao que fez o leitor antigo cortar as poses no lugar errado.
static func _separar(nome: String) -> Dictionary:
	var vista := ""
	var resto := ""
	if nome.begins_with(VISTA_COSTAS + "_"):
		vista = VISTA_COSTAS
		resto = nome.substr(VISTA_COSTAS.length() + 1)
	elif nome.begins_with(VISTA_FRENTE + "_"):
		vista = VISTA_FRENTE
		resto = nome.substr(VISTA_FRENTE.length() + 1)
	else:
		return {}
	if resto.is_empty():
		return {}

	var corte := resto.rfind("_")
	if corte > 0:
		var sufixo := resto.substr(corte + 1)
		if sufixo.is_valid_int():
			return {
				"vista": vista,
				"estado": resto.substr(0, corte),
				"ordem": sufixo.to_int(),
			}
	return {"vista": vista, "estado": resto, "ordem": 0}


func valido() -> bool:
	return _valido


func tem_pose(nome: String) -> bool:
	return _regioes.has(nome)


func regiao(nome: String) -> Rect2:
	if _regioes.has(nome):
		return _regioes[nome]
	return Rect2(Vector2.ZERO, celula)


## Ancora da pose em fracao da celula. (0.5, 1.0) = centro embaixo, ou seja,
## o pe da Beast. E isso que mantem a criatura plantada no chao quando uma
## pose e mais alta que outra.
func ancora(nome: String) -> Vector2:
	if _ancoras.has(nome):
		return _ancoras[nome]
	return Vector2(0.5, 1.0)


## Sequencia de quadros de um estado, ja na vista certa e ja ordenada.
##
## Devolve UM nome quando o atlas so tem uma pose para aquele estado (V3) e
## varios quando o atlas e animado (V4). Quem toca a sequencia nao precisa
## saber qual dos dois esta instalado.
func sequencia(vista: String, estado: String) -> PackedStringArray:
	var tentativas: Array = FALLBACK.get(estado, [estado, "idle"])
	for candidato: String in tentativas:
		var chave := "%s|%s" % [vista, candidato]
		if _sequencias.has(chave):
			return _sequencias[chave]
	return PackedStringArray()


## Quantos quadros o estado tem naquela vista. 0 significa que nem o
## fallback existe — o chamador deve manter o quadro atual.
func total_de_quadros(vista: String, estado: String) -> int:
	return sequencia(vista, estado).size()


## Altura util da pose em pixels. A escala da Beast no mundo 3D e sempre
## calculada pelo primeiro quadro de idle, nunca pela pose corrente: senao
## a criatura encolheria ao cair no KO e cresceria ao comemorar.
func altura_de_referencia(vista: String) -> float:
	var idle := sequencia(vista, "idle")
	if idle.is_empty():
		return celula.y
	return regiao(idle[0]).size.y


func largura_de_referencia(vista: String) -> float:
	var idle := sequencia(vista, "idle")
	if idle.is_empty():
		return celula.x
	return regiao(idle[0]).size.x


## Limpa os caches estaticos. Usado pelas ferramentas de validacao para
## reabrir o mesmo atlas depois de regerar a arte.
static func limpar_cache() -> void:
	_cache_manifesto.clear()
	_cache_textura.clear()
