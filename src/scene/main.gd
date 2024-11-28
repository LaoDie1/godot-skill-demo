extends Node


@onready var player: Player = $Player


func _on_skill_a_pressed() -> void:
	player.execute_skill(SkillName.sword_a)

func _on_skill_b_pressed() -> void:
	player.execute_skill(SkillName.sword_b)
