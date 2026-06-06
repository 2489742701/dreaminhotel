# ==============================================================================
# AxeDoorBreakEffect.gd
# 斧头破门攻击效果
# 功能：实现斧头对封门木板的劈砍效果，与门控制系统交互
# 继承：WeaponAttackEffect - 武器攻击效果基类
# ==============================================================================

@tool
class_name AxeDoorBreakEffect
extends WeaponAttackEffect

# ==============================================================================
# 核心攻击方法重写
# ==============================================================================

# 重写目标检测方法，使用事件驱动的nearby_doors列表
func _detect_attack_targets(attacker: Node3D) -> Array[Node]:
	var valid_targets: Array[Node] = []
	
	# 1. 确保攻击者有记录列表
	if not attacker.get("nearby_doors"):
		print("斧头攻击效果：攻击者没有nearby_doors列表，使用备用检测方法")
		return _fallback_detect_targets(attacker)
	
	var candidates = attacker.nearby_doors
	if candidates.is_empty():
		print("斧头攻击效果：附近没有门")
		return valid_targets

	# 2. 筛选：防止砍到背后的门（暂时禁用方向检查）
	# 注释掉方向检查，允许攻击任何方向的门
	# var look_dir = Vector3.ZERO
	# if attacker.has_method("get_camera_forward"):
	# 	look_dir = attacker.get_camera_forward()
	# 	print("斧头攻击效果：使用get_camera_forward方法，方向: ", look_dir)
	# elif attacker.has_node("camera") and is_instance_valid(attacker.get_node("camera")):
	# 	var camera = attacker.get_node("camera")
	# 	# 由于相机被旋转了180度，需要修正方向
	# 	look_dir = camera.global_transform.basis.z
	# 	print("斧头攻击效果：使用相机方向（修正后），方向: ", look_dir)
	# else:
	# 	# 备用方案：使用攻击者自身的前方
	# 	look_dir = -attacker.global_transform.basis.z
	# 	print("斧头攻击效果：使用玩家自身方向，方向: ", look_dir)
	# 
	# look_dir = look_dir.normalized()
	
	for door in candidates:
		# 安全检查：确保门节点有效
		if not is_instance_valid(door):
			print("斧头攻击效果：检测到无效的门实例，跳过")
			continue
		
		# 计算从玩家到门的方向向量（暂时不需要用于方向检查）
		var to_door = door.global_position - attacker.global_position
		to_door = to_door.normalized()
		
		# 点乘计算夹角（暂时禁用方向检查）：
		# 结果 > 0 表示在前方，< 0 表示在身后
		# 结果 > 0.5 表示在视野正前方 60度 范围内（比较严格）
		# 结果 > 0.2 表示在视野前方宽范围（比较宽松）
		# var dot = look_dir.dot(to_door)
		# 
		# if dot > 0.4: # 调整这个数值：越大越难砍中（需要瞄得更准）
		# 	valid_targets.append(door)
		# else:
		# 	print("忽略背后的门: ", door.name, " 角度: ", dot)
		
		# 暂时允许攻击任何方向的门
		valid_targets.append(door)
		print("允许攻击门: ", door.name)
			
	print("斧头攻击效果：检测到", valid_targets.size(), "个可攻击目标")
	return valid_targets

# 备用检测方法（保持向后兼容）
func _fallback_detect_targets(attacker: Node3D) -> Array[Node]:
	var targets: Array[Node] = []
	
	# 通过攻击者获取场景树
	if not attacker or not is_instance_valid(attacker):
		push_error("斧头攻击效果：攻击者无效")
		return targets
	
	# 检查攻击者是否有场景树
	if not attacker.get_tree():
		push_error("斧头攻击效果：攻击者没有有效的场景树")
		return targets
	
	# 获取玩家附近的所有门控制系统
	var nearby_doors = []
	nearby_doors = attacker.get_tree().get_nodes_in_group("door_control")
	
	print("斧头攻击效果（备用）：找到", nearby_doors.size(), "个门控制系统")
	
	for door in nearby_doors:
		# 检查门的实例是否有效
		if not is_instance_valid(door):
			print("斧头攻击效果：检测到无效的门实例，跳过")
			continue
			
		# 检查玩家是否在门的交互区域内
		if door.has_method("has_player"):
			var has_player = false
			# 使用 GDScript 兼容的错误处理方式
			if is_instance_valid(door):
				has_player = door.has_player()
			else:
				print("斧头攻击效果：调用has_player方法失败，门：", door.name)
				continue
			
			print("斧头攻击效果：检查门", door.name, " - 有玩家:", has_player)
			if has_player:
				targets.append(door)
		else:
			print("斧头攻击效果：门", door.name, "没有has_player方法")
	
	return targets

# 重写攻击应用方法，直接调用门的劈砍方法
func _apply_attack_to_target(target: Node, _weapon: Item) -> bool:
	# 防御性编程：检查目标有效性
	if not is_instance_valid(target):
		push_error("斧头攻击效果：目标无效")
		return false
		
	# 检查武器有效性
	if not is_instance_valid(_weapon):
		push_error("斧头攻击效果：武器无效")
		return false
	
	# 检查目标是否是门控制系统
	if target.has_method("try_chop_planks"):
		print("斧头攻击效果：对目标", target.name, "应用劈砍攻击")
		# 直接调用门的劈砍方法，让门自己处理效果
		var result = false
		if is_instance_valid(target):
			result = target.try_chop_planks()
			print("斧头攻击效果：劈砍结果:", result)
		else:
			push_error("斧头攻击效果：调用try_chop_planks方法失败")
			return false
		return result
	else:
		print("斧头攻击效果：目标", target.name, "没有try_chop_planks方法")
	
	return false
