# ==============================================================================
# ConsumableEffect.gd
# 消耗品效果基类
# 这是一个资源类型的基类，用于定义各种消耗品(如药水、食物等)使用时产生的效果
# 其他具体效果类需要继承此类并实现apply方法
# ==============================================================================

# 定义类名为ConsumableEffect，方便在其他脚本中引用
class_name ConsumableEffect
# 继承自Resource类，表示这是一个可序列化的资源
extends Resource

# 消耗品使用时播放的音效
@export var use_sound: AudioStream

# 应用效果的核心方法
# 所有继承自ConsumableEffect的具体效果类都必须实现此方法
# @param _target: 效果作用的目标节点，通常是玩家节点
# @return: void
func apply(_target: Node) -> void:
	# 基类中仅抛出错误，提醒开发者需要在子类中实现具体逻辑
	push_error("未实现具体逻辑")
