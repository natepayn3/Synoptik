#!/usr/bin/env bash

# Builds the wallpaper tag index: a { "<path>": ["tag", ...] } map, written
# next to the dominant-colour index (colors.json) that wallpaper_colors.py
# produces, and read by WallpaperConfig the same way.
#
# Why this is a separate pass from wallhaven_sync.sh: the collection listing
# endpoint returns colours and a category per wallpaper but NOT tags - those
# only exist on the per-wallpaper endpoint, one HTTP request each. Wallhaven
# allows 45 requests/minute, so tagging a 112-image library takes about three
# minutes the first time. Every run after that is incremental (already-tagged
# paths are skipped), which is why the cache is merged rather than rebuilt.
#
# The API key is optional here. Public SFW wallpapers answer without one; a key
# is only needed for sketchy/NSFW entries, which simply stay untagged without it.
#
# Usage: wallhaven_tags.sh [api_key] [wallpaper_dir] [cache_file] [max_per_run]

API_KEY="$1"
TARGET_DIR="${2:-$HOME/Pictures/Wallpapers}"
CACHE_FILE="${3:-$HOME/.cache/wallpaper-thumbs/tags.json}"
MAX_PER_RUN="${4:-0}"

command -v jq >/dev/null 2>&1 || { echo "STATUS:Error: jq is not installed"; exit 1; }
mkdir -p "$(dirname "$CACHE_FILE")"
[ -s "$CACHE_FILE" ] || echo '{}' > "$CACHE_FILE"

# A cache that isn't valid JSON (interrupted write on an older version, manual
# edit) would otherwise poison every merge below - start over instead.
jq -e . "$CACHE_FILE" >/dev/null 2>&1 || echo '{}' > "$CACHE_FILE"

echo "STATUS:Scanning wallpapers..."

PENDING=()
while IFS= read -r file; do
    [ -n "$file" ] || continue
    # Only wallhaven-<id>.<ext> files carry a recoverable ID; anything else in
    # the folder (a hand-added wallpaper, a screenshot) has nothing to look up.
    base=$(basename "$file")
    case "$base" in
        wallhaven-*) ;;
        *) continue ;;
    esac
    if jq -e --arg p "$file" 'has($p)' "$CACHE_FILE" >/dev/null 2>&1; then
        continue
    fi
    PENDING+=("$file")
done < <(find "$TARGET_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)

TOTAL=${#PENDING[@]}
if [ "$TOTAL" -eq 0 ]; then
    echo "STATUS:Tag index already up to date"
    exit 0
fi

if [ "$MAX_PER_RUN" -gt 0 ] && [ "$TOTAL" -gt "$MAX_PER_RUN" ]; then
    PENDING=("${PENDING[@]:0:$MAX_PER_RUN}")
    TOTAL=$MAX_PER_RUN
fi

echo "STATUS:Tagging $TOTAL wallpaper(s) from Wallhaven..."

CURL=(curl -s --connect-timeout 10 --max-time 20 -w $'\n%{http_code}')
CURRENT=0
BATCH="$(mktemp)"
trap 'rm -f "$BATCH"' EXIT

# Merges whatever has been collected so far into the cache and empties the
# batch. Called every 10 wallpapers as well as at the end, so a run that is
# interrupted (or rate-limited into giving up) still keeps its work.
flush_batch() {
    [ -s "$BATCH" ] || return 0
    local tmp
    tmp="$(mktemp)"
    if jq -s 'add' "$CACHE_FILE" "$BATCH" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
        mv -f "$tmp" "$CACHE_FILE"
        : > "$BATCH"
    else
        rm -f "$tmp"
    fi
}

for file in "${PENDING[@]}"; do
    CURRENT=$((CURRENT + 1))
    base=$(basename "$file")
    id="${base#wallhaven-}"
    id="${id%.*}"

    url="https://wallhaven.cc/api/v1/w/$id"
    [ -n "$API_KEY" ] && url="$url?apikey=$API_KEY"

    response=$("${CURL[@]}" ${API_KEY:+-H "X-API-Key: $API_KEY"} "$url")
    status=$(printf '%s' "$response" | tail -n1)
    body=$(printf '%s' "$response" | sed '$d')

    # 45 requests/minute, enforced per-IP: back off once rather than burning
    # through the rest of the queue collecting nothing but 429s.
    if [ "$status" = "429" ]; then
        echo "STATUS:Rate limited by Wallhaven - waiting 30s..."
        sleep 30
        response=$("${CURL[@]}" ${API_KEY:+-H "X-API-Key: $API_KEY"} "$url")
        status=$(printf '%s' "$response" | tail -n1)
        body=$(printf '%s' "$response" | sed '$d')
    fi

    if [ "$status" = "200" ]; then
        # "anime" and "people" are things people ask for by name, so the
        # category joins the tag list - except "general", which is Wallhaven's
        # catch-all and would end up on most of the library while meaning
        # nothing. (Config.wallpaperTags() also filters it, for caches written
        # before this did.)
        printf '%s' "$body" | jq --arg p "$file" -c \
            '{($p): ([.data.tags[].name] + [.data.category | select(. != "general")]
                     | map(ascii_downcase) | unique)}' \
            >> "$BATCH" 2>/dev/null
    else
        # A 404 (deleted upload) or 401 (needs a key) is permanent for this
        # wallpaper - record it empty so later runs don't retry it forever.
        printf '{"%s":[]}\n' "$file" >> "$BATCH"
    fi

    echo "PROGRESS:$CURRENT:$TOTAL"
    [ $((CURRENT % 10)) -eq 0 ] && flush_batch

    # ~40 requests/minute, comfortably inside the published limit.
    sleep 1.5
done

flush_batch
echo "STATUS:Tag index updated ($TOTAL wallpaper(s))"
exit 0
