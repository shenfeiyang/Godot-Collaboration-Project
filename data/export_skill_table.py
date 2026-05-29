"""
技能表导入脚本 —— 从 execl/skill.xlsx 生成 Godot .tres 资源。

用法:
    python data/export_skill_table.py

产出:
    abilities/skills/generated/
        skArt_*.tres   (SkillArtConfig)
        skPar_*.tres   (SkillParamPack)
        skTrig_*.tres  (TriggerConfig)
        skPas_*.tres   (PassiveConfig)
        skDef_*.tres   (SkillDefinition)
        skBuf_*.tres   (BuffConfig)
"""

from __future__ import annotations

from pathlib import Path
import sys
import os

# 确保能找到同目录下的 export_tables.py
sys.path.insert(0, str(Path(__file__).resolve().parent))
from export_tables import load_sheet_rows

PROJECT_ROOT = Path(__file__).resolve().parents[1]
EXCEL_PATH = PROJECT_ROOT / "execl" / "skill.xlsx"
OUTPUT_DIR = PROJECT_ROOT / "abilities" / "skills" / "generated"

# ── 脚本路径常量 ──
SKILL_DEF_SCRIPT = "res://abilities/skills/definitions/skill_definition.gd"
SKILL_ART_SCRIPT = "res://abilities/skills/definitions/skill_art_config.gd"
SKILL_PARAM_SCRIPT = "res://abilities/skills/definitions/skill_param_pack.gd"
TRIGGER_SCRIPT = "res://abilities/skills/definitions/trigger_config.gd"
PASSIVE_SCRIPT = "res://abilities/skills/definitions/passive_config.gd"
BUFF_CONFIG_SCRIPT = "res://scripts/stats/buff_config.gd"
FIRE_EFFECT_SCRIPT = "res://abilities/skills/definitions/fire_projectile_effect_config.gd"


def escape(s: str) -> str:
    """转义字符串中的特殊字符用于 .tres"""
    return s.replace("\\", "\\\\").replace('"', '\\"')


def write_tres(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"  ✓ {path.name}")


# ────────────────────── skillArt ──────────────────────

def build_skill_art_tres(row: dict) -> str:
    art_id = row.get("artPackId", "")
    lines = [
        '[gd_resource type="Resource" script_class="SkillArtConfig" format=3]',
        "",
        f'[ext_resource type="Script" path="{SKILL_ART_SCRIPT}" id="1_script"]',
        "",
        "[resource]",
        'script = ExtResource("1_script")',
        f'art_pack_id = &"{art_id}"',
        f'icon_key = "{escape(row.get("icon", ""))}"',
        f'effect_key = "{escape(row.get("effect", ""))}"',
        f'sound_key = "{escape(row.get("sound", ""))}"',
        "",
    ]
    return "\n".join(lines)


def parse_int(raw: str, default: int = 0) -> int:
    if not raw or not raw.strip():
        return default
    try:
        return int(float(raw))
    except ValueError:
        return default


# ────────────────────── skillParam ──────────────────────

def build_skill_param_tres(row: dict) -> str:
    param_id = row.get("paramPackId", "")
    lines = [
        '[gd_resource type="Resource" script_class="SkillParamPack" format=3]',
        "",
        f'[ext_resource type="Script" path="{SKILL_PARAM_SCRIPT}" id="1_script"]',
        "",
        "[resource]",
        'script = ExtResource("1_script")',
        f'param_pack_id = &"{param_id}"',
        f"dmg_rate = {parse_int(row.get('dmgRate', '10000'), 10000)}",
        f"cd_ms = {parse_int(row.get('cd', '0'))}",
        f"seek_range = {parse_int(row.get('seekRange', '0'))}",
        f'target_search = "{escape(row.get("targetSearch", "NearU"))}"',
        f"scale = {parse_int(row.get('scale', '10000'), 10000)}",
        f"space = {parse_int(row.get('space', '0'))}",
        f"bullet_num = {parse_int(row.get('bulletNum', '1'), 1)}",
        f"atk_num = {parse_int(row.get('atkNum', '1'), 1)}",
        f"bullet_speed = {parse_int(row.get('bulletSpeed', '0'))}",
        f"pierc = {parse_int(row.get('pierc', '0'))}",
        f"duration_ms = {parse_int(row.get('durationMS', '0'))}",
        f"cd_open = {parse_int(row.get('cdOpen', '0'))}",
        f'repel = "{escape(row.get("repel", ""))}"',
        f"impact_count = {parse_int(row.get('impactCount', '0'))}",
        f"impact_interval_ms = {parse_int(row.get('impactIntervalMS', '0'))}",
        "",
    ]
    return "\n".join(lines)


# ────────────────────── skillTrig ──────────────────────

def build_trigger_tres(row: dict) -> str:
    trig_id = row.get("triggerPackId", "")
    lines = [
        '[gd_resource type="Resource" script_class="TriggerConfig" format=3]',
        "",
        f'[ext_resource type="Script" path="{TRIGGER_SCRIPT}" id="1_script"]',
        "",
        "[resource]",
        'script = ExtResource("1_script")',
        f'trigger_pack_id = &"{trig_id}"',
        f"order = {parse_int(row.get('order', '1'), 1)}",
        f'trigger_event = "{escape(row.get("triggerEvent", "Trig_Hit"))}"',
        f"trig_param = {parse_int(row.get('trigPar01', '1'), 1)}",
        f'trigger_skill_id = &"{row.get("triggerSkillId", "")}"',
        f"trigger_delay_ms = {parse_int(row.get('triggerDelayMS', '0'))}",
        f"max_trigger_count = {parse_int(row.get('maxTriggerCount', '0'))}",
        "",
    ]
    return "\n".join(lines)


# ────────────────────── skillPas ──────────────────────

def build_passive_tres(row: dict) -> str:
    pid = row.get("passiveId", "")
    lines = [
        '[gd_resource type="Resource" script_class="PassiveConfig" format=3]',
        "",
        f'[ext_resource type="Script" path="{PASSIVE_SCRIPT}" id="1_script"]',
        "",
        "[resource]",
        'script = ExtResource("1_script")',
        f'passive_id = &"{pid}"',
        f'display_name = "{escape(row.get("name", ""))}"',
        f'description = "{escape(row.get("desc", ""))}"',
        f'source_type = "{escape(row.get("sourceType", ""))}"',
        f'trigger_event = "{escape(row.get("triggerEvent", ""))}"',
        f'trigger_condition = "{escape(row.get("triggerCondition", ""))}"',
        f'effect_type = "{escape(row.get("effectType", ""))}"',
        f'target_rule = "{escape(row.get("targetRule", ""))}"',
        f'param1 = "{escape(row.get("param1", ""))}"',
        f'param2 = "{escape(row.get("param2", ""))}"',
        f"duration_ms = {parse_int(row.get('durationMS', '0'))}",
        f"max_stack = {parse_int(row.get('maxStack', '0'))}",
        f'stack_rule = "{escape(row.get("stackRule", ""))}"',
        f'tags = "{escape(row.get("tags", ""))}"',
        f'remark = "{escape(row.get("remark", ""))}"',
        "",
    ]
    return "\n".join(lines)


# ────────────────────── skill main ──────────────────────

def build_skill_definition_tres(row: dict) -> str:
    skill_id = row.get("skillId", "")
    param_pack_id = row.get("paramPackId", "").strip()
    lines = [
        '[gd_resource type="Resource" script_class="SkillDefinition" format=3]',
        "",
        f'[ext_resource type="Script" path="{SKILL_DEF_SCRIPT}" id="1_script"]',
        f'[ext_resource type="Script" path="{FIRE_EFFECT_SCRIPT}" id="2_fire_effect"]',
    ]
    next_ext_id = 3
    # 如果有参数包，加上 ExtResource 引用
    if param_pack_id:
        param_path = f"res://abilities/skills/generated/{param_pack_id}.tres"
        lines.append(f'[ext_resource type="Resource" path="{param_path}" id="{next_ext_id}_param_pack"]')
        next_ext_id += 1
    # 生成一个最小效果的 SubResource，技能运行时通过它触发发射
    lines.append("")
    lines.append('[sub_resource type="Resource" id="effect_1"]')
    lines.append('script = ExtResource("2_fire_effect")')
    lines.append("")
    lines.extend([
        "[resource]",
        'script = ExtResource("1_script")',
        f'skill_id = &"{skill_id}"',
        f'display_name = "{escape(row.get("name", ""))}"',
        f'tier = "{escape(row.get("tier", "MainSk"))}"',
        f'caster = "{escape(row.get("caster", "Player"))}"',
        f'main_tag = "{escape(row.get("mainTag", ""))}"',
        f'sub_tag = "{escape(row.get("subTag", ""))}"',
        f'dmg_tag = "{escape(row.get("DmgTag", "Phys"))}"',
        f'art_pack_id = &"{row.get("sound", "")}"',
        f'param_pack_id = &"{param_pack_id}"',
        f'trigger_pack_id = &"{row.get("triggerPackId", "")}"',
        f'buff_pack_id = &"{row.get("buffPackId", "")}"',
    ])
    if param_pack_id:
        ext_id = 3  # 因为 next_ext_id 从 3 开始
        lines.append(f'param_pack = ExtResource("{ext_id}_param_pack")')
    # effects 数组引用上面的 SubResource
    lines.append('effects = Array[Resource]([SubResource("effect_1")])')
    lines.append("cooldown = 0.0")
    lines.append("")
    return "\n".join(lines)


# ────────────────────── skillBuff ──────────────────────

def build_buff_tres(row: dict) -> str:
    # 按 BuffConfig 现有结构生成
    buf_id = row.get("buffPackId", "")
    buf_name = row.get("buffName", "")
    lines = [
        '[gd_resource type="Resource" script_class="BuffConfig" format=3]',
        "",
        f'[ext_resource type="Script" path="{BUFF_CONFIG_SCRIPT}" id="1_script"]',
        "",
        "[resource]",
        'script = ExtResource("1_script")',
        f'buff_id = &"{buf_id}"',
        f'display_name = "{escape(buf_name)}"',
        f"duration = {parse_int(row.get('durationMS', '0')) / 1000.0:.1f}",
        "",
    ]
    return "\n".join(lines)


# ────────────────────── 主流程 ──────────────────────

FIELD_MAP = {
    # 英文字段名所在行号（1-indexed）
    "skillArt": {
        "header_row": 5,
        "key_col": "artPackId",
        "builder": build_skill_art_tres,
        "prefix": "skArt_",
        "desc": "技能美术包",
    },
    "skillParam": {
        "header_row": 5,
        "key_col": "paramPackId",
        "builder": build_skill_param_tres,
        "prefix": "skPar_",
        "desc": "技能参数包",
    },
    "skillTrig": {
        "header_row": 4,
        "key_col": "triggerPackId",
        "builder": build_trigger_tres,
        "prefix": "skTrig_",
        "desc": "技能触发包",
    },
    "skillPas": {
        "header_row": 4,
        "key_col": "passiveId",
        "builder": build_passive_tres,
        "prefix": "skPas_",
        "desc": "被动效果",
    },
    "skill": {
        "header_row": 5,
        "key_col": "skillId",
        "builder": build_skill_definition_tres,
        "prefix": "skDef_",
        "desc": "技能定义",
    },
    "skillBuff": {
        "header_row": 4,
        "key_col": "buffPackId",
        "builder": build_buff_tres,
        "prefix": "skBuf_",
        "desc": "技能Buff",
    },
}


def build_header_map(header_row: list[str]) -> dict[str, int]:
    """将表头行映射为 {字段名: 列索引}"""
    mapping = {}
    for idx, val in enumerate(header_row):
        key = val.strip()
        if key:
            mapping[key] = idx
    return mapping


def row_to_dict(header_map: dict[str, int], row: list[str]) -> dict[str, str]:
    """将一行数据按表头映射转为字典"""
    result = {}
    for field_name, col_idx in header_map.items():
        if col_idx < len(row):
            val = row[col_idx].strip()
            result[field_name] = val
        else:
            result[field_name] = ""
    return result


def export_sheet(sheet_name: str, config: dict) -> int:
    """导出单个 sheet，返回导出文件数"""
    print(f"\n[{config['desc']}] {sheet_name} ...")
    rows = load_sheet_rows(EXCEL_PATH, sheet_name)
    if not rows:
        print(f"  ⚠ 空 sheet，跳过")
        return 0

    # header_row 指向英文字段名所在行（1-indexed），转为 0-index
    header_idx = config["header_row"] - 1
    if header_idx >= len(rows):
        print(f"  ⚠ 找不到表头行 (row {config['header_row']})，跳过")
        return 0

    # 用英文字段名行构建字段名→列索引映射
    header_map = build_header_map(rows[header_idx])
    if not header_map:
        print(f"  ⚠ 表头为空，跳过")
        return 0
    key_col = config["key_col"]
    if key_col not in header_map:
        print(f"  ⚠ 表头中找不到主键列 '{key_col}'，可用字段: {list(header_map.keys())}")
        return 0

    export_count = 0
    # 数据从 字段名行 + 类型行 之后开始（+2）
    for row in rows[header_idx + 2:]:
        if not row or len(row) < 2:
            continue
        data = row_to_dict(header_map, row)
        key_val = data.get(key_col, "").strip()
        if not key_val:
            continue

        content = config["builder"](data)
        fname = f"{key_val}.tres"
        write_tres(OUTPUT_DIR / fname, content)
        export_count += 1

    return export_count


def export_all() -> None:
    print("=" * 60)
    print("skill.xlsx → .tres 导入开始")
    print(f"来源: {EXCEL_PATH}")
    print(f"输出: {OUTPUT_DIR}")
    print("=" * 60)

    total = 0
    for sheet_name, config in FIELD_MAP.items():
        count = export_sheet(sheet_name, config)
        total += count

    print(f"\n{'=' * 60}")
    print(f"完成！共导出 {total} 个资源文件到 {OUTPUT_DIR}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    export_all()
