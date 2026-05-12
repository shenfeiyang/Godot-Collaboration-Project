# 项目文件目录说明

> 项目类型：2D 肉鸽随机刷宝游戏  
> 引擎版本：Godot 4.x  
> 脚本语言：GDScript

---

## 一、设计原则

1. &zwnj;**场景中心化**&zwnj;  
   每个角色、怪物、UI 面板的资源（脚本、贴图、音效）就近存放在各自的文件夹内，保持场景的自包含性，避免所有资源堆在一个全局目录里。

2. &zwnj;**数据配置分离**&zwnj;  
   所有数值（掉落率、流派伤害系数、怪物属性等）抽离到 `data/` 目录，用 JSON 管理。调整平衡性时只需改配置，无需触碰代码。

3. &zwnj;**命名规范统一**&zwnj;  
   文件和文件夹统一使用 `snake_case` 蛇形命名法（如 `enemy_ai.gd`、`health_potion.tscn`），避免 Windows/macOS 与 Linux 之间的大小写敏感问题。

4. &zwnj;**资源路径规范**&zwnj;  
   - `res://` 始终指向项目根目录（`project.godot` 所在位置），所有资源引用使用此前缀。
   - 导出后文件系统变为只读，需要写入的数据（存档、设置）使用 `user://` 路径。

---

## 二、完整目录结构

project_root/ # 项目根目录
├── project.godot # Godot 项目入口文件（定义根目录位置）
│
├── scenes/ # 主场景文件
│ ├── main_menu.tscn # 主菜单
│ ├── game_world.tscn # 核心战斗/探索场景
│ └── game_over.tscn # 结算界面
│
├── characters/ # 角色相关（场景+脚本+资源打包）
│ ├── player/
│ │ ├── player.tscn # 玩家场景
│ │ ├── player.gd # 玩家控制脚本
│ │ ├── textures/ # 玩家专属贴图
│ │ └── sfx/ # 玩家专属音效
│ ├── enemies/ # 怪物
│ │ ├── slime/
│ │ │ ├── slime.tscn
│ │ │ ├── slime.gd
│ │ │ └── textures/
│ │ └── boss_dragon/
│ │ ├── boss_dragon.tscn
│ │ ├── boss_dragon.gd
│ │ └── textures/
│ └── npcs/ # 功能性 NPC
│
├── loot_system/ # 刷宝核心：掉落物与装备
│ ├── items/ # 物品场景（武器、防具、消耗品）
│ │ ├── sword_01.tscn
│ │ └── health_potion.tscn
│ ├── item_base.gd # 物品基类脚本
│ └── loot_table.gd # 掉落逻辑脚本
│
├── roguelike_builds/ # 肉鸽流派构筑
│ ├── elements/ # 元素流派（电、毒、火等）
│ │ ├── electric_build.gd
│ │ └── poison_build.gd
│ └── buffs/ # Buff/Debuff 场景或脚本
│
├── ui/ # 用户界面
│ ├── hud/
│ │ ├── hud.tscn # 战斗 HUD
│ │ └── health_bar.gd
│ ├── inventory/ # 背包系统
│ │ ├── inventory_panel.tscn
│ │ └── item_slot.gd
│ └── meta_progression/ # 局外养成界面
│ └── talent_tree.tscn
│
├── data/ # 数值配置（只改 JSON，不动代码）
│ ├── items.json # 所有物品属性
│ ├── enemies.json # 怪物血量、攻击力
│ ├── loot_tables.json # 掉落概率表
│ └── build_coefficients.json # 流派伤害系数
│
├── scripts/ # 全局通用脚本
│ ├── autoload/ # 单例 / 自动加载脚本
│ │ ├── game_manager.gd # 游戏流程控制
│ │ ├── audio_manager.gd # 音频管理
│ │ └── data_manager.gd # 读取 data/ 中的 JSON 配置
│ └── utils/ # 工具函数库
│ └── math_helper.gd
│
├── shaders/ # 着色器（技能特效、屏幕震动等）
│ └── hit_flash.gdshader
│
├── assets/ # 跨场景共用的全局资源
│ ├── fonts/
│ ├── music/
│ └── ui_themes/ # UI 主题
│
├── addons/ # Godot 插件（如有）
│
└── docs/ # 设计文档
├── game_design_brief.md # 核心玩法设计摘要
├── system_spec.md # 系统详细规格说明
└── open_questions.md # 待决策的设计问题清单

---

## 三、各目录职责详解

### 3.1 `scenes/` — 主场景

存放游戏的顶层场景文件，每个场景对应一个完整的游戏状态（菜单、战斗中、结算）。场景内通过实例化 `characters/`、`ui/` 等子目录中的子场景来组装。

### 3.2 `characters/` — 角色

采用「一个角色一个文件夹」的组织方式，每个文件夹内包含该角色的场景文件、脚本、贴图和音效。新增怪物时只需在 `enemies/` 下新建文件夹即可，不会影响其他角色。

### 3.3 `loot_system/` — 掉落与装备

刷宝游戏的核心模块。`item_base.gd` 定义所有物品的通用行为（拾取、使用、丢弃），`loot_table.gd` 负责根据 `data/loot_tables.json` 中的概率配置生成掉落。

### 3.4 `roguelike_builds/` — 流派构筑

存放不同流派（电系、毒系、火系等）的逻辑脚本。每个流派独立一个文件，通过信号或组合的方式挂载到玩家身上。新增流派时只需在此目录添加新脚本，不会污染现有代码。

### 3.5 `ui/` — 用户界面

按功能模块拆分为 HUD、背包、局外养成等子目录。每个 UI 面板的场景和脚本放在一起，便于独立开发和调试。

### 3.6 `data/` — 数值配置

所有游戏数值以 JSON 格式存储在此目录。`data_manager.gd`（位于 `scripts/autoload/`）负责在游戏启动时加载这些配置，其他脚本通过它读取数据。调整平衡性时只需修改 JSON 文件，无需重新编译。

### 3.7 `scripts/` — 全局脚本

- &zwnj;**`autoload/`**&zwnj;：存放 Godot 的 Autoload 单例脚本，随游戏启动自动加载，负责全局状态管理。
- &zwnj;**`utils/`**&zwnj;：存放可复用的工具函数，如数学计算、随机数生成等。

### 3.8 `shaders/` — 着色器

存放自定义着色器文件（`.gdshader`），用于实现技能特效、受击闪白、屏幕震动等视觉效果。

### 3.9 `assets/` — 全局资源

存放跨多个场景共用的资源，如字体、背景音乐、UI 主题。仅用于确实无法归属到具体场景的通用资源。

### 3.10 `docs/` — 设计文档

记录游戏的设计意图、系统规格和待决策问题。`open_questions.md` 用于汇总开发过程中遇到的设计疑问，集中处理，避免方向跑偏。

---

## 四、文件命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 文件夹 | `snake_case` | `enemy_ai/`、`loot_system/` |
| GDScript 文件 | `snake_case` | `player.gd`、`health_bar.gd` |
| 场景文件 | `snake_case` | `game_world.tscn`、`main_menu.tscn` |
| JSON 配置文件 | `snake_case` | `items.json`、`loot_tables.json` |
| 贴图/音效 | `snake_case` | `idle.png`、`hit_sound.wav` |
| 场景节点（编辑器内） | `PascalCase` | `HitBox`、`AnimationPlayer` |

---

## 五、肉鸽刷宝游戏特别说明

1. &zwnj;**流派扩展**&zwnj;：新增流派时，在 `roguelike_builds/elements/` 下添加新脚本，并在 `data/build_coefficients.json` 中配置对应系数即可，无需改动战斗核心逻辑。

2. &zwnj;**掉落配置**&zwnj;：所有物品的掉落概率、稀有度权重统一在 `data/loot_tables.json` 中管理，支持按关卡、怪物类型配置不同的掉落表。

3. &zwnj;**局外养成**&zwnj;：天赋树、永久升级等局外养成系统的 UI 场景放在 `ui/meta_progression/`，相关数值配置可扩展 `data/` 目录下的 JSON 文件。

4. &zwnj;**快速迭代**&zwnj;：调整「爽感」时，优先修改 `data/` 中的数值文件；调整「手感」时，优先修改对应角色文件夹内的脚本。两者互不干扰。

---

## 六、版本控制建议

- `project.godot`、所有 `.tscn`、`.gd`、`.json` 文件应纳入 Git 管理。
- `.import/` 目录由 Godot 自动生成，无需手动管理，建议加入 `.gitignore`。
- 大型二进制资源（高清贴图、音频）可考虑使用 Git LFS 管理。
- 从 Godot 编辑器的文件系统面板中进行移动、重命名操作，避免手动操作导致引用断裂。
