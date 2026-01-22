import argparse

def main():
    ap = argparse.ArgumentParser(description="__SKILL_NAME__: __SKILL_DESCRIPTION__")
    ap.add_argument("path", nargs="?", default=".", help="Input path (file or folder)")
    ap.add_argument("--organize", action="store_true", help="Optional organize behavior")
    args = ap.parse_args()

    print(f"[__SKILL_NAME__] path={args.path} organize={args.organize}")
    # TODO: implement

if __name__ == "__main__":
    main()
