extends Area2D
## NPC Wise — diálogo com Gemini 2.5 Flash, lore acumulativo por progresso global.

## Contexto local da cena (tom, dicas). Lore desbloqueado vem de StoryState (autoload).
@export var fase_atual: int = 1
## No ninho do dragão: invisível e sem colisão até StoryState.dragao_derrotado.
@export var bloqueado_ate_dragao_derrotado: bool = false

const WiseLoreData = preload("res://data/wise_lore.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")

const GEMINI_URL := "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
## Gemini 2.5 Flash gasta tokens de "thinking" dentro de maxOutputTokens — 256 cortava a fala.
const MAX_OUTPUT_TOKENS := 512
const PROMPT_INTERACT := "▲ Interagir"
const PROMPT_BLOCKED := "Derrote os inimigos primeiro"
const DRAGAO_UNLOCK_DELAY := 2.0
const MSG_POS_BOSS := (
	"[color=yellow]Wise:[/color] O ar está leve outra vez. O Dragão Calórico caiu — "
	+ "pergunte o que quiser sobre o mundo; a história inteira está ao seu alcance.\n\n"
)

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt_label: Label = $PromptLabel
@onready var dialog_canvas: CanvasLayer = $DialogCanvas
@onready var chat_log: RichTextLabel = $DialogCanvas/DialogRoot/Panel/ChatLog
@onready var player_input: LineEdit = $DialogCanvas/DialogRoot/Panel/PlayerInput
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var _story: StoryStateScript = get_node("/root/StoryState")

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
	fase_atual = WiseLoreData.clamp_fase(fase_atual)
	_apply_unlock_state()
	if bloqueado_ate_dragao_derrotado and not _is_unlocked():
		_connect_boss_died()


func _connect_boss_died() -> void:
	for boss in get_tree().get_nodes_in_group("boss"):
		if boss.has_signal("died") and not boss.died.is_connected(_on_dragao_derrotado):
			boss.died.connect(_on_dragao_derrotado)


func _on_dragao_derrotado() -> void:
	await get_tree().create_timer(DRAGAO_UNLOCK_DELAY).timeout
	if not is_instance_valid(self):
		return
	_apply_unlock_state()


func _is_unlocked() -> bool:
	if not bloqueado_ate_dragao_derrotado:
		return true
	return _story.dragao_derrotado


func _apply_unlock_state() -> void:
	var unlocked := _is_unlocked()
	visible = unlocked
	monitoring = unlocked
	monitorable = unlocked
	set_process(unlocked)
	set_physics_process(unlocked)
	set_process_unhandled_input(unlocked)
	if _sprite:
		_sprite.visible = unlocked
	if not unlocked:
		_player_in_range = null
		prompt_label.visible = false
		if _dialog_open:
			_close_dialog()


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
	if not _is_unlocked():
		prompt_label.visible = false
		return
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
	if not _is_unlocked():
		return
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
	if not _is_unlocked():
		return
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
	if not _is_unlocked():
		return
	if _has_living_enemies():
		return
	_dialog_open = true
	prompt_label.visible = false
	dialog_canvas.visible = true
	chat_log.clear()
	chat_log.append_text("[i]Converse com o sábio. Enter envia. Esc fecha.[/i]\n\n")
	if _story.get_fase_efetiva() >= WiseLoreData.FASE_MAX:
		chat_log.append_text(MSG_POS_BOSS)
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
	_append_chat("[color=cyan]Você:[/color] " + _escape_bbcode(msg) + "\n")
	_request_gemini_reply(msg)


func _append_chat(bbcode: String) -> void:
	chat_log.append_text(bbcode)


func _build_system_instruction() -> String:
	var fase_desbloqueada: int = _story.get_fase_efetiva()
	var fase_cena := fase_atual
	if fase_desbloqueada >= WiseLoreData.FASE_MAX:
		fase_cena = WiseLoreData.FASE_MAX
	return WiseLoreData.build_system_instruction(fase_desbloqueada, fase_cena)


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
			"maxOutputTokens": MAX_OUTPUT_TOKENS,
			"temperature": 0.9,
			"thinkingConfig": {
				"thinkingBudget": 0,
			},
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
	var parsed := _extract_gemini_text(data)
	var reply: String = parsed.text
	if reply.is_empty():
		_append_chat("[color=orange]Resposta vazia da API.[/color]\n")
		return

	_conversation.append({
		"role": "model",
		"parts": [{"text": reply}],
	})
	var wise_line := "[color=yellow]Wise:[/color] " + _escape_bbcode(reply)
	if parsed.truncated:
		wise_line += " [i](resposta cortada pelo limite da API)[/i]"
	_append_chat(wise_line + "\n\n")


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


func _extract_gemini_text(data: Variant) -> Dictionary:
	var empty := {"text": "", "truncated": false}
	if typeof(data) != TYPE_DICTIONARY:
		return empty
	var err = data.get("error", null)
	if err is Dictionary:
		return {"text": "[Erro API] " + str(err.get("message", err)), "truncated": false}
	var candidates: Array = data.get("candidates", [])
	if candidates.is_empty():
		return empty
	var candidate: Dictionary = candidates[0]
	var finish_reason: String = str(candidate.get("finishReason", ""))
	var truncated := finish_reason == "MAX_TOKENS"
	var content: Dictionary = candidate.get("content", {})
	var parts: Array = content.get("parts", [])
	var texts: PackedStringArray = []
	for part in parts:
		if not part is Dictionary:
			continue
		if part.get("thought", false):
			continue
		var part_text: Variant = part.get("text", "")
		if part_text is String and not part_text.is_empty():
			texts.append(part_text)
	return {"text": "\n".join(texts), "truncated": truncated}
