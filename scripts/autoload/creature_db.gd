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

var creatures: Array[Dictionary] = []
var creatures_by_id: Dictionary = {}

## Preenchidos por `_load_elements()`. Antes eram constantes escritas a mao.
var ELEMENTS: Array = []
var TYPE_COLORS: Dictionary = {}
var STRONG_AGAINST: Dictionary = {}
var ELEMENT_SLUGS: Dictionary = {}

var MULTIPLICADOR_VANTAGEM := 1.45
var MULTIPLICADOR_RESISTENCIA := 0.68
var MULTIPLICADOR_MESMO_TIPO := 0.82


func _ready() -> void:
	_load_elements()
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
		var alvos: Variant = elemento.get("strong_against", [])
		STRONG_AGAINST[nome] = (alvos as Array).duplicate() if alvos is Array else []

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


func color_for_type(type_name: String) -> Color:
	return TYPE_COLORS.get(type_name, Color.WHITE)


## Elementos que `element` vence.
func strong_against(element: String) -> Array:
	return (STRONG_AGAINST.get(element, []) as Array).duplicate()


## Elementos que vencem `element`. Derivado da tabela, nunca escrito a mao.
func weak_against(element: String) -> Array:
	var resultado: Array = []
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
func rival_pairs() -> Array:
	var pares: Array = []
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
