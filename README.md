# Dream in Hotel

这是一个3D酒店探索游戏项目，使用Godot引擎开发。

## 项目简介

该项目是一个3D游戏，玩家可以在酒店环境中探索，与物品互动，管理体力，使用钥匙开门等。

## 主要功能

- 3D角色控制和动画系统
- 物品拾取和库存管理
- 体力系统和UI显示
- 钥匙和门交互系统
- 多语言支持

## 开发环境

- Godot Engine
- GDScript

## 项目结构

```
├── .gitattributes        # Git属性配置文件
├── .gitignore            # Git忽略文件配置
├── Global.gd             # 全局脚本文件
├── LICENSE               # 许可证文件
├── MainCharacter/        # 角色模型和纹理资源
│   ├── character.fbm/    # 角色材质和纹理文件
│   ├── character.fbx     # 角色3D模型
│   └── 角色动画帧序列    # 角色动画的PNG序列
├── MainCharacterAnimal/  # 动物角色动画
│   ├── Animation.tscn    # 动画场景
│   └── 各类动作FBX文件   # 呼吸、跳跃、跑步、走路等动作
├── MainCharacterplace/   # 玩家角色相关代码
│   ├── inventory.gd      # 背包系统脚本
│   ├── player.gd         # 玩家控制脚本
│   ├── player.tscn       # 玩家场景
│   └── skeleton_3d.gd    # 骨骼动画控制脚本
├── README.md             # 项目说明文档
├── StaminaUI.tscn        # 体力UI场景
├── Tr.gd                 # 翻译相关脚本
├── export_presets.cfg    # Godot导出配置
├── hotelpalce/           # 酒店场景和交互对象
│   ├── KeyPickup.tscn    # 钥匙拾取场景
│   ├── key_pickup.gd     # 钥匙拾取脚本
│   └── wall+door/        # 门和墙壁资源
│       ├── door.tscn     # 门场景
│       ├── doorcontrol.gd # 门控制脚本
│       ├── 门和墙壁.gltf  # 门和墙壁3D模型
│       └── 材质贴图       # 门和墙壁的纹理文件
├── icon.svg              # 项目图标
├── items/                # 物品系统
│   ├── DroppableItem.tscn # 可拾取物品场景
│   ├── InventoryGUI3D.gd  # 3D背包界面脚本
│   ├── Item.gd           # 物品基类脚本
│   ├── addons/           # 插件目录
│   ├── droppable_item.gd  # 可丢弃物品脚本
│   ├── effects/          # 物品效果
│   │   ├── ConsumableEffect.gd # 消耗品效果基类
│   │   └── EffectRestoreStamina.gd # 恢复体力效果
│   └── item/             # 物品定义文件
│       ├── drink.tres    # 饮料物品
│       └── key1.tres     # 钥匙物品
├── project.godot         # Godot项目主文件
├── stamina_ui.gd         # 体力UI控制脚本
└── translations/         # 多语言翻译
    └── items.csv         # 物品翻译文件

## 如何运行

1. 使用Godot引擎打开项目
2. 运行主场景开始游戏

## 许可证

MIT License