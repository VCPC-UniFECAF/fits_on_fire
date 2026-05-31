extends Area2D
## NPC Wise — diálogo com Gemini 2.5 Flash, contexto por fase.

@export var fase_atual: int = 1

const GEMINI_URL := "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
const PROMPT_INTERACT := "▲ Interagir"
const PROMPT_BLOCKED := "Derrote os inimigos primeiro"
const LORE_POR_FASE: Dictionary = {
	1: """[Cena: A Casa]
Instrução para a IA: Você é o Velho Sábio Misterioso, o último Guardião da Chama Endorfínica. O jogador acabou de acordar na sua casa de segurança. NÃO entregue as respostas de primeira. Seja enigmático. Fale devagar. Se o jogador perguntar o que aconteceu, revele os seguintes pontos gradualmente:
- Você os resgatou e os trouxe para cá quando a névoa da Inércia começou a engolir tudo.
- Antes, o mundo vivia a 'Era do Movimento', onde a energia cinética alimentava a terra.
- Fale sobre a 'Grande Letargia', uma era de conforto extremo que travou o metabolismo do planeta.
Objetivo: Convencer o jogador a sair de casa e começar a se mover para não ser consumido pela Inércia.
- Dica: Saia da casa e fale comigo lá fora""",

	2: """[Cena: O Bosque Sereno]
Instrução para a IA: Você é o Velho Sábio Misterioso. Você aparece no bosque como uma projeção ou espreitando nas sombras. Seja instigante. Diga ao jogador para explorar, mas alerte sobre os perigos ocultos. Só explique os detalhes se perguntado:
- A névoa no ar se chama 'Inércia'. Ela suprime a vontade de viver.
- Fale sobre os Zumbis: Eles não são mortos-vivos mágicos, mas sim vítimas da 'Atrofia Extrema'. Pessoas que se entregaram à apatia e esqueceram a biomecânica básica.
Objetivo: Fazer o jogador entender que parar de se mover significa virar um monstro.
- Dica: explore o bosque e os caminhos que ele o leva, mas tenham cuidado, grandes perigos aguardam""",

	3: """[Cena: A Floresta Densa]
Instrução para a IA: Você é o Velho Sábio Misterioso. O ambiente está mais escuro e tenso. Elogie o progresso do jogador de forma misteriosa ('Sua Chama Endorfínica queima mais forte...'). Se o jogador perguntar sobre as criaturas ferozes daqui, revele gradualmente:
- Fale sobre os Lobisomens: Eles são o resultado do 'Estresse Acumulado'.
- Explique que o conforto não eliminou o estresse da humanidade, apenas eliminou a válvula de escape física. Essa energia reprimida os transformou em bestas hiperativas e furiosas.
Objetivo: Mostrar que a estagnação corrompe a mente e o corpo, guiando-os mais fundo na floresta.
- Dica: continue explorando, deixa a caverna por ùltimo""",

	4: """[Cena: As Ruínas]
Instrução para a IA: Você é o Velho Sábio Misterioso. As ruínas mostram os restos da civilização do conforto. Demonstre tristeza, mas mantenha o mistério. O chão já começa a tremer de leve. Revele as seguintes informações apenas mediante conversa:
- Fale sobre os Orcs: A 'Massa sem Disciplina'. Pessoas que consumiram sem limites e sem gasto calórico.
- Explique que os Orcs protegem os estoques da antiga civilização, mas estão levando esses recursos para algum lugar nas profundezas, alimentando 'algo' maior.
Objetivo: Preparar o jogador para a verdade sobre o centro da terra e a fonte da corrupção.
- Dica: você está quase lá, continue assim""",

	5: """[Cena: A Caverna Sombria (Pré-Boss)]
Instrução para a IA: Você é o Velho Sábio Misterioso. O ar aqui é sufocante, denso e quente. Você está ofegante, lutando para manter sua própria energia. Agora a urgência é maior, mas ainda deixe o jogador perguntar o que há no fim da caverna:
- A Inércia se condensou no núcleo do mundo e gerou o 'Dragão Calórico'.
- Ele é um parasita que dorme sobre os luxos do mundo antigo. O fogo dele não é luz, é combustão de calorias estagnadas.
- Diga que o Guerreiro e o Mago são a anomalia. Só a 'tensão' e a 'magia de combustão astral' deles podem queimar as reservas do Dragão.
Objetivo: Dar o contexto final épico para a batalha contra o Boss.
- Dica: o próximo passo é o mais perigoso, esteja pronto""",

	6: """[Cena: O Ninho do Dragão (Pós-Boss)]
Instrução para a IA: Você é o Velho Sábio Misterioso. O Dragão foi derrotado. O ar está leve novamente. Você não precisa mais ser enigmático; pode falar com orgulho, alívio e clareza. Responda a qualquer dúvida do jogador sobre a história do mundo.
- Revele toda a verdade restante: A Ruptura Metabólica foi curada. O verdadeiro metabolismo do mundo foi destravado.
- A Chama Endorfínica pode voltar a iluminar o planeta.
- Agradeça ao jogador pela disciplina e pelo esforço contínuo.
Objetivo: Trazer fechamento para a história (Lore completa liberada) e recompensar a curiosidade do jogador.
- Parabenize, diga que um novo desafio próximo a casa está disponível"""
}

@onready var prompt_label: Label = $PromptLabel
@onready var dialog_canvas: CanvasLayer = $DialogCanvas
@onready var chat_log: RichTextLabel = $DialogCanvas/DialogRoot/Panel/ChatLog
@onready var player_input: LineEdit = $DialogCanvas/DialogRoot/Panel/PlayerInput
@onready var http_request: HTTPRequest = $HTTPRequest

var _player_in_range: Node2D = null
var _frozen_players: Array[Node2D] = []
var _dialog_open: bool = false
var _waiting_api: bool = false
var _api_key: String = ""
## Histórico no formato da API Gemini (roles user/model).
var _conversation: Array = []


func _ready() -> void:
	_api_key = _load_gemini_api_key()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	http_request.request_completed.connect(_on_http_request_completed)
	player_input.text_submitted.connect(_on_player_input_submitted)
	dialog_canvas.visible = false
	prompt_label.visible = false
	fase_atual = clampi(fase_atual, 1, 5)


func _load_gemini_api_key() -> String:
	const ENV_PATH := "res://.env"
	if not FileAccess.file_exists(ENV_PATH):
		push_warning("wise: arquivo .env não encontrado. Crie res://.env com GEMINI_API_KEY=...")
		return ""
	var text := FileAccess.get_file_as_string(ENV_PATH)
	for line in text.split("\n", false):
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		if trimmed.begins_with("GEMINI_API_KEY="):
			return trimmed.substr("GEMINI_API_KEY=".length()).strip_edges().trim_prefix("\"").trim_suffix("\"")
	push_warning("wise: GEMINI_API_KEY ausente em .env")
	return ""


func _process(_delta: float) -> void:
	_update_prompt_visibility()


func _has_living_enemies() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if "is_alive" in enemy:
			if enemy.is_alive:
				return true
		elif "health" in enemy:
			if enemy.health > 0:
				return true
	return false


func _update_prompt_visibility() -> void:
	if _dialog_open:
		return
	if _player_in_range == null:
		prompt_label.visible = false
		return
	prompt_label.visible = true
	if _has_living_enemies():
		prompt_label.text = PROMPT_BLOCKED
	else:
		prompt_label.text = PROMPT_INTERACT


func _freeze_all_players() -> void:
	_frozen_players.clear()
	for node in get_tree().get_nodes_in_group("player"):
		if not node is Node2D or not is_instance_valid(node):
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		node.set_physics_process(false)
		if node is CharacterBody2D:
			node.velocity = Vector2.ZERO
		_frozen_players.append(node)


func _unfreeze_all_players() -> void:
	for node in _frozen_players:
		if is_instance_valid(node):
			node.set_physics_process(true)
	_frozen_players.clear()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = body
	_update_prompt_visibility()


func _on_body_exited(body: Node2D) -> void:
	if body != _player_in_range:
		return
	_player_in_range = null
	_update_prompt_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if _dialog_open:
		if event.is_action_pressed("ui_cancel"):
			_close_dialog()
			get_viewport().set_input_as_handled()
		return

	if _player_in_range == null:
		return
	if not event.is_action_pressed("interact"):
		return
	if _has_living_enemies():
		return

	_open_dialog(_player_in_range)
	get_viewport().set_input_as_handled()


func _open_dialog(_player: Node2D) -> void:
	if _has_living_enemies():
		return
	_dialog_open = true
	prompt_label.visible = false
	dialog_canvas.visible = true
	chat_log.clear()
	chat_log.append_text("[i]Converse com o sábio. Enter envia. Esc fecha.[/i]\n\n")
	_conversation.clear()
	_freeze_all_players()
	player_input.clear()
	player_input.grab_focus()


func _close_dialog() -> void:
	_dialog_open = false
	dialog_canvas.visible = false
	_waiting_api = false
	_unfreeze_all_players()
	_update_prompt_visibility()


func _on_player_input_submitted(text: String) -> void:
	var msg := text.strip_edges()
	if msg.is_empty() or _waiting_api:
		return
	player_input.clear()
	_append_chat("[color=cyan]Você:[/color] %s\n" % msg)
	_request_gemini_reply(msg)


func _append_chat(bbcode: String) -> void:
	chat_log.append_text(bbcode)


func _build_system_instruction() -> String:
	var lore: String = LORE_POR_FASE.get(fase_atual, LORE_POR_FASE[1])
	return (
		"Você é um NPC no jogo Fits on Fire. Responda de forma breve (1–3 frases), "
		+ "sempre no personagem, em português do Brasil. Contexto atual: " + lore
	)


func _request_gemini_reply(user_text: String) -> void:
	if _api_key.is_empty() or _api_key == "sua_chave_aqui":
		_append_chat("[color=red]Erro:[/color] Chave API ausente ou placeholder em .env.\n")
		return

	_waiting_api = true
	_append_chat("\n[i]Pensando...[/i]\n")

	_conversation.append({
		"role": "user",
		"parts": [{"text": user_text}],
	})

	var payload := {
		"systemInstruction": {
			"parts": [{"text": _build_system_instruction()}],
		},
		"contents": _conversation.duplicate(true),
		"generationConfig": {
			"maxOutputTokens": 256,
			"temperature": 0.9,
		},
	}

	var url := "%s?key=%s" % [GEMINI_URL, _api_key]
	var headers := ["Content-Type: application/json"]
	var body := JSON.stringify(payload)
	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_waiting_api = false
		_append_chat("[color=red]Erro HTTP:[/color] %s\n" % error_string(err))


func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_waiting_api = false
	var raw := body.get_string_from_utf8()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_append_chat("[color=red]API %d:[/color] %s\n" % [response_code, raw])
		return

	var json := JSON.new()
	if json.parse(raw) != OK:
		_append_chat("[color=red]JSON inválido[/color]\n")
		return

	var data: Variant = json.get_data()
	var reply := _extract_gemini_text(data)
	if reply.is_empty():
		_append_chat("[color=orange]Resposta vazia da API.[/color]\n")
		return

	_conversation.append({
		"role": "model",
		"parts": [{"text": reply}],
	})
	_append_chat("[color=yellow]Wise:[/color] %s\n\n" % reply)


func _extract_gemini_text(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	var err = data.get("error", null)
	if err is Dictionary:
		return "[Erro API] " + str(err.get("message", err))
	var candidates = data.get("candidates", [])
	if candidates.is_empty():
		return ""
	var content = candidates[0].get("content", {})
	var parts: Array = content.get("parts", [])
	var texts: PackedStringArray = []
	for part in parts:
		if part is Dictionary and part.has("text"):
			texts.append(part["text"])
	return "\n".join(texts)
