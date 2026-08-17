class_name TypeEmblem
extends Control

## Emblema do elemento, desenhado em vetor.
##
## Substitui `assets/type_icons/<slug>.png`, que era o maior responsavel pelo
## aspecto amador da interface. Cada um daqueles arquivos era:
##
##   - um QUADRADO 100% opaco (zero pixel transparente, os quatro cantos com
##     alfa 1.0) — o "fundo quadrado" colado sobre a arte de qualquer tela;
##   - dentro dele um adesivo de borda branca grossa;
##   - dentro do adesivo um circulo CINZA, sem relacao com a cor do elemento;
##   - e o nome do elemento QUEIMADO na imagem em 256x256, que reaparecia
##     serrilhado em toda escala e duplicava o texto que a tela ja escrevia.
##
## Aqui o emblema nasce transparente, na cor do proprio elemento, e e
## desenhado no tamanho exato em que aparece — entao fica nitido tanto no
## selo de 34 px do combate quanto na placa de 150 px do guia de poderes.
## O nome do elemento e responsabilidade da TELA, nao da arte.

const RAIO_BASE := 128.0

var element := "Luz":
	set(value):
		element = value
		_cor = CreatureDB.color_for_type(value)
		queue_redraw()

## Brilho do anel externo. A tela sobe isso para destacar o elemento ativo.
var destaque := 0.0:
	set(value):
		destaque = clampf(value, 0.0, 1.0)
		queue_redraw()

## Quando falso o emblema sai chapado, sem anel nem halo — util em listas
## densas, onde o brilho de dezenas de emblemas viraria ruido.
var enfeitado := true:
	set(value):
		enfeitado = value
		queue_redraw()

var _cor := Color("ffe477")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(64, 64)


func _ready() -> void:
	_cor = CreatureDB.color_for_type(element)
	resized.connect(queue_redraw)


func _draw() -> void:
	var lado := minf(size.x, size.y)
	if lado <= 1.0:
		return
	var centro := size * 0.5
	var raio := lado * 0.5
	var escala := raio / RAIO_BASE

	var claro := _cor.lightened(0.42)
	var escuro := _cor.darkened(0.62)

	if enfeitado:
		## Halo: some suavemente, entao o emblema se apoia no fundo da tela
		## em vez de recortar contra ele.
		for passo in range(5, 0, -1):
			var t := float(passo) / 5.0
			draw_circle(
				centro,
				raio * (0.86 + t * 0.16),
				Color(_cor.r, _cor.g, _cor.b, 0.05 * (1.0 - t) + destaque * 0.10)
			)

	## Disco do elemento, escuro no fundo e claro em cima: da volume sem
	## depender de textura.
	draw_circle(centro, raio * 0.80, escuro)
	draw_circle(centro - Vector2(0.0, raio * 0.06), raio * 0.74, _cor.darkened(0.28))
	draw_circle(centro - Vector2(0.0, raio * 0.14), raio * 0.62, _cor)

	if enfeitado:
		## Anel fino na cor clara. Substitui a borda branca grossa do PNG.
		draw_arc(centro, raio * 0.88, 0.0, TAU, 64, Color(claro, 0.85 + destaque * 0.15), maxf(1.5, 3.0 * escala), true)

	_desenhar_simbolo(centro, raio * 0.52, Color(1.0, 1.0, 1.0, 0.97), escuro)


## Simbolo de cada elemento. Poligonos e arcos: nitido em qualquer tamanho.
func _desenhar_simbolo(centro: Vector2, raio: float, tinta: Color, sombra: Color) -> void:
	var deslocamento := Vector2(0.0, raio * 0.055)
	match element:
		"Luz":
			_estrela(centro + deslocamento, raio, sombra, 8)
			_estrela(centro, raio, tinta, 8)
		"Escuridão":
			## Sem passe de sombra: o crescente ja e recortado pelo disco,
			## e um segundo passe deslocado sujaria a silhueta.
			_lua(centro, raio, tinta, _cor)
		"Fogo":
			_chama(centro + deslocamento, raio, sombra)
			_chama(centro, raio, tinta)
		"Choque":
			_raio(centro + deslocamento, raio, sombra)
			_raio(centro, raio, tinta)
		"Terra":
			_montanha(centro + deslocamento, raio, sombra)
			_montanha(centro, raio, tinta)
		"Água":
			_gota(centro + deslocamento, raio, sombra)
			_gota(centro, raio, tinta)
		"Natureza":
			_folha(centro + deslocamento, raio, sombra)
			_folha(centro, raio, tinta)
		"Vento":
			_vento(centro + deslocamento, raio, sombra)
			_vento(centro, raio, tinta)
		_:
			draw_circle(centro, raio * 0.5, tinta)


func _estrela(centro: Vector2, raio: float, cor: Color, pontas: int) -> void:
	var pontos := PackedVector2Array()
	for indice in range(pontas * 2):
		var angulo := TAU * float(indice) / float(pontas * 2) - PI * 0.5
		var r := raio if indice % 2 == 0 else raio * 0.40
		pontos.append(centro + Vector2(cos(angulo), sin(angulo)) * r)
	draw_colored_polygon(pontos, cor)


## Crescente. O GDScript nao tem furo em poligono, entao o recorte e feito
## desenhando por cima um disco com a cor do fundo do emblema.
##
## A tentativa anterior montava o crescente como um unico poligono costurando
## dois arcos; a costura se auto-intersectava e o triangulador do Godot
## devolvia um disco cheio — a Escuridao aparecia como uma bolinha roxa lisa,
## sem lua nenhuma.
func _lua(centro: Vector2, raio: float, cor: Color, recorte: Color) -> void:
	draw_circle(centro, raio * 0.96, cor)
	draw_circle(centro + Vector2(raio * 0.46, -raio * 0.12), raio * 0.86, recorte)


func _chama(centro: Vector2, raio: float, cor: Color) -> void:
	var pontos := PackedVector2Array([
		centro + Vector2(0.0, -raio),
		centro + Vector2(raio * 0.46, -raio * 0.18),
		centro + Vector2(raio * 0.62, raio * 0.34),
		centro + Vector2(raio * 0.30, raio * 0.86),
		centro + Vector2(-raio * 0.30, raio * 0.86),
		centro + Vector2(-raio * 0.62, raio * 0.34),
		centro + Vector2(-raio * 0.40, -raio * 0.22),
		centro + Vector2(-raio * 0.10, -raio * 0.52),
	])
	draw_colored_polygon(pontos, cor)


func _raio(centro: Vector2, raio: float, cor: Color) -> void:
	var pontos := PackedVector2Array([
		centro + Vector2(raio * 0.30, -raio),
		centro + Vector2(-raio * 0.52, raio * 0.14),
		centro + Vector2(-raio * 0.04, raio * 0.14),
		centro + Vector2(-raio * 0.28, raio),
		centro + Vector2(raio * 0.56, -raio * 0.18),
		centro + Vector2(raio * 0.06, -raio * 0.18),
	])
	draw_colored_polygon(pontos, cor)


func _montanha(centro: Vector2, raio: float, cor: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		centro + Vector2(-raio, raio * 0.62),
		centro + Vector2(-raio * 0.24, -raio * 0.30),
		centro + Vector2(raio * 0.18, raio * 0.20),
		centro + Vector2(raio * 0.44, -raio * 0.10),
		centro + Vector2(raio, raio * 0.62),
	]), cor)


func _gota(centro: Vector2, raio: float, cor: Color) -> void:
	var pontos := PackedVector2Array([centro + Vector2(0.0, -raio)])
	var passos := 40
	for indice in range(passos + 1):
		var angulo := lerpf(-PI * 0.42, PI * 1.42, float(indice) / float(passos))
		pontos.append(centro + Vector2(cos(angulo), sin(angulo)) * raio * 0.72 + Vector2(0.0, raio * 0.24))
	draw_colored_polygon(pontos, cor)


func _folha(centro: Vector2, raio: float, cor: Color) -> void:
	var pontos := PackedVector2Array()
	var passos := 32
	for indice in range(passos + 1):
		var t := float(indice) / float(passos)
		var y := lerpf(-raio, raio, t)
		var largura := sin(t * PI) * raio * 0.62
		pontos.append(centro + Vector2(largura, y))
	for indice in range(passos + 1):
		var t := 1.0 - float(indice) / float(passos)
		var y := lerpf(-raio, raio, t)
		var largura := sin(t * PI) * raio * 0.62
		pontos.append(centro + Vector2(-largura * 0.28, y))
	draw_colored_polygon(pontos, cor)


## Tres rajadas de comprimentos diferentes. Os arcos de gancho da versao
## anterior se sobrepunham as linhas e viravam um borrao no tamanho do HUD.
func _vento(centro: Vector2, raio: float, cor: Color) -> void:
	var espessura := maxf(2.0, raio * 0.22)
	var comprimentos := [0.72, 1.0, 0.54]
	for indice in range(3):
		var y := centro.y + (float(indice) - 1.0) * raio * 0.56
		var largura := raio * float(comprimentos[indice])
		draw_line(
			Vector2(centro.x - largura, y), Vector2(centro.x + largura, y),
			cor, espessura, true
		)
