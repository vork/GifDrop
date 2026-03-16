#!/bin/bash
# Benchmark gifski quality settings: measure PSNR and file size across quality levels
set -uo pipefail

VIDEOS_DIR="/Users/markboss/Dev/gif_converter/gif_converter"
TMPDIR_BASE=$(mktemp -d)
FPS=20
WIDTH=480
QUALITY_LEVELS="10 20 30 40 50 60 70 80 90 100"

echo "Temp dir: $TMPDIR_BASE" >&2

extract_psnr() {
    echo "$1" | sed -n 's/.*average:\([0-9.]*\).*/\1/p' | tail -1
}

run_test() {
    local vname="$1" ref_dir="$2" ref_video="$3" q="$4" mq_flag="$5" mq_label="$6"
    local gif_path="$TMPDIR_BASE/${vname}_q${q}_mq${mq_label}.gif"

    local cmd=(gifski --fps "$FPS" --quality "$q" --width "$WIDTH")
    if [ -n "$mq_flag" ]; then
        cmd+=(--motion-quality "$mq_flag")
    fi
    cmd+=(-o "$gif_path")
    "${cmd[@]}" "$ref_dir"/frame_*.png 2>/dev/null || true

    if [ ! -f "$gif_path" ]; then
        printf "%-20s %5d %5s %10s %10s\n" "$vname" "$q" "$mq_label" "FAIL" "N/A"
        return
    fi

    local file_size_kb=$(( $(stat -f%z "$gif_path") / 1024 ))

    # Measure PSNR directly (same dimensions, no scaling needed)
    local psnr_output
    psnr_output=$(ffmpeg -i "$ref_video" -i "$gif_path" -lavfi psnr -f null - 2>&1) || true
    local mean_psnr
    mean_psnr=$(extract_psnr "$psnr_output")
    [ -z "$mean_psnr" ] && mean_psnr="N/A"

    printf "%-20s %5d %5s %10d %10s\n" "$vname" "$q" "$mq_label" "$file_size_kb" "$mean_psnr"
    rm -f "$gif_path"
}

printf "\n%-20s %5s %5s %10s %10s\n" "video" "q" "mq" "size_kb" "psnr"
echo "--------------------------------------------------------------"

for video in "$VIDEOS_DIR"/*.mp4; do
    vname=$(basename "$video" .mp4)
    echo "Processing: $vname" >&2

    ref_dir="$TMPDIR_BASE/${vname}_ref"
    mkdir -p "$ref_dir"
    ffmpeg -loglevel error -i "$video" \
        -vf "fps=$FPS,scale=$WIDTH:-2:flags=lanczos" \
        -vsync vfr "$ref_dir/frame_%06d.png" 2>/dev/null || true

    ref_count=$(ls "$ref_dir"/frame_*.png 2>/dev/null | wc -l | tr -d ' ')
    if [ "$ref_count" -eq 0 ]; then
        echo "# SKIP $vname" >&2
        continue
    fi

    ref_video="$TMPDIR_BASE/${vname}_ref.mp4"
    ffmpeg -loglevel error -framerate "$FPS" -i "$ref_dir/frame_%06d.png" \
        -c:v libx264 -crf 0 -pix_fmt yuv420p "$ref_video" -y 2>/dev/null || true

    for q in $QUALITY_LEVELS; do
        run_test "$vname" "$ref_dir" "$ref_video" "$q" "" "def"
    done

    for q in 50 80 90 100; do
        for mq in 50 100; do
            run_test "$vname" "$ref_dir" "$ref_video" "$q" "$mq" "$mq"
        done
    done

    rm -rf "$ref_dir" "$ref_video"
    echo ""
done

rm -rf "$TMPDIR_BASE"
echo "Done." >&2
