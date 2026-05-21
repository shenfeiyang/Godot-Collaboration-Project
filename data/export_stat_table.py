from __future__ import annotations

from pathlib import Path
from zipfile import ZipFile
import xml.etree.ElementTree as ET

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_XLSX = PROJECT_ROOT / "execl" / "属性表.xlsx"
OUTPUT_DIR = PROJECT_ROOT / "assets" / "stats" / "generated"
UNIT_STATS_CONFIG_SCRIPT = "res://scripts/stats/unit_stats_config.gd"

NS = {
    "main": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "rel": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "pkg_rel": "http://schemas.openxmlformats.org/package/2006/relationships",
}

STAT_FIELD_MAP = {
    "HPMax": "max_hp",
    "Atk": "attack",
    "Def": "defense",
    "CritRate": "crit_rate",
    "CritDamage": "crit_damage",
    "AS": "attack_speed",
    "PhysicalDamageBonus": "physical_damage_bonus",
    "WindDamageBonus": "wind_damage_bonus",
    "FireDamageBonus": "fire_damage_bonus",
    "IceDamageBonus": "ice_damage_bonus",
    "LightningDamageBonus": "lightning_damage_bonus",
    "LightDamageBonus": "light_damage_bonus",
    "DarkDamageBonus": "dark_damage_bonus",
}

DEFAULT_PLAYER_VALUES = {
    "max_energy": 100.0,
    "energy_regen": 10.0,
    "move_speed": 120.0,
    "crit_rate": 0.05,
    "crit_damage": 0.5,
    "physical_damage_bonus": 0.0,
    "wind_damage_bonus": 0.0,
    "fire_damage_bonus": 0.15,
    "ice_damage_bonus": 0.0,
    "lightning_damage_bonus": 0.0,
    "light_damage_bonus": 0.0,
    "dark_damage_bonus": 0.0,
}


def column_letters_to_index(letters: str) -> int:
    index = 0
    for char in letters:
        index = index * 26 + (ord(char.upper()) - ord("A") + 1)
    return index - 1


def get_cell_text(cell: ET.Element, shared_strings: list[str]) -> str:
    cell_type = cell.get("t")
    value_node = cell.find("main:v", NS)
    if value_node is None or value_node.text is None:
        return ""
    raw_value = value_node.text.strip()
    if cell_type == "s":
        return shared_strings[int(raw_value)]
    return raw_value


def load_shared_strings(zip_file: ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in zip_file.namelist():
        return []
    root = ET.fromstring(zip_file.read("xl/sharedStrings.xml"))
    strings: list[str] = []
    for string_item in root.findall("main:si", NS):
        text_parts = [node.text or "" for node in string_item.findall(".//main:t", NS)]
        strings.append("".join(text_parts))
    return strings


def load_first_sheet_rows(xlsx_path: Path) -> list[list[str]]:
    with ZipFile(xlsx_path) as zip_file:
        shared_strings = load_shared_strings(zip_file)
        workbook_root = ET.fromstring(zip_file.read("xl/workbook.xml"))
        workbook_rels = ET.fromstring(zip_file.read("xl/_rels/workbook.xml.rels"))
        first_sheet = workbook_root.find("main:sheets/main:sheet", NS)
        if first_sheet is None:
            raise RuntimeError("属性表.xlsx 不包含任何工作表")
        relation_id = first_sheet.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
        target_path = None
        for relation in workbook_rels.findall("pkg_rel:Relationship", NS):
            if relation.get("Id") == relation_id:
                target_path = relation.get("Target")
                break
        if not target_path:
            raise RuntimeError("找不到属性表首个工作表的关系路径")
        sheet_path = "xl/" + target_path.lstrip("/") if not target_path.startswith("xl/") else target_path
        sheet_root = ET.fromstring(zip_file.read(sheet_path))
        rows: list[list[str]] = []
        for row in sheet_root.findall("main:sheetData/main:row", NS):
            row_values: list[str] = []
            for cell in row.findall("main:c", NS):
                cell_ref = cell.get("r", "")
                column_letters = "".join(char for char in cell_ref if char.isalpha())
                column_index = column_letters_to_index(column_letters)
                while len(row_values) <= column_index:
                    row_values.append("")
                row_values[column_index] = get_cell_text(cell, shared_strings)
            rows.append(row_values)
        return rows


def parse_stat_table(rows: list[list[str]]) -> dict[str, dict[str, str]]:
    header_index = None
    for index, row in enumerate(rows):
        if len(row) >= 7 and row[0] == "id" and row[1] == "name" and row[2] == "type":
            header_index = index
            break
    if header_index is None:
        raise RuntimeError("属性表中未找到 id/name/type/base 这一行表头")

    parsed_stats: dict[str, dict[str, str]] = {}
    for row in rows[header_index + 1 :]:
        if len(row) < 4:
            continue
        stat_id = row[0].strip()
        stat_name = row[1].strip()
        base_value = row[3].strip()
        if not stat_id or not stat_name or not base_value:
            continue
        parsed_stats[stat_name] = {
            "id": stat_id,
            "name": stat_name,
            "type": row[2].strip() if len(row) > 2 else "",
            "base": base_value,
            "min": row[4].strip() if len(row) > 4 else "",
            "max": row[5].strip() if len(row) > 5 else "",
            "desc": row[6].strip() if len(row) > 6 else "",
        }
    return parsed_stats


def build_player_stats_values(parsed_stats: dict[str, dict[str, str]]) -> dict[str, float]:
    values: dict[str, float] = dict(DEFAULT_PLAYER_VALUES)
    missing_fields: list[str] = []
    for table_name, output_field in STAT_FIELD_MAP.items():
        stat_entry = parsed_stats.get(table_name)
        if stat_entry is None:
            missing_fields.append(table_name)
            continue
        values[output_field] = float(stat_entry["base"])
    if missing_fields:
        raise RuntimeError("属性表缺少必要字段: %s" % ", ".join(missing_fields))
    return values


def format_float(value: float) -> str:
    return f"{value:.1f}"


def build_unit_stats_tres(values: dict[str, float]) -> str:
    lines = [
        '[gd_resource type="Resource" script_class="UnitStatsConfig" format=3]',
        "",
        f'[ext_resource type="Script" path="{UNIT_STATS_CONFIG_SCRIPT}" id="1_unit_stats_config"]',
        "",
        "[resource]",
        'script = ExtResource("1_unit_stats_config")',
    ]
    ordered_fields = [
        "max_hp",
        "attack",
        "defense",
        "crit_rate",
        "crit_damage",
        "max_energy",
        "energy_regen",
        "move_speed",
        "attack_speed",
        "physical_damage_bonus",
        "wind_damage_bonus",
        "fire_damage_bonus",
        "ice_damage_bonus",
        "lightning_damage_bonus",
        "light_damage_bonus",
        "dark_damage_bonus",
    ]
    for field_name in ordered_fields:
        if field_name not in values:
            continue
        lines.append(f"{field_name} = {format_float(values[field_name])}")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    if not SOURCE_XLSX.exists():
        raise SystemExit(f"未找到属性表: {SOURCE_XLSX}")
    rows = load_first_sheet_rows(SOURCE_XLSX)
    parsed_stats = parse_stat_table(rows)
    player_values = build_player_stats_values(parsed_stats)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / "player_stats_from_excel.tres"
    output_path.write_text(build_unit_stats_tres(player_values), encoding="utf-8")
    print(f"导出完成: {output_path.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
