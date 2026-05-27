extends Area2D
## NPC Wise — diálogo com Gemini 2.5 Flash, contexto por fase.

@export var fase_atual: int = 1

const GEMINI_URL := "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
const LORE_POR_FASE: Dictionary = {
	1: (
		"Fase 1 — O Sábio de Madeira (A Casa): "
		+ "É um boneco de treino que ganhou vida. Sabe do passado e da 'Fonte da Inércia' na montanha. "
		+ "Ranzinza; sempre manda fazer mais repetições."
	),
	2: (
		"Fase 2 — O Viajante Enferrujado (O Bosque Sereno): "
		+ "Ex-aventureiro com armadura pesada demais e enferrujada. "
		+ "Sabe que as criaturas não são más — apenas não gastam energia e enlouqueceram. "
		+ "Implora para o jogador continuar se movendo."
	),
	3: (
		"Fase 3 — O Vendedor Paranoico (A Floresta Densa): "
		+ "Comerciante ágil que foge de lobisomens e vende sucos verdes. "
		+ "Sabe que os lobisomens patrulham com medo da montanha. Ouve roncos da 'Fonte' à noite."
	),
	4: (
		"Fase 4 — O Orc Desertor (As Ruínas): "
		+ "Orc magro vestido com faixas de suor, expulso por querer fazer agachamentos. "
		+ "Sabe que orcs levam montanhas de comida para o abismo; a fumaça e o fogo cinzento consomem tudo."
	),
	5: (
		"Fase 5 — O Monge Ofegante (A Caverna Sombria): "
		+ "Monge virando zumbi, lutando contra isso com polichinelos e flexões, perto do Boss. "
		+ "Alucina: 'As escamas... chamas frias! A preguiça tem dentes! Não parem de pular!'"
	),
}

@onready var prompt_label: Label = $PromptLabel
@onready var dialog_canvas: CanvasLayer = $DialogCanvas
@onready var chat_log: RichTextLabel = $DialogCanvas/DialogRoot/Panel/ChatLog
@onready var player_input: LineEdit = $DialogCanvas/DialogRoot/Panel/PlayerInput
@onready var http_request: HTTPRequest = $HTTPRequest

var _player_in_range: Node2D = null
var _player_ref: Node2D = null
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


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = body
	if not _dialog_open:
		prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body != _player_in_range:
		return
	_player_in_range = null
	prompt_label.visible = false


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

	_open_dialog(_player_in_range)
	get_viewport().set_input_as_handled()


func _open_dialog(player: Node2D) -> void:
	_dialog_open = true
	_player_ref = player
	prompt_label.visible = false
	dialog_canvas.visible = true
	chat_log.clear()
	chat_log.append_text("[i]Converse com o sábio. Enter envia. Esc fecha.[/i]\n\n")
	_conversation.clear()
	player.set_physics_process(false)
	player_input.clear()
	player_input.grab_focus()


func _close_dialog() -> void:
	_dialog_open = false
	dialog_canvas.visible = false
	_waiting_api = false
	if _player_ref and is_instance_valid(_player_ref):
		_player_ref.set_physics_process(true)
	_player_ref = null
	if _player_in_range:
		prompt_label.visible = true


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
