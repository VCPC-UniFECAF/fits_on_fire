class_name UiMenuFocus
extends RefCounted

const CONFIRM_ACTION := "confirm"


static func collect_buttons(container: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	for child in container.get_children():
		if child is Button and child.visible:
			buttons.append(child)
	return buttons


static func link_vertical(buttons: Array[Button]) -> void:
	for i in buttons.size():
		if i > 0:
			buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[i - 1])
		if i < buttons.size() - 1:
			buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[i + 1])


static func grab_first(buttons: Array[Button]) -> void:
	for button in buttons:
		if button.visible:
			button.grab_focus()
			return


static func handle_confirm(event: InputEvent, viewport: Viewport) -> bool:
	if viewport == null or not event.is_action_pressed(CONFIRM_ACTION):
		return false
	var focus_owner := viewport.gui_get_focus_owner()
	if focus_owner is Button and focus_owner.is_visible_in_tree():
		viewport.set_input_as_handled()
		focus_owner.emit_signal("pressed")
		return true
	return false
