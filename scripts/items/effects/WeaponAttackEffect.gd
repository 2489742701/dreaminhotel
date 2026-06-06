# ==============================================================================
# WeaponAttackEffect.gd
# 武器攻击效果基类
# 功能：定义武器攻击的基本接口和通用逻辑，支持与场景中其他节点的交互
# 继承：Resource - Godot资源类
# ==============================================================================

@tool
class_name WeaponAttackEffect
extends Resource

# ==============================================================================
# 核心攻击方法
# ==============================================================================

# 执行攻击效果
# @param attacker: 攻击者节点（通常是玩家）
# @param weapon: 武器物品
# @param _target: 攻击目标（可选，如果为空则自动检测）
func execute_attack(attacker: Node3D, weapon: Item, _target: Node = null) -> bool:
	# 安全检查
	if not attacker or not weapon:
		push_warning("攻击者或武器为空")
		return false
	
	# 播放攻击动画
	if not _play_attack_animation(attacker, weapon):
		return false
	
	# 检测攻击目标
	var targets = _detect_attack_targets(attacker)
	if targets.is_empty():
		print("没有检测到可攻击的目标")
		return false
	
	# 对每个目标应用攻击效果
	var hit_something = false
	for target_node in targets:
		if _apply_attack_to_target(target_node, weapon):
			hit_something = true
			# 播放命中效果
			_play_hit_effects(target_node)
	
	return hit_something

# ==============================================================================
# 子类需要重写的方法
# ==============================================================================

# 播放攻击动画（子类需要重写）
func _play_attack_animation(_attacker: Node3D, _weapon: Item) -> bool:
	# 默认实现：总是返回true，让子类处理具体动画
	return true

# 检测攻击范围内的目标（子类可以重写）
func _detect_attack_targets(_attacker: Node3D) -> Array[Node]:
	# 默认实现：返回空数组，让子类处理具体检测逻辑
	return []

# 对目标应用攻击效果（子类需要重写）
func _apply_attack_to_target(_target: Node, _weapon: Item) -> bool:
	# 默认实现：检查目标是否有可攻击的接口
	if _target.has_method("take_damage"):
		_target.take_damage(1)  # 默认攻击力为1
		return true
	
	return false

# 播放命中效果
func _play_hit_effects(_target: Node) -> void:
	# 默认实现：空方法，让子类处理具体效果
	pass