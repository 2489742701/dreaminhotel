# ==============================================================================
# EffectWeaponDurability.gd
# 武器耐久度效果实现
# 这是一个具体的消耗品效果实现，用于处理武器的耐久度减少和损坏检测
# 继承自ConsumableEffect基类，展示了如何实现武器耐久度效果
# ==============================================================================

# @tool装饰器使此类可以在Godot编辑器中被实例化和预览
@tool

# 定义类名为EffectWeaponDurability
class_name EffectWeaponDurability

# 继承自ConsumableEffect基类
extends ConsumableEffect

# ========== 自定义属性 ==========

# 每次使用减少的耐久度值
@export_range(1, 10, 1) var 耐久度减少量 := 1

# 耐久度耗尽时的音效
@export var 损坏音效: AudioStream

# ========== 核心方法实现 ==========

# 实现父类的apply方法，定义具体的耐久度减少逻辑
func apply(_target: Node) -> void:
	# 安全检查：确保目标节点有装备武器的方法
	if not _target.has_method("get_equipped_item"):
		push_warning("目标节点没有get_equipped_item方法")
		return
	
	# 获取当前装备的物品
	var equipped_item = _target.get_equipped_item()
	if not equipped_item:
		push_warning("目标节点没有装备任何物品")
		return
	
	# 检查物品是否为武器类型
	if equipped_item.物品类型 != Item.Kind.WEAPON:
		push_warning("当前装备的物品不是武器类型")
		return
	
	# 减少武器耐久度
	reduce_weapon_durability(equipped_item)

# ========== 耐久度减少逻辑 ==========

# 减少武器耐久度
func reduce_weapon_durability(weapon: Item) -> void:
	# 检查是否支持方法调用方式的耐久度减少
	if weapon.has_method("reduce_durability"):
		# 如果武器有reduce_durability方法，调用它
		var success = weapon.reduce_durability(耐久度减少量)
		if success:
			print("武器耐久度减少", 耐久度减少量, "点")
		else:
			print("武器已损坏，无法使用")
			# 播放损坏音效
			play_damage_sound()
		return
	
	# 检查是否支持属性方式的耐久度减少
	if "耐久度" in weapon:
		var current_durability = weapon.耐久度
		var max_durability = weapon.最大耐久度 if "最大耐久度" in weapon else current_durability
		
		# 减少耐久度
		weapon.耐久度 = max(0, current_durability - 耐久度减少量)
		
		print("武器耐久度减少", 耐久度减少量, "点，剩余", weapon.耐久度, "/", max_durability)
		
		# 检查武器是否损坏
		if weapon.耐久度 <= 0:
			print("武器已损坏，无法使用")
			# 播放损坏音效
			play_damage_sound()
	else:
		# 如果武器没有耐久度系统，默认可以无限使用
		print("使用武器（无耐久度限制）")
	return

# ========== 音效播放 ==========

# 播放武器损坏音效
func play_damage_sound() -> void:
	if 损坏音效:
		# 这里可以添加音效播放逻辑
		# 例如：AudioStreamPlayer3D.play()
		pass

# ========== 工具方法 ==========

# 获取武器当前耐久度
func get_weapon_durability(weapon: Item) -> int:
	if "耐久度" in weapon:
		return weapon.耐久度
	return -1  # 表示没有耐久度系统

# 获取武器最大耐久度
func get_weapon_max_durability(weapon: Item) -> int:
	if weapon.has("最大耐久度"):
		return weapon.最大耐久度
	return get_weapon_durability(weapon)  # 如果没有最大耐久度，返回当前耐久度

# 检查武器是否损坏
func is_weapon_damaged(weapon: Item) -> bool:
	var durability = get_weapon_durability(weapon)
	return durability != -1 and durability <= 0