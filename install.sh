#!/usr/bin/env bash
# claude-monorepo installer.
#
# Usage:
#   ./install.sh                # interactive menu
#   ./install.sh --all          # install everything
#   ./install.sh --relay        # just relay
#   ./install.sh --sync         # just sync-daemon
#   ./install.sh --ios          # bootstrap iOS Xcode project
#   ./install.sh --brain        # info about the brain folder
#   ./install.sh --deps-only    # only system deps (node, xcodegen)
#   ./install.sh --doctor       # check prerequisites, install nothing
#   ./install.sh --version      # print version and exit
#   ./install.sh -h | --help

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo "unknown")"

# ---------- pretty ----------
b()  { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
no() { printf '  \033[31m✗\033[0m %s\n' "$*"; }
hr() { printf '  \033[90m·\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
have()     { command -v "$1" >/dev/null 2>&1; }

# ---------- system deps ----------
ensure_brew() {
  if have brew; then ok "brew $(brew --version | sed -n '1p' | awk '{print $2}')"; return; fi
  if ! is_macos; then warn "Homebrew is macOS-only; skipping"; return; fi
  warn "Homebrew not found. Install it from https://brew.sh and re-run."
  return 1
}

ensure_node() {
  if have node; then ok "node $(node -v)"; return; fi
  if is_macos && have brew; then
    hr "installing node via brew"
    brew install node
    ok "node $(node -v)"
  else
    die "node missing; install Node 18+ and re-run"
  fi
}

ensure_xcodegen() {
  if have xcodegen; then ok "xcodegen $(xcodegen --version 2>&1 | tail -n1)"; return; fi
  if is_macos && have brew; then
    hr "installing xcodegen via brew"
    brew install xcodegen
    ok "xcodegen $(xcodegen --version 2>&1 | tail -n1)"
  else
    warn "xcodegen missing (iOS app needs it). Install: brew install xcodegen"
  fi
}

system_deps() {
  b "system deps"
  ensure_brew || true
  ensure_node
  if [[ "${WANT_IOS:-0}" == 1 ]]; then ensure_xcodegen; fi
}

# ---------- per-app installers ----------
install_relay() {
  b "apps/relay"
  ( cd apps/relay && npm install ) && ok "relay deps installed"
  if [[ ! -f apps/relay/.env ]]; then
    cp apps/relay/.env.example apps/relay/.env 2>/dev/null && \
      warn "apps/relay/.env created from .env.example — edit it before running"
  fi
}

install_sync() {
  b "apps/sync-daemon"
  ( cd apps/sync-daemon && npm install ) && ok "sync-daemon deps installed"
}

install_ios() {
  b "apps/ios-app"
  ensure_xcodegen
  ( cd apps/ios-app && ./bootstrap.sh ) && ok "Xcode project generated"
  hr "open in Xcode: open apps/ios-app/ClaudePlanner.xcodeproj"
}

install_brain() {
  b "apps/brain"
  ok "brain is plain markdown — no install needed"
  hr "edit files in apps/brain/, or symlink it elsewhere"
  hr "e.g. ln -s \"$ROOT/apps/brain\" ~/Brain"
}

# ---------- doctor ----------
doctor() {
  b "doctor"
  have node      && ok "node       $(node -v)"           || no "node       MISSING (install Node 18+)"
  have npm       && ok "npm        $(npm -v)"            || no "npm        MISSING"
  have git       && ok "git        $(git --version | awk '{print $3}')" || no "git        MISSING"
  have brew      && ok "brew       $(brew --version | sed -n '1p' | awk '{print $2}')" || warn "brew       (macOS recommended)"
  have xcodegen  && ok "xcodegen   $(xcodegen --version 2>&1 | tail -n1)" || warn "xcodegen   (needed for iOS app)"
  have xcodebuild && ok "xcodebuild present" || warn "xcodebuild (install Xcode for iOS builds)"
  have gh        && ok "gh         $(gh --version | sed -n '1p' | awk '{print $3}')"  || warn "gh         (optional, for GitHub ops)"
  echo
  hr "app status:"
  [[ -d apps/relay/node_modules        ]] && ok "relay deps installed"        || no "relay deps NOT installed (./install.sh --relay)"
  [[ -d apps/sync-daemon/node_modules  ]] && ok "sync-daemon deps installed"  || no "sync-daemon deps NOT installed (./install.sh --sync)"
  [[ -f apps/ios-app/ClaudePlanner.xcodeproj/project.pbxproj ]] && ok "ios-app project present" || no "ios-app NOT bootstrapped (./install.sh --ios)"
  [[ -f apps/relay/.env ]] && ok "apps/relay/.env present" || warn "apps/relay/.env missing (copy from .env.example)"
}

# ---------- menu ----------
menu() {
  cat <<'EOF'
claude-monorepo installer

  1) everything (system deps + all apps)
  2) relay only
  3) sync-daemon only
  4) iOS app only
  5) brain (info)
  6) doctor (check only)
  q) quit
EOF
  read -r -p "choose: " choice
  case "$choice" in
    1) WANT_IOS=1; system_deps; install_relay; install_sync; install_ios; install_brain ;;
    2) system_deps; install_relay ;;
    3) system_deps; install_sync ;;
    4) WANT_IOS=1; system_deps; install_ios ;;
    5) install_brain ;;
    6) doctor ;;
    q|Q) ;;
    *) die "unknown choice" ;;
  esac
}

# ---------- arg parse ----------
WANT_ALL=0; WANT_RELAY=0; WANT_SYNC=0; WANT_IOS=0; WANT_BRAIN=0; WANT_DEPS=0; WANT_DOCTOR=0

while (( $# )); do
  case "$1" in
    --all)        WANT_ALL=1 ;;
    --relay)      WANT_RELAY=1 ;;
    --sync|--sync-daemon) WANT_SYNC=1 ;;
    --ios)        WANT_IOS=1 ;;
    --brain)      WANT_BRAIN=1 ;;
    --deps-only)  WANT_DEPS=1 ;;
    --doctor|--check) WANT_DOCTOR=1 ;;
    --version|-V) printf 'claude-monorepo %s\n' "$VERSION"; exit 0 ;;
    -h|--help)
      sed -n '2,14p' "$0"; exit 0 ;;
    *) die "unknown arg: $1 (try --help)" ;;
  esac
  shift
done

b "claude-monorepo $VERSION"

if (( WANT_DOCTOR )); then doctor; exit 0; fi
if (( WANT_DEPS )); then system_deps; exit 0; fi

if (( WANT_ALL || WANT_RELAY || WANT_SYNC || WANT_IOS || WANT_BRAIN )); then
  if (( WANT_ALL )); then WANT_IOS=1; system_deps; install_relay; install_sync; install_ios; install_brain; exit 0; fi
  if (( WANT_RELAY )); then system_deps; install_relay; fi
  if (( WANT_SYNC ));  then system_deps; install_sync; fi
  if (( WANT_IOS ));   then system_deps; install_ios; fi
  if (( WANT_BRAIN )); then install_brain; fi
  exit 0
fi

# no args → interactive
menu
