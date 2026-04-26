#!/bin/bash
SRC_DIR="~/mnt/frigate-fast"
DEST_DIR="~/mnt/frigate-slow"
AGE=1440
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --src)   SRC_DIR="$2";  shift 2 ;;
        --dest)  DEST_DIR="$2"; shift 2 ;;
        --age)   AGE="$2";      shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Moves Frigate recordings older than a specified age from fast storage"
            echo "(e.g. SSD) to slow storage (e.g. NAS), preserving the directory structure."
            echo ""
            echo "Options:"
            echo "  --src <path>    Source directory to move files from."
            echo "                  Default: $SRC_DIR"
            echo "  --dest <path>   Destination directory to move files to."
            echo "                  Default: $DEST_DIR"
            echo "  --age <minutes> Minimum file age in minutes before it is moved."
            echo "                  Default: $AGE (approx. 3 days)"
            echo "  --dry-run       Preview which files would be moved without moving anything."
            echo "  --help          Show this help message and exit."
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if $DRY_RUN; then
    echo "[DRY RUN] No files will be moved."
fi

find "$SRC_DIR" -type f -mmin +$AGE -print0 | while IFS= read -r -d '' file; do
    rel_path="${file#$SRC_DIR/}"
    dest_file="$DEST_DIR/$rel_path"
    dest_dir="$(dirname "$dest_file")"

    if $DRY_RUN; then
        echo "[DRY RUN] Would move: $file -> $dest_file"
    else
        IFS='/' read -ra DIRS <<< "$dest_dir"
        path=""
        for dir in "${DIRS[@]}"; do
            path="$path/$dir"
            if [ ! -d "$path" ]; then
                mkdir "$path"
                chown root:root "$path"
            fi
        done
        rsync -a --chown=root:root --remove-source-files "$file" "$dest_file"
        rm -f "$file"
    fi
done

if ! $DRY_RUN; then
    find "$SRC_DIR" -type d -empty -delete
fi
