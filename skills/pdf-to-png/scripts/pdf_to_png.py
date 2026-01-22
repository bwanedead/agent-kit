import argparse
from pathlib import Path

import fitz  # PyMuPDF


def iter_pdfs(root: Path, recursive: bool):
    seen = set()
    patterns = ["*.pdf", "*.PDF"] if recursive else ["*.pdf", "*.PDF"]
    glob_fn = root.rglob if recursive else root.glob
    for pattern in patterns:
        for p in glob_fn(pattern):
            if p not in seen:
                seen.add(p)
                yield p


def ensure_dir(p: Path):
    p.mkdir(parents=True, exist_ok=True)


def convert_pdf(pdf_path: Path, in_root: Path, out_root: Path, dpi: int, force: bool, pdf_dest: Path = None):
    """
    Convert one PDF to one-or-many PNGs.
    Output naming:
      - single-page PDF -> <stem>.png
      - multi-page PDF  -> <stem>_p001.png, <stem>_p002.png, ...
    Output folder mirrors input folder structure relative to in_root.
    """
    rel_parent = pdf_path.parent.relative_to(in_root)
    out_dir = out_root / rel_parent
    ensure_dir(out_dir)

    try:
        doc = fitz.open(pdf_path)
    except Exception as e:
        return (pdf_path, 0, f"open_failed: {e}")

    page_count = doc.page_count
    zoom = dpi / 72.0
    matrix = fitz.Matrix(zoom, zoom)

    def out_name(i: int) -> str:
        stem = pdf_path.stem
        if page_count == 1:
            return f"{stem}.png"
        return f"{stem}_p{i+1:03d}.png"

    # If not forcing, skip if every expected output exists
    if not force:
        all_exist = True
        for i in range(page_count):
            if not (out_dir / out_name(i)).exists():
                all_exist = False
                break
        if all_exist:
            doc.close()
            # Still move PDF if organizing
            if pdf_dest is not None:
                rel_parent = pdf_path.parent.relative_to(in_root)
                pdf_out_dir = pdf_dest / rel_parent
                ensure_dir(pdf_out_dir)
                new_pdf_path = pdf_out_dir / pdf_path.name
                if not new_pdf_path.exists():
                    pdf_path.rename(new_pdf_path)
            return (pdf_path, page_count, "skipped_existing")

    written = 0
    try:
        for i in range(page_count):
            out_path = out_dir / out_name(i)
            if out_path.exists() and not force:
                continue
            page = doc.load_page(i)
            pix = page.get_pixmap(matrix=matrix, alpha=False)
            pix.save(out_path.as_posix())
            written += 1
    except Exception as e:
        doc.close()
        return (pdf_path, written, f"render_failed: {e}")

    doc.close()

    # If organize mode, move PDF to pdf subfolder
    if pdf_dest is not None:
        rel_parent = pdf_path.parent.relative_to(in_root)
        pdf_out_dir = pdf_dest / rel_parent
        ensure_dir(pdf_out_dir)
        new_pdf_path = pdf_out_dir / pdf_path.name
        if not new_pdf_path.exists():
            pdf_path.rename(new_pdf_path)

    return (pdf_path, written, "ok")


def main():
    ap = argparse.ArgumentParser(
        description="Convert PDFs in a folder into PNG sidecars (one PNG per page)."
    )
    ap.add_argument("folder", nargs="?", default=".", help="Input folder containing PDFs")
    ap.add_argument(
        "--out",
        default="png",
        help="Output folder (absolute or relative to input folder). Default: png (inside input folder).",
    )
    ap.add_argument("--dpi", type=int, default=200, help="Render DPI (default: 200)")
    ap.add_argument("--recursive", action="store_true", help="Recurse into subfolders")
    ap.add_argument("--force", action="store_true", help="Overwrite existing PNGs")
    ap.add_argument("--organize", action="store_true", help="Organize files into pdf/ and png/ subfolders")
    args = ap.parse_args()

    in_root = Path(args.folder).expanduser().resolve()
    if not in_root.exists() or not in_root.is_dir():
        raise SystemExit(f"Input folder not found: {in_root}")

    out_root = Path(args.out).expanduser()
    if not out_root.is_absolute():
        out_root = (in_root / out_root).resolve()
    ensure_dir(out_root)

    # Set up pdf destination folder if organizing
    pdf_dest = None
    if args.organize:
        pdf_dest = (in_root / "pdf").resolve()
        ensure_dir(pdf_dest)

    pdfs = list(iter_pdfs(in_root, args.recursive))
    if not pdfs:
        print(f"No PDFs found in {in_root} (recursive={args.recursive})")
        return

    total_written = 0
    errors = 0

    for pdf in pdfs:
        pdf_path, written, status = convert_pdf(pdf, in_root, out_root, args.dpi, args.force, pdf_dest)
        if status.startswith("open_failed") or status.startswith("render_failed"):
            errors += 1
        if status == "ok":
            total_written += written
        print(f"{status:16} | wrote {written:4d} | {pdf_path}")

    print("\nSummary")
    print(f"  Input:        {in_root}")
    print(f"  PNG output:   {out_root}")
    if pdf_dest:
        print(f"  PDF output:   {pdf_dest}")
    print(f"  PDFs:         {len(pdfs)}")
    print(f"  PNGs written: {total_written}")
    if pdf_dest:
        print(f"  PDFs moved:   {len(pdfs)}")
    print(f"  Errors:       {errors}")


if __name__ == "__main__":
    main()
