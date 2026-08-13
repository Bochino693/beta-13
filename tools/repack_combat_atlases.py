#!/usr/bin/env python3
"""Isola e normaliza as 16 poses dos atlas de combate.

Os atlas artísticos não nasceram em uma grade perfeitamente rígida: asas,
caudas e partículas atravessam alguns limites de célula. Recortar apenas por
largura/4 e altura/4 faz a pose vizinha aparecer durante a luta. Este utilitário
atribui cada componente visível à pose pelo seu centro, preserva a extensão
completa desse componente e recompõe um atlas 4x4 com margem transparente.

As poses 0..7 continuam sendo a vista de costas (jogador) e 8..15 a vista de
frente (oponente). A arte original permanece recuperável pelo histórico Git.
"""

from __future__ import annotations

import argparse
import io
import json
import subprocess
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[1]
ATLAS_DIR = ROOT / "assets" / "sprites_combat"
GRID = 4
CELL = 384
SAFE_MARGIN = 18
ALPHA_THRESHOLD = 10
LAYOUT_VERSION = 2


@dataclass
class Component:
    label: int
    area: int
    bounds: tuple[int, int, int, int]
    cell: int


def component_catalog(alpha: np.ndarray) -> tuple[np.ndarray, list[Component]]:
    visible = alpha > ALPHA_THRESHOLD
    labels, count = ndimage.label(visible, structure=np.ones((3, 3), dtype=np.uint8))
    objects = ndimage.find_objects(labels)
    height, width = alpha.shape
    cell_width = width / GRID
    cell_height = height / GRID
    components: list[Component] = []

    for label_index in range(1, count + 1):
        slices = objects[label_index - 1]
        if slices is None:
            continue
        ys, xs = slices
        local = labels[ys, xs] == label_index
        area = int(local.sum())
        if area < 4:
            continue
        weights = alpha[ys, xs].astype(np.float64) * local
        total = float(weights.sum())
        if total <= 0.0:
            continue
        yy, xx = np.indices(local.shape)
        center_x = float((weights * (xx + xs.start)).sum() / total)
        center_y = float((weights * (yy + ys.start)).sum() / total)
        column = min(GRID - 1, max(0, int(center_x / cell_width)))
        row = min(GRID - 1, max(0, int(center_y / cell_height)))
        components.append(Component(
            label=label_index,
            area=area,
            bounds=(xs.start, ys.start, xs.stop, ys.stop),
            cell=row * GRID + column,
        ))
    return labels, components


def extract_pose(
    rgba: np.ndarray,
    labels: np.ndarray,
    components: list[Component],
    cell_index: int,
) -> Image.Image:
    selected = [component for component in components if component.cell == cell_index]
    if not selected:
        return Image.new("RGBA", (1, 1))

    largest = max(component.area for component in selected)
    # Pontos isolados de 1-3 px são ruído de geração. Partículas e ornamentos
    # reais permanecem mesmo quando são bem menores que o corpo principal.
    minimum = max(4, int(largest * 0.00012))
    selected = [component for component in selected if component.area >= minimum]
    x0 = min(component.bounds[0] for component in selected)
    y0 = min(component.bounds[1] for component in selected)
    x1 = max(component.bounds[2] for component in selected)
    y1 = max(component.bounds[3] for component in selected)

    wanted = np.zeros(labels.shape, dtype=bool)
    for component in selected:
        wanted |= labels == component.label
    crop = rgba[y0:y1, x0:x1].copy()
    crop[~wanted[y0:y1, x0:x1]] = 0
    return Image.fromarray(crop, mode="RGBA")


def extract_manifest_pose(rgba: np.ndarray, rect: list[int]) -> Image.Image:
    """Extrai uma pose pela caixa detectada e remove fragmentos de borda.

    As caixas dos manifestos seguem a posição artística real e, portanto,
    funcionam até em atlas como Teslouro, cujas figuras se encostam entre
    linhas. Pequenos componentes distantes que tocam a borda são vazamento da
    pose vizinha; o corpo principal nunca é descartado.
    """
    x, y, width, height = [int(value) for value in rect]
    source_height, source_width = rgba.shape[:2]
    x0 = max(0, x)
    y0 = max(0, y)
    x1 = min(source_width, x + width)
    y1 = min(source_height, y + height)
    crop = rgba[y0:y1, x0:x1].copy()
    alpha = crop[:, :, 3]
    labels, count = ndimage.label(
        alpha > ALPHA_THRESHOLD,
        structure=np.ones((3, 3), dtype=np.uint8),
    )
    if count == 0:
        return Image.new("RGBA", (1, 1))
    objects = ndimage.find_objects(labels)
    areas = np.bincount(labels.ravel())
    main_label = int(np.argmax(areas[1:]) + 1)
    main_slice = objects[main_label - 1]
    if main_slice is None:
        return Image.new("RGBA", (1, 1))
    main_y, main_x = main_slice
    main_center = np.array([
        (main_x.start + main_x.stop) * 0.5,
        (main_y.start + main_y.stop) * 0.5,
    ])
    diagonal = max(1.0, float(np.hypot(crop.shape[1], crop.shape[0])))
    keep = np.zeros(labels.shape, dtype=bool)
    largest = int(areas[main_label])

    for label_index in range(1, count + 1):
        slices = objects[label_index - 1]
        if slices is None:
            continue
        ys, xs = slices
        area = int(areas[label_index])
        if area < max(4, int(largest * 0.00012)):
            continue
        center = np.array([(xs.start + xs.stop) * 0.5, (ys.start + ys.stop) * 0.5])
        distance = float(np.linalg.norm(center - main_center)) / diagonal
        touches_edge = (
            xs.start <= 1 or ys.start <= 1
            or xs.stop >= crop.shape[1] - 1 or ys.stop >= crop.shape[0] - 1
        )
        is_border_leak = (
            label_index != main_label
            and touches_edge
            and distance > 0.30
            and area < largest * 0.16
        )
        if not is_border_leak:
            keep |= labels == label_index
    crop[~keep] = 0
    visible = np.argwhere(crop[:, :, 3] > ALPHA_THRESHOLD)
    if visible.size == 0:
        return Image.new("RGBA", (1, 1))
    yy0, xx0 = visible.min(axis=0)
    yy1, xx1 = visible.max(axis=0) + 1
    return Image.fromarray(crop[yy0:yy1, xx0:xx1], mode="RGBA")


def extract_grid_pose(rgba: np.ndarray, columns: int, rows: int, index: int) -> Image.Image:
    height, width = rgba.shape[:2]
    column = index % columns
    row = index // columns
    x0 = round(column * width / columns)
    x1 = round((column + 1) * width / columns)
    y0 = round(row * height / rows)
    y1 = round((row + 1) * height / rows)
    crop = rgba[y0:y1, x0:x1].copy()
    visible = np.argwhere(crop[:, :, 3] > ALPHA_THRESHOLD)
    if visible.size == 0:
        return Image.new("RGBA", (1, 1))
    yy0, xx0 = visible.min(axis=0)
    yy1, xx1 = visible.max(axis=0) + 1
    return Image.fromarray(crop[yy0:yy1, xx0:xx1], mode="RGBA")


def compose_view(poses: list[Image.Image]) -> list[Image.Image]:
    maximum_width = max(image.width for image in poses)
    maximum_height = max(image.height for image in poses)
    available = CELL - SAFE_MARGIN * 2
    scale = min(available / maximum_width, available / maximum_height, 1.18)
    output: list[Image.Image] = []

    for pose in poses:
        width = max(1, round(pose.width * scale))
        height = max(1, round(pose.height * scale))
        resized = pose.resize((width, height), Image.Resampling.LANCZOS)
        cell = Image.new("RGBA", (CELL, CELL))
        x = (CELL - width) // 2
        y = CELL - SAFE_MARGIN - height
        cell.alpha_composite(resized, (x, y))
        output.append(cell)
    return output


def manifest_is_current(path: Path) -> bool:
    if not path.is_file():
        return False
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    return data.get("layout_version") == LAYOUT_VERSION


def git_bytes(ref: str, relative: Path) -> bytes:
    result = subprocess.run(
        ["git", "show", f"{ref}:{relative.as_posix()}"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    return result.stdout


def repack(path: Path, force: bool, source_ref: str) -> bool:
    manifest_path = path.with_suffix(".poses.json")
    if not force and manifest_is_current(manifest_path):
        with Image.open(path) as current:
            if current.size == (CELL * GRID, CELL * GRID):
                return False

    relative = path.relative_to(ROOT)
    image_bytes = git_bytes(source_ref, relative) if source_ref else path.read_bytes()
    with Image.open(io.BytesIO(image_bytes)) as source:
        rgba_image = source.convert("RGBA")
    rgba = np.asarray(rgba_image)
    manifest_bytes = (
        git_bytes(source_ref, manifest_path.relative_to(ROOT))
        if source_ref else manifest_path.read_bytes()
    )
    source_manifest = json.loads(manifest_bytes.decode("utf-8-sig"))
    source_poses = sorted(source_manifest.get("poses", []), key=lambda pose: int(pose["indice"]))
    if path.stem == "teslouro":
        # O atlas-fonte de Teslouro possui 12 desenhos reais em uma grade 4x3.
        # Os oito estados traseiros estão completos; a vista frontal traz quatro
        # poses, combinadas com movimento corporal para preencher os oito estados
        # sem jamais exibir uma figura cortada.
        twelve = [extract_grid_pose(rgba, 4, 3, index) for index in range(12)]
        front_map = [8, 9, 10, 10, 8, 9, 10, 11]
        extracted = twelve[:8] + [twelve[index] for index in front_map]
    elif len(source_poses) == 16 and all("rect" in pose for pose in source_poses):
        extracted = [extract_manifest_pose(rgba, pose["rect"]) for pose in source_poses]
    else:
        labels, components = component_catalog(rgba[:, :, 3])
        extracted = [extract_pose(rgba, labels, components, index) for index in range(16)]
    if any(image.width == 1 and image.height == 1 for image in extracted):
        missing = [str(index) for index, image in enumerate(extracted) if image.size == (1, 1)]
        raise RuntimeError(f"{path.name}: poses vazias: {', '.join(missing)}")

    # Escalas independentes preservam o enquadramento das vistas de costas e
    # frente sem provocar mudança de tamanho durante os estados de cada vista.
    cells = compose_view(extracted[:8]) + compose_view(extracted[8:])
    atlas = Image.new("RGBA", (CELL * GRID, CELL * GRID))
    for index, cell in enumerate(cells):
        atlas.alpha_composite(cell, ((index % GRID) * CELL, (index // GRID) * CELL))
    temporary_path = path.with_suffix(".repack.png")
    atlas.save(temporary_path, optimize=True, compress_level=9)
    # Só substitui o recurso depois de decodificá-lo por inteiro. Assim uma
    # interrupção nunca deixa um PNG parcial no projeto.
    with Image.open(temporary_path) as verification:
        verification.load()
        if verification.size != (CELL * GRID, CELL * GRID):
            raise RuntimeError(f"{path.name}: tamanho inválido após gravação")
    temporary_path.replace(path)

    pose_names = [
        "repouso_a", "repouso_b", "carga", "ataque",
        "dano", "esquiva", "vitoria", "ko",
    ]
    manifest = {
        "id": path.stem,
        "atlas": f"res://assets/sprites_combat/{path.name}",
        "layout_version": LAYOUT_VERSION,
        "tamanho": [CELL * GRID, CELL * GRID],
        "linhas": GRID,
        "colunas": GRID,
        "deteccao": "componentes_isolados",
        "ordem_vistas": ["costas", "frente"],
        "poses": [
            {
                "nome": f"{pose_names[index % 8]}_{'costas' if index < 8 else 'frente'}",
                "indice": index,
                "rect": [(index % GRID) * CELL, (index // GRID) * CELL, CELL, CELL],
                "ancora": [0.5, 1.0],
            }
            for index in range(16)
        ],
    }
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return True


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="reprocessa atlas já normalizados")
    parser.add_argument(
        "--source-ref",
        default="",
        help="lê os atlas-fonte de uma referência Git, por exemplo origin/main",
    )
    args = parser.parse_args()
    paths = sorted(
        path for path in ATLAS_DIR.glob("*.png")
        if not path.name.endswith(".repack.png")
    )
    if len(paths) != 30:
        raise SystemExit(f"Esperados 30 atlas; encontrados {len(paths)}.")
    changed = 0
    for path in paths:
        if repack(path, args.force, args.source_ref):
            changed += 1
            print(f"OK  {path.stem}")
        else:
            print(f"--  {path.stem} (já normalizado)")
    print(f"Atlas normalizados: {changed}/{len(paths)}")


if __name__ == "__main__":
    main()
