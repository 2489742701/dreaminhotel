# ==============================================================================
# EffectRestoreStamina.gd
# 体力恢复效果
# 继承自ConsumableEffect基类，实现了消耗品使用时恢复角色体力的功能
# @tool标记表示此类可以在编辑器中使用
# ==============================================================================

# @tool装饰器使此类可以在Godot编辑器中被实例化和预览
@tool
# 定义类名为EffectRestoreStamina，方便在其他脚本中引用
class_name EffectRestoreStamina
# 继承自ConsumableEffect基类，获得基础消耗品效果功能
extends ConsumableEffect

# 恢复的体力百分比，范围为0-100%
# @export_range装饰器限制了值的范围，并设置步长为1
@export_range(0,100,1) var percent := 20.0

# 实现父类的apply方法，定义具体的体力恢复逻辑
# @param _target: 效果作用的目标节点，通常是玩家节点
# @return: void
func apply(_target: Node) -> void:
	# 从目标节点获取StaminaComponent子节点，并调用其add_stamina_percent方法
	# 传入percent参数，增加目标的体力值
	_target.get_node("StaminaComponent").add_stamina_percent(percent)
