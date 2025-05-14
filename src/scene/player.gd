class_name Player
extends Node2D


enum StateName {
	NORMAL, #普通状态
	SKILL #施放技能状态
}

@onready var state_node: StateNode = $StateNode
@onready var skill_actuator: SkillActuator = $SkillActuator
@onready var move_controller: PlatformController = $PlatformController

@onready var body: CharacterBody2D = $body
@onready var animated_sprite: AnimatedSprite2D = $body/AnimatedSprite2D
@onready var state_label: Label = $body/StateLabel

# 添加状态
@onready var normal_state : StateNode = state_node.add_state(StateName.NORMAL)
@onready var skill_state : StateNode = state_node.add_state(StateName.SKILL)

var _skill_queue : Array = []


func _ready() -> void:
	# 普通状态时的控制
	normal_state.entered_state.connect(
		func(data): update_normal_anim()
	)
	normal_state.state_processed.connect(
		func():
			var v = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
			move_controller.move_direction(v)
	)
	# 默认进入普通状态
	state_node.enter_child_state(StateName.NORMAL)
	
	# 更新头顶状态文字
	state_node.child_state_changed.connect(
		func(previous, current, data):
			state_label.text = str(StateName.find_key(current))
	)
	state_label.text = "NORMAL"
	
	# 执行一个技能需要经过的几个阶段
	skill_actuator.set_stages([SkillStage.READY, SkillStage.EXECUTE, SkillStage.COOLDOWN] ) 
	# 添加技能
	skill_actuator.add_skill(SkillName.sword_a, {SkillStage.COOLDOWN: 4})
	skill_actuator.add_skill(SkillName.sword_b, {SkillStage.COOLDOWN: 2.5})
	
	# 每个技能结束时，自动执行下一个
	skill_actuator.ended.connect(
		func(skill_name: StringName, tag: StringName):
			if skill_name in skill_data:
				_execute_next_skill()
	)
	
	# 更新普通状态播放的动画
	update_normal_anim()

## 更新普通状态下的动画
func update_normal_anim():
	if normal_state.is_running():
		if move_controller.is_moving():
			animated_sprite.play("剑_跑步")
		else:
			animated_sprite.play("剑_站立")

## 面部朝向
func get_face_direction() -> Vector2:
	return animated_sprite.scale


## 执行技能组的名称
func execute_skill(skill_name: String):
	if normal_state.is_running():
		if skill_actuator.is_can_execute(skill_name):
			skill_actuator.execute(skill_name)
			# 切换到执行技能状态
			state_node.trans_to_child(StateName.SKILL)
			# 这个技能执行具体效果的小技能组
			match skill_name:
				SkillName.sword_a:
					_skill_queue.append("剑_螺旋刺")
					_skill_queue.append("剑_螺旋刺_循环")
					_skill_queue.append("剑_螺旋刺_结束")
				SkillName.sword_b:
					_skill_queue.append("技能_龙卷风")
					_skill_queue.append("技能_龙卷风_旋转")
					_skill_queue.append("技能_龙卷风_结束")
			# 开始执行小技能组
			_execute_next_skill()
		else:
			print_debug(skill_name, " 技能正在冷却中，剩余时间：", skill_actuator.get_skill(skill_name).get_time_left())

# 技能所需消耗的时间的数据
@onready var skill_data = {
	"剑_螺旋刺": { SkillStage.EXECUTE: _get_sprite_frame_time("剑_螺旋刺"), },
	"剑_螺旋刺_循环": {SkillStage.EXECUTE: 0.5, },
	"剑_螺旋刺_结束": {SkillStage.EXECUTE: _get_sprite_frame_time("剑_螺旋刺_结束"), },
	
	"技能_龙卷风": {SkillStage.EXECUTE: _get_sprite_frame_time("技能_龙卷风"), },
	"技能_龙卷风_旋转": {SkillStage.EXECUTE: 1, },
	"技能_龙卷风_结束": {SkillStage.EXECUTE: _get_sprite_frame_time("技能_龙卷风_结束"), },
}

func _get_sprite_frame_time(anim: String) -> float:
	var sf : SpriteFrames = animated_sprite.sprite_frames
	var time = 1.0 / sf.get_animation_speed(anim)
	var count = sf.get_frame_count(anim)
	return time * count

func _execute_next_skill():
	if _skill_queue.is_empty():
		# 执行完了所有的小技能组，则此次技能执行完
		state_node.trans_to_child(StateName.NORMAL)
		return
	# 执行这组技能中的小块技能
	var skill_name = _skill_queue.pop_front()
	if not skill_actuator.has_skill(skill_name):
		skill_actuator.add_skill(skill_name)
		# 这个技能执行的时间线，对技能实现具体的执行细节
		var skill_node : TimeLine = skill_actuator.get_skill(skill_name)
		skill_node.executed_stage.connect(
			func(stage, data: Dictionary):
				# 播放动画
				if stage == SkillStage.EXECUTE:
					animated_sprite.play(skill_name)
				# 开始实现技能效果
				var duration = data.get(SkillStage.EXECUTE, 0)
				match skill_name:
					"剑_螺旋刺_循环":
						match stage:
							SkillStage.READY:
								move_controller.gravity_enabled = false
							SkillStage.EXECUTE:
								var skill_process = SkillProcess.new()
								skill_process.name = skill_name
								skill_process.duration = duration
								var direction = get_face_direction()
								direction.x *= 300
								skill_process.callback = func():
									body.velocity = direction
									body.move_and_slide()
							SkillStage.COOLDOWN:
								move_controller.gravity_enabled = true
					
					"技能_龙卷风_旋转":
						match stage:
							SkillStage.EXECUTE:
								var skill_process = SkillProcess.new()
								skill_process.name = skill_name
								skill_process.duration = duration
								var direction = get_face_direction()
								direction.x *= 100
								skill_process.callback = func():
									body.velocity = direction
									body.move_and_slide()
		)
	var data : Dictionary = skill_data.get(skill_name) # 获取技能每个阶段执行完所需时间数据
	skill_actuator.execute(skill_name, data) # 执行


# 技能线程
class SkillProcess:
	extends Node
	
	var callback : Callable
	var duration : float
	var _time = 0
	
	func _init() -> void:
		Engine.get_main_loop().current_scene.add_child(self, true)
	
	func _process(delta: float) -> void:
		callback.call()
		_time += delta
		if _time >= duration:
			queue_free()
			return


#===========================================================
# 连接信号
#===========================================================
func _on_platform_controller_direction_changed(direction: Vector2) -> void:
	animated_sprite.scale.x = direction.x

func _on_platform_controller_move_state_changed(state: bool) -> void:
	update_normal_anim()
