extends Node

const DATA_PATH := "res://data/creatures.json"

## HIERARQUIA ELEMENTAL — carregada de `data/elements.json`.
##
## Aquele arquivo e a fonte UNICA: o runtime le dali e
## `tools/simulate_balance.py` le do mesmo lugar. Ate a versao anterior cada
## um tinha a sua propria tabela, e as duas divergiam — o simulador aprovava
## um equilibrio que nao era o do jogo instalado.
##
## Regra geral: cada elemento vence outros e e vencido por outros; e um
## ciclo, nenhum elemento domina a roda inteira.
##
## A unica relacao RECIPROCA e LUZ <-> ESCURIDAO: os dois se vencem
## mutuamente, com o mesmo multiplicador nos dois sentidos. Nesse confronto
## nao existe lado seguro — quem acertar primeiro leva a vantagem — e a
## interface o anuncia como CHOQUE DE RIVAIS, porque a vantagem nao
## pertence a nenhum dos dois.
const ELEMENTS_PATH := "res://data/elements.json"

## Raridade de COLECAO, nao de forca. Ver o cabecalho de
## `data/rarities.json`: os status das Beasts sao planos de proposito e
## o equilibrio depende disso, entao raridade nunca entra no dano.
const RARITIES_PATH := "res://data/rarities.json"

var creatures: Array[Dictionary] = []
var creatures_by_id: Dictionary = {}

## Preenchidos por `_load_elements()`. Antes eram constantes escritas a mao.
## `ELEMENTS` e as listas de `STRONG_AGAINST` sao `Array[String]` de
## verdade, nao `Array` solta. Uma tela que faca
## `var x: Array[String] = CreatureDB.strong_against(e)` precisa receber o
## tipo ja pronto: devolver `Array` crua aqui e o que produzia o erro
## "Trying to return an array of type Array where expected return type is
## Array[String]" la na ponta.
var ELEMENTS: Array[String] = []
var TYPE_COLORS: Dictionary = {}
var STRONG_AGAINST: Dictionary = {}
var ELEMENT_SLUGS: Dictionary = {}

## Preenchidos por `_load_rarities()`, a partir de `data/rarities.json`.
var RARITIES: Array[String] = []
var RARITY_ORDER: Dictionary = {}
var RARITY_LABELS: Dictionary = {}
var RARITY_COLORS: Dictionary = {}
var RARITY_WEIGHTS: Dictionary = {}

var MULTIPLICADOR_VANTAGEM := 1.45
var MULTIPLICADOR_RESISTENCIA := 0.68
var MULTIPLICADOR_MESMO_TIPO := 0.82


func _ready() -> void:
	_load_elements()
	_load_rarities()
	_load_catalog()


func _load_elements() -> void:
	var file := FileAccess.open(ELEMENTS_PATH, FileAccess.READ)
	if file == null:
		push_error("Hierarquia elemental não encontrada: %s" % ELEMENTS_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Hierarquia elemental inválida: %s" % ELEMENTS_PATH)
		return

	var raiz: Dictionary = parsed as Dictionary
	var multiplicadores: Variant = raiz.get("multipliers", {})
	if multiplicadores is Dictionary:
		var m: Dictionary = multiplicadores as Dictionary
		MULTIPLICADOR_VANTAGEM = float(m.get("advantage", MULTIPLICADOR_VANTAGEM))
		MULTIPLICADOR_RESISTENCIA = float(m.get("resistance", MULTIPLICADOR_RESISTENCIA))
		MULTIPLICADOR_MESMO_TIPO = float(m.get("same_type", MULTIPLICADOR_MESMO_TIPO))

	ELEMENTS.clear()
	TYPE_COLORS.clear()
	STRONG_AGAINST.clear()
	ELEMENT_SLUGS.clear()

	for entrada in raiz.get("elements", []):
		if not entrada is Dictionary:
			continue
		var elemento: Dictionary = entrada as Dictionary
		var nome := str(elemento.get("name", ""))
		if nome.is_empty():
			continue
		ELEMENTS.append(nome)
		TYPE_COLORS[nome] = Color(str(elemento.get("color", "ffffff")))
		ELEMENT_SLUGS[nome] = str(elemento.get("slug", ""))
		var alvos: Array[String] = []
		var brutos: Variant = elemento.get("strong_against", [])
		if brutos is Array:
			for alvo: Variant in brutos as Array:
				alvos.append(str(alvo))
		STRONG_AGAINST[nome] = alvos

	if ELEMENTS.size() != 8:
		push_warning(
			"A hierarquia deveria ter 8 elementos; foram carregados %d." % ELEMENTS.size()
		)

	## Um alvo escrito errado quebraria a hierarquia em silencio: o golpe
	## simplesmente nunca teria vantagem. Melhor reclamar na importacao.
	for atacante: String in STRONG_AGAINST.keys():
		for alvo: String in STRONG_AGAINST[atacante]:
			if alvo not in ELEMENTS:
				push_error(
					"Hierarquia elemental: %s vence '%s', que não é um elemento."
					% [atacante, alvo]
				)


## Nome do arquivo de icone do elemento, sem acento. Sai do proprio
## catalogo, entao um elemento novo nao precisa de tabela de conversao
## espalhada pelas telas.
func slug_for_type(type_name: String) -> String:
	return str(ELEMENT_SLUGS.get(type_name, ""))


func _load_rarities() -> void:
	var file := FileAccess.open(RARITIES_PATH, FileAccess.READ)
	if file == null:
		push_error("Catálogo de raridades não encontrado: %s" % RARITIES_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Catálogo de raridades inválido: %s" % RARITIES_PATH)
		return

	RARITIES.clear()
	RARITY_ORDER.clear()
	RARITY_LABELS.clear()
	RARITY_COLORS.clear()
	RARITY_WEIGHTS.clear()

	var entradas: Array = []
	for entrada: Variant in (parsed as Dictionary).get("rarities", []):
		if entrada is Dictionary:
			entradas.append(entrada)
	## Ordena pela escassez declarada, para as telas nao dependerem da
	## ordem em que o arquivo foi escrito.
	entradas.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("order", 0)) < int(b.get("order", 0))
	)

	for entrada: Dictionary in entradas:
		var id_raridade := str(entrada.get("id", ""))
		if id_raridade.is_empty():
			continue
		RARITIES.append(id_raridade)
		RARITY_ORDER[id_raridade] = int(entrada.get("order", RARITIES.size() - 1))
		RARITY_LABELS[id_raridade] = str(entrada.get("label", id_raridade)).to_upper()
		RARITY_COLORS[id_raridade] = Color(str(entrada.get("color", "ffffff")))
		RARITY_WEIGHTS[id_raridade] = maxf(0.0, float(entrada.get("weight", 0.0)))

	if RARITIES.is_empty():
		push_error("Catálogo de raridades vazio: %s" % RARITIES_PATH)


func _load_catalog() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Catálogo de criaturas não encontrado: %s" % DATA_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("creatures"):
		push_error("Catálogo de criaturas inválido.")
		return
	creatures.clear()
	creatures_by_id.clear()
	for entry in parsed["creatures"]:
		var creature: Dictionary = entry.duplicate(true)
		if str(creature.get("type", "")) not in ELEMENTS:
			push_error("Elemento inválido em %s: %s" % [creature.get("id", "?"), creature.get("type", "?")])
		## Mesma logica do elemento: uma raridade escrita errada passaria
		## despercebida e a carta cairia no rodape da colecao em silencio.
		if str(creature.get("rarity", "")) not in RARITIES:
			push_error(
				"Raridade inválida em %s: %s"
				% [creature.get("id", "?"), creature.get("rarity", "?")]
			)
		creatures.append(creature)
		creatures_by_id[creature["id"]] = creature
	if creatures.size() != 30:
		push_warning("O catálogo deveria ter 30 criaturas; foram carregadas %d." % creatures.size())


func all() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for creature in creatures:
		output.append(creature.duplicate(true))
	return output


func get_creature(creature_id: String) -> Dictionary:
	if not creatures_by_id.has(creature_id):
		return {}
	return creatures_by_id[creature_id].duplicate(true)


## --- RARIDADE DE COLECAO -------------------------------------------------
## As telas leem daqui; nenhuma delas redefine cor, rotulo ou ordem. Nada
## nesta secao entra no calculo de dano ou de vida: raridade diz o quanto a
## carta e dificil de obter, nao o quanto a Beast bate.


func rarity_of(creature: Dictionary) -> String:
	var valor := str(creature.get("rarity", ""))
	if valor in RARITIES:
		return valor
	return RARITIES[0] if not RARITIES.is_empty() else ""


func rarity_label(rarity: String) -> String:
	return str(RARITY_LABELS.get(rarity, rarity.to_upper()))


func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


## Quanto maior, mais escassa. Serve para ordenar e comparar sem espalhar a
## lista de raridades pelas telas.
func rarity_rank(rarity: String) -> int:
	return int(RARITY_ORDER.get(rarity, 0))


## Beasts de uma faixa, na ordem do catalogo.
func creatures_of_rarity(rarity: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for creature in creatures:
		if str(creature.get("rarity", "")) == rarity:
			saida.append(creature.duplicate(true))
	return saida


## Quantas Beasts existem em cada faixa. A tela de colecao mostra "x de y"
## sem recontar o catalogo por conta propria.
func rarity_counts() -> Dictionary:
	var contagem: Dictionary = {}
	for rarity: String in RARITIES:
		contagem[rarity] = 0
	for creature in creatures:
		var rarity := str(creature.get("rarity", ""))
		if contagem.has(rarity):
			contagem[rarity] = int(contagem[rarity]) + 1
	return contagem


## Sorteia uma raridade respeitando os pesos de `data/rarities.json`.
## Usado por sorteio de carta/recompensa, nunca pelo combate.
func random_rarity() -> String:
	var total := 0.0
	for rarity: String in RARITIES:
		total += float(RARITY_WEIGHTS.get(rarity, 0.0))
	if total <= 0.0:
		return RARITIES[0] if not RARITIES.is_empty() else ""
	var sorteio := randf() * total
	for rarity: String in RARITIES:
		sorteio -= float(RARITY_WEIGHTS.get(rarity, 0.0))
		if sorteio <= 0.0:
			return rarity
	return RARITIES[RARITIES.size() - 1]


func color_for_type(type_name: String) -> Color:
	return TYPE_COLORS.get(type_name, Color.WHITE)


## Elementos que `element` vence.
func strong_against(element: String) -> Array[String]:
	var resultado: Array[String] = []
	for alvo: Variant in STRONG_AGAINST.get(element, []):
		resultado.append(str(alvo))
	return resultado


## Elementos que vencem `element`. Derivado da tabela, nunca escrito a mao.
func weak_against(element: String) -> Array[String]:
	var resultado: Array[String] = []
	for atacante: String in ELEMENTS:
		if element in STRONG_AGAINST.get(atacante, []):
			resultado.append(atacante)
	return resultado


## Verdadeiro quando os dois elementos se vencem MUTUAMENTE. Hoje so o par
## Luz/Escuridao satisfaz isso; a funcao le a tabela, entao um par novo
## passa a valer sem tocar aqui.
func are_rivals(element_a: String, element_b: String) -> bool:
	if element_a == element_b:
		return false
	return (
		element_b in STRONG_AGAINST.get(element_a, [])
		and element_a in STRONG_AGAINST.get(element_b, [])
	)


## Todos os pares reciprocos da tabela, sem repetir o inverso.
func rival_pairs() -> Array[Array]:
	var pares: Array[Array] = []
	for a: String in ELEMENTS:
		for b: String in ELEMENTS:
			if a < b and are_rivals(a, b):
				pares.append([a, b])
	return pares


func type_multiplier(attack_type: String, defender_type: String) -> float:
	if attack_type == defender_type:
		return MULTIPLICADOR_MESMO_TIPO
	## A vantagem e conferida ANTES da resistencia. Num par reciproco os dois
	## lados caem neste ramo, entao os dois atacam com vantagem — que e
	## exatamente o comportamento desejado para Luz/Escuridao.
	if defender_type in STRONG_AGAINST.get(attack_type, []):
		return MULTIPLICADOR_VANTAGEM
	if attack_type in STRONG_AGAINST.get(defender_type, []):
		return MULTIPLICADOR_RESISTENCIA
	return 1.0


## Texto do resultado. Recebe os dois elementos para conseguir separar
## "vantagem de um lado" de "os dois tem vantagem" — o multiplicador
## sozinho e 1.45 nos dois casos e nao distingue.
func effectiveness_text(
	multiplier: float, attack_type: String = "", defender_type: String = ""
) -> String:
	if multiplier >= 1.4:
		if not attack_type.is_empty() and are_rivals(attack_type, defender_type):
			return "CHOQUE DE RIVAIS!"
		return "SUPER EFETIVO!"
	if multiplier <= 0.7:
		return "RESISTIU AO TIPO"
	if multiplier < 0.9:
		return "MESMO TIPO: DANO REDUZIDO"
	return "ACERTO LIMPO"


func max_hp(data: Dictionary) -> int:
	return MoveDB.max_hp(data)


func make_fighter(creature_id: String) -> Dictionary:
	var data := get_creature(creature_id)
	var hp := max_hp(data)
	return {
		"id": creature_id,
		"data": data,
		"hp": hp,
		"max_hp": hp,
		"energy": 0,
		"cooldowns": {},
		"guard": false,
		"guard_turns": 0,
		"guard_cooldown": 0,
		"ko": false,
		"round_damage": 0
	}


func random_team(team_size: int = 5, excluded: Array = []) -> Array[String]:
	var pool: Array[String] = []
	for creature in creatures:
		var creature_id: String = creature["id"]
		if creature_id not in excluded:
			pool.append(creature_id)
	pool.shuffle()
	return pool.slice(0, mini(team_size, pool.size()))
