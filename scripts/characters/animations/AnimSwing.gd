# ==============================================================================
# AnimSwing.gd
# 斧子砍击动画资源类
# 功能：实现斧子砍击动画，完全复刻原hand_take.gd中的play_axe_swing_animation逻辑
# 继承：HandAnimation - 手持动画基类
# ==============================================================================

@tool
extends HandAnimation
class_name AnimSwing

# ==============================================================================
# 斧子动画参数（完全复刻原代码）
# ==============================================================================

# 斧子砍下角度（度，负值表示向下砍）
@export_group("斧子动画参数")
@export var 砍下角度: float = -45.0

# 动画总时长（秒）
@export var 动画时长: float = 0.3

# 下砍阶段时间比例
@export var 下砍比例: float = 0.6

# 回弹阶段时间比例  
@export var 回弹比例: float = 0.4

# ==============================================================================
# 核心动画方法
# ==============================================================================

# 应用斧子砍击动画
func apply(target: Node3D, tween: Tween, on_complete: Callable = Callable()) -> void:
    # 保存原始旋转（原代码逻辑）
    var original_rotation = target.rotation_degrees
    
    # 确保Tween是串行执行的
    tween.set_parallel(false)
    
    # 第一步：斧子砍下动作（围绕Z轴旋转，实现竖着往下砍）
    # 原代码: tween.tween_property(self, "rotation_degrees:z", 斧子砍下角度, 斧子动画时长 * 0.6)
    tween.tween_property(target, "rotation_degrees:z", 砍下角度, 动画时长 * 下砍比例)
    
    # 第二步：返回原位
    # 原代码: tween.tween_property(self, "rotation_degrees:z", original_rotation.z, 斧子动画时长 * 0.4)
    tween.tween_property(target, "rotation_degrees:z", original_rotation.z, 动画时长 * 回弹比例)
    
    # 动画完成回调
    if on_complete.is_valid():
        tween.tween_callback(on_complete)