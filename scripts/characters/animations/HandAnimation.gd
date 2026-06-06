# ==============================================================================
# HandAnimation.gd
# 手持动画基类
# 功能：所有手持动画资源的基类，定义统一的动画接口
# 继承：Resource - Godot的资源类
# ==============================================================================

@tool
extends Resource
class_name HandAnimation

# ==============================================================================
# 核心动画方法
# ==============================================================================

# 应用动画到目标节点
# @param target: 做动画的物体 (HandTake/MeshInstance3D)
# @param tween: 传入的 Tween 对象
# @param on_complete: 动画完成后的回调（可选）
func apply(_target: Node3D, _tween: Tween, on_complete: Callable = Callable()) -> void:
    # 基类只需要定义接口，具体逻辑由子类实现
    push_error("HandAnimation.apply() 方法必须在子类中实现")
    if on_complete.is_valid():
        on_complete.call()