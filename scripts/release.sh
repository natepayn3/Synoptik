#!/usr/bin/env bash
#
# Cut a Synoptik release.
#
#     scripts/release.sh 1.1.0
#     scripts/release.sh 1.1.0 --dry-run
#
# Four things have to move together for a release, and forgetting any one of
# them produces a subtly broken package rather than an obvious failure:
#
#   1. Config.qml          shellVersion, which is what the shell reports
#   2. the git tag         what the release page and the tarball URL point at
#   3. packaging/PKGBUILD  pkgver AND sha256sums of the new tarball
#   4. packaging/.SRCINFO  regenerated from the PKGBUILD
#
# The ordering is not negotiable: the checksum in (3) can only be computed
# after (2) is pushed and GitHub has published the tarball, so this pushes the
# tag, waits for the archive to appear, and only then touches packaging.
#
# Leaves the GitHub release page itself to you - that wants a human-written
# changelog, and it can be created any time after the tag exists.

set -euo pipefail

DRY_RUN=0
ASSUME_YES=0
VERSION=""

usage() {
    cat <<'EOF'
Usage: scripts/release.sh <version> [options]

  <version>    Release version without the leading v, e.g. 1.1.0

  --dry-run    Show every change and command without making any of them.
  -y, --yes    Do not prompt before pushing the commit and tag.
  -h, --help   Show this help.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -y|--yes)  ASSUME_YES=1 ;;
        -h|--help) usage; exit 0 ;;
        -*)        echo "Unknown option: $arg (see --help)" >&2; exit 1 ;;
        *)
            if [ -n "$VERSION" ]; then
                echo "Version given twice: $VERSION and $arg" >&2; exit 1
            fi
            VERSION="$arg"
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    usage >&2
    exit 1
fi

# Reject a leading v now rather than producing tag "vv1.1.0" later.
if ! printf '%s' "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Version must be bare semver like 1.1.0 (no leading v): got '$VERSION'" >&2
    exit 1
fi

TAG="v$VERSION"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

CONFIG_QML="components/Config.qml"
PKGBUILD="packaging/PKGBUILD"
SRCINFO="packaging/.SRCINFO"
TARBALL_URL="https://github.com/natepayn3/Synoptik/archive/refs/tags/$TAG.tar.gz"

say()  { printf '==> %s\n' "$1"; }
info() { printf '    %s\n' "$1"; }
die()  { printf 'error: %s\n' "$1" >&2; exit 1; }

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

# --- Preflight ------------------------------------------------------------
# Everything that would make this release wrong, checked before anything is
# changed - a half-applied release is far more annoying than a refused one.

say "Checking preconditions for $TAG"

[ -f "$CONFIG_QML" ] || die "$CONFIG_QML not found - run this from the Synoptik repo"
[ -f "$PKGBUILD" ]   || die "$PKGBUILD not found"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "main" ] || die "on branch '$BRANCH' - releases are cut from main"

[ -z "$(git status --porcelain)" ] || die "working tree is dirty - commit or stash first"

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists locally"
if git ls-remote --tags origin "refs/tags/$TAG" | grep -q .; then
    die "tag $TAG already exists on origin"
fi

git fetch -q origin main
LOCAL="$(git rev-parse @)"
REMOTE="$(git rev-parse @{u})"
[ "$LOCAL" = "$REMOTE" ] || die "main is not in sync with origin/main - pull or push first"

CURRENT="$(grep -oP 'shellVersion:\s*"\K[^"]+' "$CONFIG_QML" || true)"
[ -n "$CURRENT" ] || die "could not read shellVersion from $CONFIG_QML"
info "current version: $CURRENT  ->  $VERSION"

if [ "$CURRENT" = "$VERSION" ]; then
    die "shellVersion is already $VERSION - nothing to bump"
fi

if [ "$ASSUME_YES" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    printf '\nThis will commit, tag %s, and push both to origin. Continue? [y/N] ' "$TAG"
    read -r reply
    case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "Aborted."; exit 1 ;;
    esac
fi

# --- 1. Version the shell reports ----------------------------------------

say "Bumping shellVersion in $CONFIG_QML"
if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] sed shellVersion "%s" -> "%s"\n' "$CURRENT" "$VERSION"
else
    sed -i "s/shellVersion: \"$CURRENT\"/shellVersion: \"$VERSION\"/" "$CONFIG_QML"
    grep -q "shellVersion: \"$VERSION\"" "$CONFIG_QML" || die "shellVersion bump did not apply"
fi

run git add "$CONFIG_QML"
run git commit -m "Release $TAG"

# --- 2. Tag and push ------------------------------------------------------
# Pushed before packaging is touched, because the tarball has to exist before
# it can be checksummed.

say "Tagging and pushing $TAG"
run git tag -a "$TAG" -m "Synoptik $TAG"
run git push origin main
run git push origin "$TAG"

# --- 3. Wait for GitHub to publish the archive ---------------------------
# Generated on demand the first time it is requested, so it is not always
# instant after the tag lands.

if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] wait for %s, then checksum it\n' "$TARBALL_URL"
    SHA="<computed after the tag is pushed>"
else
    say "Waiting for $TARBALL_URL"
    SHA=""
    for attempt in $(seq 1 30); do
        code="$(curl -sSL -o /dev/null -w '%{http_code}' "$TARBALL_URL" || echo 000)"
        if [ "$code" = "200" ]; then
            tmp="$(mktemp)"
            curl -sSL -o "$tmp" "$TARBALL_URL"
            SHA="$(sha256sum "$tmp" | cut -d' ' -f1)"
            rm -f "$tmp"
            info "archive ready after ${attempt}s"
            break
        fi
        sleep 1
    done
    [ -n "$SHA" ] || die "archive did not appear after 30s - tag is pushed, re-run the packaging steps by hand"
    info "sha256: $SHA"
fi

# --- 4. Packaging ---------------------------------------------------------

say "Updating $PKGBUILD"
OLD_PKGVER="$(grep -oP '^pkgver=\K.*' "$PKGBUILD")"
if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] pkgver %s -> %s, and replace sha256sums\n' "$OLD_PKGVER" "$VERSION"
else
    sed -i "s/^pkgver=.*/pkgver=$VERSION/" "$PKGBUILD"
    sed -i "s/^sha256sums=.*/sha256sums=('$SHA')/" "$PKGBUILD"
    grep -q "^pkgver=$VERSION\$" "$PKGBUILD" || die "pkgver bump did not apply"
    grep -q "^sha256sums=('$SHA')\$" "$PKGBUILD" || die "sha256sums bump did not apply"
fi

say "Regenerating $SRCINFO"
if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] (cd packaging && makepkg --printsrcinfo > .SRCINFO)\n'
else
    ( cd packaging && makepkg --printsrcinfo > .SRCINFO )
fi

run git add "$PKGBUILD" "$SRCINFO"
run git commit -m "packaging: build $TAG"
run git push origin main

# --- Done -----------------------------------------------------------------

echo
if [ "$DRY_RUN" -eq 1 ]; then
    say "Dry run complete - nothing was changed."
else
    say "$TAG is tagged and pushed."
    info "Remaining, by hand:"
    info "  1. Create the release page: https://github.com/natepayn3/Synoptik/releases/new?tag=$TAG"
    info "  2. Tick 'Set as the latest release'"
    info "  3. If synoptik is on the AUR, push packaging/PKGBUILD and .SRCINFO there too"
fi
