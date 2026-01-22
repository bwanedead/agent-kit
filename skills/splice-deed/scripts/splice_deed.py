import argparse
from pathlib import Path
from typing import Iterable, Tuple

from PIL import Image

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".webp"}


def ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def iter_images(root: Path, recursive: bool) -> Iterable[Path]:
    glob_fn = root.rglob if recursive else root.glob
    seen = set()
    for ext in sorted(IMAGE_EXTS):
        for pat in (f"*{ext}", f"*{ext.upper()}"):
            for p in glob_fn(pat):
                if p not in seen:
                    seen.add(p)
                    yield p


def is_probably_double_page(w: int, h: int) -> bool:
    return (w / max(h, 1)) >= 1.35


def downsample_for_analysis(img: Image.Image, max_dim: int = 900):
    w, h = img.size
    scale = max(w, h) / float(max_dim)
    if scale <= 1.0:
        return img, 1.0
    new_w = max(1, int(w / scale))
    new_h = max(1, int(h / scale))
    return img.resize((new_w, new_h), Image.BILINEAR), scale


def gutter_score_vertical(gray: Image.Image, x_center: int, band_px: int, y0: int, y1: int) -> int:
    w, h = gray.size
    x0 = max(0, x_center - band_px // 2)
    x1 = min(w, x0 + band_px)
    if x1 <= x0:
        return 10**18
    band = gray.crop((x0, y0, x1, y1))
    hist = band.histogram()
    return sum((255 - i) * c for i, c in enumerate(hist))


def gutter_score_horizontal(gray: Image.Image, y_center: int, band_px: int, x0: int, x1: int) -> int:
    w, h = gray.size
    y0 = max(0, y_center - band_px // 2)
    y1 = min(h, y0 + band_px)
    if y1 <= y0:
        return 10**18
    band = gray.crop((x0, y0, x1, y1))
    hist = band.histogram()
    return sum((255 - i) * c for i, c in enumerate(hist))


def find_split_vertical(img: Image.Image, search: float, band: float) -> int:
    small, scale = downsample_for_analysis(img.convert("RGB"))
    gray = small.convert("L")
    w, h = gray.size
    y0 = int(h * 0.08)
    y1 = int(h * 0.92)

    mid = w // 2
    half_window = int(w * search / 2.0)
    start = max(1, mid - half_window)
    end = min(w - 2, mid + half_window)

    band_px = max(2, int(w * band))
    step = max(1, int(w / 500))

    best_x = mid
    best_score = None

    for x in range(start, end + 1, step):
        s = gutter_score_vertical(gray, x, band_px, y0, y1)
        if best_score is None or s < best_score:
            best_score = s
            best_x = x

    center_score = gutter_score_vertical(gray, mid, band_px, y0, y1)
    if best_score is None or best_score > center_score * 0.95:
        best_x = mid

    return int(best_x * scale)


def find_split_horizontal(img: Image.Image, search: float, band: float) -> int:
    small, scale = downsample_for_analysis(img.convert("RGB"))
    gray = small.convert("L")
    w, h = gray.size
    x0 = int(w * 0.08)
    x1 = int(w * 0.92)

    mid = h // 2
    half_window = int(h * search / 2.0)
    start = max(1, mid - half_window)
    end = min(h - 2, mid + half_window)

    band_px = max(2, int(h * band))
    step = max(1, int(h / 500))

    best_y = mid
    best_score = None

    for y in range(start, end + 1, step):
        s = gutter_score_horizontal(gray, y, band_px, x0, x1)
        if best_score is None or s < best_score:
            best_score = s
            best_y = y

    center_score = gutter_score_horizontal(gray, mid, band_px, x0, x1)
    if best_score is None or best_score > center_score * 0.95:
        best_y = mid

    return int(best_y * scale)


def out_names(stem: str, suffix: str):
    return (f"{stem}_sp001{suffix}", f"{stem}_sp002{suffix}")


def safe_save(img: Image.Image, path: Path) -> None:
    """Save image, converting to RGB if needed for format compatibility."""
    try:
        img.save(path.as_posix())
    except OSError:
        # Some formats (JPEG) don't support palette/alpha modes - convert to RGB
        img.convert("RGB").save(path.as_posix())


def maybe_move_original(img_path: Path, in_root: Path, dest_root: Path) -> None:
    rel_parent = img_path.parent.relative_to(in_root)
    dest_dir = dest_root / rel_parent
    ensure_dir(dest_dir)
    dest_path = dest_dir / img_path.name
    if dest_path.exists():
        return
    img_path.rename(dest_path)


def main():
    ap = argparse.ArgumentParser(description="Split double-page deed images into two single-page images.")
    ap.add_argument("folder", nargs="?", default=".", help="Input folder containing images")
    ap.add_argument("--out", default="splice", help="Output folder (absolute or relative to input folder). Default: splice (inside input folder).")
    ap.add_argument("--recursive", action="store_true", help="Recurse into subfolders")
    ap.add_argument("--force", action="store_true", help="Overwrite existing splices")
    ap.add_argument("--organize", action="store_true", help="Move successfully-split originals into ./double (mirrors structure).")
    ap.add_argument("--mode", choices=["auto", "vertical", "horizontal"], default="auto", help="Split direction. auto chooses based on aspect ratio.")
    ap.add_argument("--search", type=float, default=0.12, help="Search window fraction around center for gutter detection.")
    ap.add_argument("--band", type=float, default=0.01, help="Band thickness fraction used to score gutter ink.")

    args = ap.parse_args()

    in_root = Path(args.folder).expanduser().resolve()
    if not in_root.exists() or not in_root.is_dir():
        raise SystemExit(f"Input folder not found: {in_root}")

    out_root = Path(args.out).expanduser()
    if not out_root.is_absolute():
        out_root = (in_root / out_root).resolve()
    ensure_dir(out_root)

    double_root = None
    if args.organize:
        double_root = (in_root / "double").resolve()
        ensure_dir(double_root)

    imgs = list(iter_images(in_root, args.recursive))
    if not imgs:
        print(f"No images found in {in_root} (recursive={args.recursive})")
        return

    total_written = 0
    total_split = 0
    skipped_single = 0
    errors = 0

    for img_path in imgs:
        try:
            with Image.open(img_path) as im:
                w, h = im.size

                mode = args.mode
                if mode == "auto":
                    if is_probably_double_page(w, h):
                        mode = "vertical"
                    elif (h / max(w, 1)) >= 1.35:
                        mode = "horizontal"
                    else:
                        print(f"skipped_single   | wrote    0 | {img_path}")
                        skipped_single += 1
                        continue

                rel_parent = img_path.parent.relative_to(in_root)
                out_dir = out_root / rel_parent
                ensure_dir(out_dir)

                suffix = img_path.suffix
                n1, n2 = out_names(img_path.stem, suffix)
                out1 = out_dir / n1
                out2 = out_dir / n2

                if (out1.exists() and out2.exists()) and (not args.force):
                    print(f"skipped_existing | wrote    0 | {img_path}")
                    continue

                if mode == "vertical":
                    split_x = find_split_vertical(im, args.search, args.band)
                    split_x = max(1, min(w - 1, split_x))
                    left = im.crop((0, 0, split_x, h))
                    right = im.crop((split_x, 0, w, h))
                    safe_save(left, out1)
                    safe_save(right, out2)
                else:
                    split_y = find_split_horizontal(im, args.search, args.band)
                    split_y = max(1, min(h - 1, split_y))
                    top = im.crop((0, 0, w, split_y))
                    bottom = im.crop((0, split_y, w, h))
                    safe_save(top, out1)
                    safe_save(bottom, out2)

                total_written += 2
                total_split += 1

            if double_root is not None:
                maybe_move_original(img_path, in_root, double_root)

            print(f"ok              | wrote    2 | {img_path}")

        except Exception as e:
            errors += 1
            print(f"failed          | wrote    0 | {img_path} | {e}")

    print("\nSummary")
    print(f"  Input:          {in_root}")
    print(f"  Splice output:  {out_root}")
    if double_root:
        print(f"  Double moved:   {double_root}")
    print(f"  Images scanned: {len(imgs)}")
    print(f"  Images split:   {total_split}")
    print(f"  Splices written:{total_written}")
    print(f"  Skipped single: {skipped_single}")
    print(f"  Errors:         {errors}")


if __name__ == "__main__":
    main()
