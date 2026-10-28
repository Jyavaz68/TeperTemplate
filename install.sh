#!/usr/bin/env bash
# =============================================================================
#  TeperTemplate — installer / updater for Pasarguard subscription pages
#  Repo : https://github.com/Jyavaz68/TeperTemplate
#  Usage: sudo bash install.sh            (interactive menu)
#         sudo bash install.sh update     (update, keep your branding)
#         sudo bash install.sh --help
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

# ---- repository (edit GH_USER once after you publish the repo) --------------
REPO_NAME="TeperTemplate"
GH_USER="${TEPER_GH_USER:-Jyavaz68}"
BRANCH="${TEPER_BRANCH:-main}"

# ---- paths (override with env vars if your layout differs) ------------------
ENV_FILE="${TEPER_ENV_FILE:-/opt/pasarguard/.env}"
DATA_DIR="${TEPER_DATA_DIR:-/var/lib/pasarguard}"
TEMPLATES_DIR="$DATA_DIR/templates"
TARGET_DIR="$TEMPLATES_DIR/subscription"
TARGET_FILE="$TARGET_DIR/index.html"
STATE_FILE="$TARGET_DIR/.teper.json"
BACKUP_DIR="$TARGET_DIR/.teper-backups"
CLI_PATH="/usr/local/bin/teper"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo /)"
RAW_BASE="https://raw.githubusercontent.com/$GH_USER/$REPO_NAME/$BRANCH"

# ---- options ----------------------------------------------------------------
ACTION=""; YES=0; FORCE=0; USE_REMOTE=0; NO_RESTART="${TEPER_NO_RESTART:-0}"
OPT_NAME=""; OPT_SUB_FA=""; OPT_SUB_EN=""; OPT_LOGO=""; OPT_SUPPORT=""; OPT_ACCENT=""; OPT_BGD=""; OPT_BGL=""; OPT_LANG=""; OPT_THEME=""
HAVE_NAME=0; HAVE_SUB_FA=0; HAVE_SUB_EN=0; HAVE_LOGO=0; HAVE_SUPPORT=0; HAVE_ACCENT=0; HAVE_BGD=0; HAVE_BGL=0; HAVE_LANG=0; HAVE_THEME=0

# ---- ui ---------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  R=$'\033[0m'; B=$'\033[1m'; D=$'\033[2m'
  RED=$'\033[38;5;203m'; GRN=$'\033[38;5;84m'; YEL=$'\033[38;5;221m'; ACC=$'\033[38;5;141m'; CYN=$'\033[38;5;117m'
else R=""; B=""; D=""; RED=""; GRN=""; YEL=""; ACC=""; CYN=""; fi
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;; *) command -v locale >/dev/null 2>&1 && locale -a 2>/dev/null | grep -qi '^c\.utf-\?8$' && export LC_ALL=C.UTF-8;; esac
UTF8=0; case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) UTF8=1;; esac
if (( UTF8 )); then OK="✔"; BAD="✖"; ARW="▸"; DOT="•"; else OK="+"; BAD="x"; ARW=">"; DOT="*"; fi

banner() {
  local ver="${1:-}"
  [[ -t 1 ]] && printf '\033[2J\033[H' || true
  echo
  if (( UTF8 )) && [[ -t 1 ]]; then
    local c=(33 69 105 141 177 213) l=(
"████████╗███████╗██████╗ ███████╗██████╗ "
"╚══██╔══╝██╔════╝██╔══██╗██╔════╝██╔══██╗"
"   ██║   █████╗  ██████╔╝█████╗  ██████╔╝"
"   ██║   ██╔══╝  ██╔═══╝ ██╔══╝  ██╔══██╗"
"   ██║   ███████╗██║     ███████╗██║  ██║"
"   ╚═╝   ╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝")
    local i; for i in "${!l[@]}"; do printf '  \033[1;38;5;%sm%s\033[0m\n' "${c[$i]}" "${l[$i]}"; done
  else
    printf '  %s=== T E P E R ===%s\n' "$B$ACC" "$R"
  fi
  echo
  printf '  %s%s%s  %s·%s  Pasarguard subscription theme' "$B" "$REPO_NAME" "$R" "$D" "$R"
  [[ -n "$ver" ]] && printf '  %s·%s  %sv%s%s' "$D" "$R" "$CYN" "$ver" "$R"
  echo
  printf '  %sgithub.com/%s/%s%s\n\n' "$D" "$GH_USER" "$REPO_NAME" "$R"
}
say()  { printf '  %s\n' "$*"; }
step() { printf '  %s%s%s %s\n' "$ACC" "$ARW" "$R" "$*"; }
ok()   { printf '  %s%s%s %s\n' "$GRN" "$OK" "$R" "$*"; }
warn() { printf '  %s!%s %s\n' "$YEL" "$R" "$*" >&2; }
die()  { printf '  %s%s %s%s\n' "$RED" "$BAD" "$*" "$R" >&2; exit 1; }
hr()   { printf '  %s%s%s\n' "$D" "──────────────────────────────────────────────" "$R"; }

have_tty() { { : >/dev/tty; } 2>/dev/null; }
ask() { # ask VAR "Prompt" "default"
  local __var="$1" __prompt="$2" __def="${3:-}" __ans=""
  if (( YES )); then printf -v "$__var" '%s' "$__def"; return 0; fi
  have_tty || die "No terminal available. Re-run with --yes and the --name/--logo/... flags."
  if [[ -n "$__def" && -z "$(printf '%s' "$__def" | LC_ALL=C tr -d '\040-\176')" ]]; then printf '  %s?%s %s %s[%s]%s: ' "$ACC" "$R" "$__prompt" "$D" "$__def" "$R" >/dev/tty
  elif [[ -n "$__def" ]]; then printf '  %s?%s %s %s[Enter = keep current]%s: ' "$ACC" "$R" "$__prompt" "$D" "$R" >/dev/tty
  else printf '  %s?%s %s: ' "$ACC" "$R" "$__prompt" >/dev/tty; fi
  IFS= read -r __ans </dev/tty || true
  printf -v "$__var" '%s' "${__ans:-$__def}"
}
confirm() { # confirm "Question" default(y/n)
  local q="$1" d="${2:-y}" a
  if (( YES )); then [[ "$d" == y ]]; return; fi
  ask a "$q ($( [[ $d == y ]] && echo 'Y/n' || echo 'y/N' ))" ""
  a="${a:-$d}"; [[ "$a" =~ ^[Yy] ]]
}

# ---- helpers ----------------------------------------------------------------
need_root() { [[ $EUID -eq 0 ]] || die "Please run as root (e.g. download install.sh, then: sudo bash install.sh ${ACTION:-})"; }
need_cmds() {
  local missing=() c
  for c in curl python3; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
  if (( ${#missing[@]} )); then
    warn "Missing: ${missing[*]}"
    if command -v apt-get >/dev/null 2>&1; then
      step "Installing ${missing[*]} ..."; apt-get update -qq >/dev/null 2>&1 || true
      apt-get install -y -qq "${missing[@]}" >/dev/null 2>&1 || die "Could not install ${missing[*]}"
    else die "Please install: ${missing[*]}"; fi
  fi
}
check_repo() {
  [[ "$GH_USER" != "YOUR_GITHUB_USERNAME" ]] || die "GH_USER is not set. Edit install.sh (GH_USER=...) or run with TEPER_GH_USER=yourname."
}
check_pasarguard() {
  [[ -f "$ENV_FILE" ]] || die "Pasarguard .env not found at $ENV_FILE (override with TEPER_ENV_FILE=/path/.env)"
  [[ -d "$DATA_DIR" ]] || die "Pasarguard data dir not found at $DATA_DIR (override with TEPER_DATA_DIR=...)"
}
fetch() { curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 10 -H 'Cache-Control: no-cache' "$1"; }
ver_gt() { [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$1" ]]; }
local_version() { [[ -f "$SCRIPT_DIR/VERSION" ]] && tr -d '[:space:]' <"$SCRIPT_DIR/VERSION" || true; }
remote_version() { fetch "$RAW_BASE/VERSION" 2>/dev/null | tr -d '[:space:]' | head -c 32 || true; }
installed_version() { [[ -f "$STATE_FILE" ]] && STATE="$STATE_FILE" python3 -c 'import json,os;print(json.load(open(os.environ["STATE"])).get("version",""))' 2>/dev/null || true; }

# ---- state / config (python does all JSON + HTML patching safely) -----------
py_cfg() { # prints merged config JSON: defaults < saved state < CLI/answers (env TEPER_ANS)
  python3 - "$@" <<'PY'
import json, os, re, sys
d = {"name":"Teper","subtitle":{"fa":"پنل اشتراک","en":"Subscription panel"},"logoUrl":"","supportUrl":"","accent":"indigo","bgDark":"","bgLight":"","lang":"fa","theme":"dark","credit":True}
st = os.environ.get("STATE","")
if st and os.path.isfile(st):
    try:
        c = json.load(open(st, encoding="utf-8")).get("config", {})
        sub = c.pop("subtitle", None)
        d.update(c)
        if isinstance(sub, dict): d["subtitle"].update(sub)
    except Exception: pass
ans = json.loads(os.environ.get("TEPER_ANS","{}"))
sub = ans.pop("subtitle", {})
d.update(ans); d["subtitle"].update(sub)
clean = lambda s, n: re.sub(r"[\x00-\x1f\x7f]", "", str(s)).strip()[:n]
d["name"] = clean(d["name"], 40) or "Teper"
d["subtitle"] = {k: clean(v, 60) for k, v in d["subtitle"].items()}
d["logoUrl"] = clean(d["logoUrl"], 500)
d["supportUrl"] = clean(d["supportUrl"], 500)
ACC = ("indigo","violet","fuchsia","pink","rose","red","orange","amber","lime","emerald","teal","cyan","sky","blue")
if not (d["accent"] in ACC or re.fullmatch(r"#[0-9a-fA-F]{6}", str(d["accent"]))): d["accent"] = "indigo"
old_bg = str(d.pop("bg", "") or "")   # migrate the single "bg" key of v1.2.x
def _hex(v): return bool(re.fullmatch(r"#[0-9a-fA-F]{6}", str(v or "")))
def _lum(h):
    c = [int(h[i:i+2], 16) / 255 for i in (1, 3, 5)]
    c = [v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
if _hex(old_bg):
    k = "bgDark" if _lum(old_bg) < 0.4 else "bgLight"
    if not d.get(k): d[k] = old_bg
for k in ("bgDark", "bgLight"):
    if not _hex(d.get(k, "")): d[k] = ""
if d["lang"] not in ("fa","en"): d["lang"] = "fa"
if d["theme"] not in ("dark","light","auto"): d["theme"] = "dark"
print(json.dumps(d, ensure_ascii=False))
PY
}
py_apply() { # py_apply FILE CONFIG_JSON  → rewrites config block in FILE
  FILE="$1" CFGJSON="$2" python3 - <<'PY'
import json, os, re
p = os.environ["FILE"]; cfg = json.loads(os.environ["CFGJSON"])
s = open(p, encoding="utf-8").read()
js = json.dumps(cfg, ensure_ascii=False, indent=2).replace("</", "<\\/").replace("<!--", "<\\!--")
blk = "/*TEPER_CONFIG_START*/\nwindow.TEPER_CONFIG = " + js + ";\n/*TEPER_CONFIG_END*/"
n, k = re.subn(r"/\*TEPER_CONFIG_START\*/.*?/\*TEPER_CONFIG_END\*/", lambda m: blk, s, count=1, flags=re.S)
if k != 1: raise SystemExit("config markers not found in template")
open(p, "w", encoding="utf-8", newline="\n").write(n)
PY
}
py_save_state() { # py_save_state VERSION CONFIG_JSON
  STATE="$STATE_FILE" VER="$1" CFGJSON="$2" python3 - <<'PY'
import json, os, time
json.dump({"version": os.environ["VER"], "installed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "config": json.loads(os.environ["CFGJSON"])},
          open(os.environ["STATE"], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
  chmod 600 "$STATE_FILE"
}
py_env_set() { # py_env_set KEY VALUE  (replace active line, else commented one, else append)
  ENVF="$ENV_FILE" K="$1" V="$2" python3 - <<'PY'
import os, re
p, k, v = os.environ["ENVF"], os.environ["K"], os.environ["V"]
lines = open(p, encoding="utf-8").read().split("\n")
new = f'{k}="{v}"'; done = False
for i, l in enumerate(lines):
    if re.match(rf"^\s*{k}\s*=", l): lines[i] = new; done = True; break
if not done:
    for i, l in enumerate(lines):
        if re.match(rf"^\s*#\s*{k}\s*=", l): lines[i] = new; done = True; break
if not done:
    if lines and lines[-1] == "": lines.pop()
    lines += ["", new, ""]
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
}
py_env_comment() { ENVF="$ENV_FILE" K="$1" python3 - <<'PY'
import os, re
p, k = os.environ["ENVF"], os.environ["K"]
t = open(p, encoding="utf-8").read().split("\n")
t = [("# " + l) if re.match(rf"^\s*{k}\s*=", l) else l for l in t]
open(p, "w", encoding="utf-8").write("\n".join(t))
PY
}
env_get() { grep -E "^\s*$1\s*=" "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- | tr -d '"'"'" || true; }

# ---- questions --------------------------------------------------------------
norm_support() {
  local s="$1"
  [[ -z "$s" || "$s" == "-" || "$s" == "none" ]] && { echo ""; return; }
  [[ "$s" =~ ^@[A-Za-z0-9_.]{3,}$ ]] && { echo "https://t.me/${s#@}"; return; }
  [[ "$s" =~ ^(t\.me|wa\.me)/ ]] && { echo "https://$s"; return; }
  [[ "$s" =~ ^https?:// ]] && { echo "$s"; return; }
  echo "INVALID"
}
check_logo() {
  local u="$1"
  [[ -z "$u" || "$u" == "-" || "$u" == "none" ]] && { echo ""; return; }
  [[ "$u" =~ ^https:// ]] || { echo "INVALID"; return; }
  local ct; ct="$(curl -fsSLI --connect-timeout 8 -o /dev/null -w '%{content_type}' "$u" 2>/dev/null || true)"
  if [[ "$ct" != image/* ]]; then warn "Could not confirm that this URL is an image (content-type: ${ct:-unknown})." >&2
    confirm "Use it anyway?" n || { echo "INVALID"; return; }; fi
  echo "$u"
}
ACC_NAMES=(indigo emerald rose amber sky violet fuchsia pink red orange lime teal cyan blue)
ACC_HEX=(7c8cff 34d399 fb7185 fbbf24 38bdf8 a78bfa d946ef f472b6 f87171 fb923c a3e635 2dd4bf 22d3ee 60a5fa)
BGD_NAMES=(Default Midnight Violet Wine Forest Ocean Graphite Coffee Black)
BGD_HEX=("" 0a1128 150b2b 2a0b18 08180f 061b1f 131316 1d130b 000000)
BGL_NAMES=(Default Snow Cream Mint Lavender Blush Sky)
BGL_HEX=("" ffffff fbf3e4 e6f7ef efe9fb fdeaee e4f1fc)
swatch() { local h="${1:-070a12}"; printf '\033[48;2;%d;%d;%dm    \033[0m' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"; }
is_hex() { [[ "$1" =~ ^#[0-9A-Fa-f]{6}$ ]]; }
pick_accent() {
  local cur="${1:-indigo}" a i nm def=1 n=${#ACC_NAMES[@]}
  say "Button / accent color:" >&2
  for ((i=0; i<n; i++)); do
    printf '    %s%2d%s %s %-9s' "$B" "$((i+1))" "$R" "$(swatch "${ACC_HEX[i]}")" "${ACC_NAMES[i]}" >&2
    (( (i+1) % 3 == 0 )) && printf '\n' >&2
  done
  (( n % 3 )) && printf '\n' >&2
  printf '    %s%2d%s custom color  %s(#rrggbb, e.g. #ff5a5f)%s\n' "$B" "$((n+1))" "$R" "$D" "$R" >&2
  for ((i=0; i<n; i++)); do [[ "${ACC_NAMES[i]}" == "$cur" ]] && def=$((i+1)); done
  is_hex "$cur" && def="$cur"
  ask a "Choose 1-$((n+1)) or type #hex" "$def"
  if [[ "$a" =~ ^[0-9]+$ ]]; then
    if (( a >= 1 && a <= n )); then echo "${ACC_NAMES[a-1]}"; return; fi
    if (( a == n+1 )); then ask a "Custom color (#rrggbb)" "#7c8cff"; is_hex "$a" && echo "$a" || echo indigo; return; fi
  fi
  is_hex "$a" && { echo "$a"; return; }
  for nm in "${ACC_NAMES[@]}"; do [[ "$a" == "$nm" ]] && { echo "$nm"; return; }; done
  echo indigo
}
pick_bg() { # pick_bg dark|light CURRENT
  local mode="$1" cur="${2:-}" a i def=0 n title names hexes
  if [[ "$mode" == dark ]]; then title="Dark theme background"; names=("${BGD_NAMES[@]}"); hexes=("${BGD_HEX[@]}")
  else title="Light theme background"; names=("${BGL_NAMES[@]}"); hexes=("${BGL_HEX[@]}"); fi
  n=${#names[@]}
  say "$title:" >&2
  for ((i=0; i<n; i++)); do
    local sw="${hexes[i]}"; [[ -z "$sw" ]] && { [[ "$mode" == dark ]] && sw=070a12 || sw=eef2fb; }
    printf '    %s%2d%s %s %-9s' "$B" "$i" "$R" "$(swatch "$sw")" "${names[i]}" >&2
    (( (i+1) % 3 == 0 )) && printf '\n' >&2
  done
  (( n % 3 )) && printf '\n' >&2
  printf '    %s%2d%s custom color  %s(#rrggbb)   %s0 = built-in default%s\n' "$B" "$n" "$R" "$D" "$D" "$R" >&2
  for ((i=1; i<n; i++)); do [[ "#${hexes[i]}" == "$cur" ]] && def=$i; done
  is_hex "$cur" && (( def == 0 )) && def="$cur"
  ask a "Choose 0-$n or type #hex" "$def"
  if [[ "$a" =~ ^[0-9]+$ ]]; then
    if (( a >= 1 && a < n )); then echo "#${hexes[a]}"; return; fi
    if (( a == 0 )); then echo ""; return; fi
    if (( a == n )); then ask a "Custom color (#rrggbb)" "#0a1128"; is_hex "$a" && echo "$a" || echo ""; return; fi
  fi
  is_hex "$a" && { echo "$a"; return; }
  echo ""
}
collect_config() { # fills ANS_JSON using saved values as defaults
  local cur; cur="$(STATE="$STATE_FILE" TEPER_ANS="{}" py_cfg)"
  getc() { CUR="$cur" python3 -c 'import json,os,sys;d=json.loads(os.environ["CUR"]);k=sys.argv[1].split(".");
for x in k: d=d[x]
print(d)' "$1"; }
  local name sfa sen logo support accent bgd bgl lang theme v
  name="$(getc name)"; sfa="$(getc subtitle.fa)"; sen="$(getc subtitle.en)"; logo="$(getc logoUrl)"; support="$(getc supportUrl)"; accent="$(getc accent)"; bgd="$(getc bgDark)"; bgl="$(getc bgLight)"; lang="$(getc lang)"; theme="$(getc theme)"
  (( HAVE_NAME ))    && name="$OPT_NAME"
  (( HAVE_SUB_FA ))  && sfa="$OPT_SUB_FA"
  (( HAVE_SUB_EN ))  && sen="$OPT_SUB_EN"
  (( HAVE_LOGO ))    && logo="$OPT_LOGO"
  (( HAVE_SUPPORT )) && support="$OPT_SUPPORT"
  (( HAVE_ACCENT ))  && accent="$OPT_ACCENT"
  (( HAVE_BGD ))     && bgd="$OPT_BGD"
  (( HAVE_BGL ))     && bgl="$OPT_BGL"
  (( HAVE_LANG ))    && lang="$OPT_LANG"
  (( HAVE_THEME ))   && theme="$OPT_THEME"

  if (( ! YES )); then
    echo; hr; say "${B}Brand your page${R}  ${D}(press Enter to keep the value in brackets)${R}"; hr; echo
    (( HAVE_NAME ))    || ask name "Brand name (shown in the logo)" "$name"
    (( HAVE_SUB_FA ))  || ask sfa  "Tagline, Persian" "$sfa"
    (( HAVE_SUB_EN ))  || ask sen  "Tagline, English" "$sen"
    if (( ! HAVE_LOGO )); then
      while :; do ask v "Logo image URL (https, PNG/SVG/WebP; '-' = default shield logo)" "${logo:--}"
        v="$(check_logo "$v")"; [[ "$v" == INVALID ]] || { logo="$v"; break; }; warn "Please enter a valid https:// image URL, or '-' to skip."; done
    fi
    if (( ! HAVE_SUPPORT )); then
      while :; do ask v "Support link (@telegram_id, https://… or '-' for none)" "${support:--}"
        v="$(norm_support "$v")"; [[ "$v" == INVALID ]] || { support="$v"; break; }; warn "Use @username, t.me/…, or an https:// link."; done
    fi
    (( HAVE_ACCENT )) || accent="$(pick_accent "$accent")"
    (( HAVE_BGD )) || bgd="$(pick_bg dark "$bgd")"
    (( HAVE_BGL )) || bgl="$(pick_bg light "$bgl")"
    (( HAVE_LANG )) || { ask lang "Default language (fa/en)" "$lang"; }
    (( HAVE_THEME )) || { ask theme "Default theme (dark/light/auto)" "$theme"; }
  else
    v="$(norm_support "$support")"; [[ "$v" == INVALID ]] && die "Invalid --support value."; support="$v"
    [[ "$logo" =~ ^(-|none)$ ]] && logo=""
    [[ -z "$logo" || "$logo" =~ ^https:// ]] || die "--logo must be an https:// URL."
  fi
  [[ "$bgd" =~ ^(-|none|default)$ ]] && bgd=""
  [[ "$bgl" =~ ^(-|none|default)$ ]] && bgl=""
  [[ -z "$bgd" ]] || is_hex "$bgd" || die "--bg-dark must be #rrggbb (or - for the built-in default)."
  [[ -z "$bgl" ]] || is_hex "$bgl" || die "--bg-light must be #rrggbb (or - for the built-in default)."
  ANS_JSON="$(N="$name" A="$sfa" E="$sen" L="$logo" S="$support" C="$accent" D="$bgd" W="$bgl" G="$lang" T="$theme" python3 -c '
import json,os;e=os.environ
print(json.dumps({"name":e["N"],"subtitle":{"fa":e["A"],"en":e["E"]},"logoUrl":e["L"],"supportUrl":e["S"],"accent":e["C"],"bgDark":e["D"],"bgLight":e["W"],"lang":e["G"],"theme":e["T"]}, ensure_ascii=False))')"
}

# ---- core -------------------------------------------------------------------
get_template() { # get_template DEST → copies local or downloads remote; echoes source description
  local dest="$1"
  if (( ! USE_REMOTE )) && [[ -f "$SCRIPT_DIR/index.html" ]] && grep -q 'TEPER_CONFIG_START' "$SCRIPT_DIR/index.html"; then
    cp "$SCRIPT_DIR/index.html" "$dest"; echo "local copy ($SCRIPT_DIR)"
  else
    check_repo
    fetch "$RAW_BASE/index.html" >"$dest" || die "Download failed: $RAW_BASE/index.html"
    echo "GitHub ($GH_USER/$REPO_NAME@$BRANCH)"
  fi
  [[ "$(wc -c <"$dest")" -gt 20000 ]] && grep -q 'TEPER_CONFIG_START' "$dest" || die "Downloaded file does not look like a valid TeperTemplate."
}
backup_current() {
  [[ -f "$TARGET_FILE" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  if ! grep -q 'TEPER_CONFIG_START' "$TARGET_FILE" && [[ ! -f "$BACKUP_DIR/original-before-teper.html" ]]; then
    cp -p "$TARGET_FILE" "$BACKUP_DIR/original-before-teper.html"; ok "Saved your previous template as original-before-teper.html"
  fi
  cp -p "$TARGET_FILE" "$BACKUP_DIR/index-$(date +%Y%m%d-%H%M%S).html"
  ls -1t "$BACKUP_DIR"/index-*.html 2>/dev/null | tail -n +6 | xargs -r rm -f --
}
write_env() {
  step "Configuring $ENV_FILE"
  cp -p "$ENV_FILE" "$ENV_FILE.teper.bak"
  py_env_set CUSTOM_TEMPLATES_DIRECTORY "$TEMPLATES_DIR/"
  py_env_set SUBSCRIPTION_PAGE_TEMPLATE "subscription/index.html"
  ok "CUSTOM_TEMPLATES_DIRECTORY and SUBSCRIPTION_PAGE_TEMPLATE are set"
}
install_cli() {
  [[ -w "$(dirname "$CLI_PATH")" ]] || return 0
  [[ "$GH_USER" == "YOUR_GITHUB_USERNAME" ]] && return 0
  cat >"$CLI_PATH" <<EOF
#!/usr/bin/env bash
# TeperTemplate launcher — always runs the latest installer from GitHub
tmp="\$(mktemp)"; trap 'rm -f "\$tmp"' EXIT
curl -fsSL "$RAW_BASE/install.sh" -o "\$tmp" || { echo "Could not reach GitHub" >&2; exit 1; }
[[ \$EUID -eq 0 ]] && bash "\$tmp" "\$@" || sudo bash "\$tmp" "\$@"
EOF
  chmod 755 "$CLI_PATH"; ok "Command ${B}teper${R} installed  ${D}(run 'teper' for the menu, 'teper update' to update)${R}"
}
restart_panel() {
  if [[ "$NO_RESTART" == 1 ]]; then warn "Restart skipped (TEPER_NO_RESTART=1)."; return; fi
  if ! confirm "Restart Pasarguard now to apply changes?" y; then say "Remember to run:  ${B}pasarguard restart${R}"; return; fi
  step "Restarting Pasarguard ..."
  if command -v pasarguard >/dev/null 2>&1; then pasarguard restart || warn "pasarguard restart reported an error."
  elif command -v docker >/dev/null 2>&1; then (cd "$(dirname "$ENV_FILE")" && docker compose down && docker compose up -d) || warn "docker compose failed."
  else warn "Could not find the pasarguard command; restart the panel manually."; fi
  ok "Done"
}
summary() { # summary CONFIG_JSON
  CUR="$1" python3 - <<'PY'
import json, os
c = json.loads(os.environ["CUR"])
rows = [("Brand", c["name"]), ("Tagline", c["subtitle"]["fa"] + "  /  " + c["subtitle"]["en"]), ("Logo", c["logoUrl"] or "(default shield logo)"),
        ("Support", c["supportUrl"] or "(none)"), ("Accent", c["accent"]), ("Dark bg", c.get("bgDark") or "(default)"), ("Light bg", c.get("bgLight") or "(default)"), ("Language", c["lang"]), ("Theme", c["theme"])]
for k, v in rows: print(f"    {k:<9} {v}")
PY
}

do_install() {
  need_root; need_cmds; check_pasarguard
  local prev; prev="$(installed_version)"
  collect_config
  local cfg; cfg="$(STATE="$STATE_FILE" TEPER_ANS="$ANS_JSON" py_cfg)"
  echo; hr; say "${B}Summary${R}"; summary "$cfg"; hr
  confirm "Install with these settings?" y || { say "Cancelled."; return; }
  local tmp; tmp="$(mktemp)"
  step "Fetching template ..."; local src; src="$(get_template "$tmp")"; ok "Source: $src"
  local ver; ver="$(remote_version)"; [[ -z "$ver" ]] && ver="$(local_version)"; ver="${ver:-0.0.0}"
  step "Applying your branding ..."; py_apply "$tmp" "$cfg"
  mkdir -p "$TARGET_DIR"; backup_current
  install -m 644 "$tmp" "$TARGET_FILE"; py_save_state "$ver" "$cfg"
  ok "Installed to $TARGET_FILE"
  rm -f "$tmp"; write_env; install_cli; restart_panel
  echo; hr; ok "${B}TeperTemplate v$ver is live.${R} ${D}Open any subscription link to see it.${R}"
  [[ -n "$prev" ]] && say "${D}(replaced previous Teper install v$prev)${R}"; echo
}

do_update() {
  need_root; need_cmds; check_pasarguard
  [[ -f "$STATE_FILE" && -f "$TARGET_FILE" ]] || die "TeperTemplate is not installed yet. Choose 'Install' first."
  local cur rem; cur="$(installed_version)"; rem="$(remote_version)"
  if (( USE_REMOTE == 0 )) && [[ -z "$rem" && -f "$SCRIPT_DIR/VERSION" ]]; then rem="$(local_version)"; fi
  [[ -n "$rem" ]] || die "Could not read the latest version from GitHub (network or GH_USER/BRANCH problem)."
  step "Installed: ${B}v${cur:-?}${R}   Latest: ${B}v$rem${R}"
  if [[ "$cur" == "$rem" ]] && (( ! FORCE )); then ok "You're already on the latest version."; return; fi
  if [[ -n "$cur" ]] && ver_gt "$cur" "$rem" && (( ! FORCE )); then warn "Installed version is newer than the repository ($cur > $rem). Use --force to reinstall."; return; fi
  if ! (( YES )); then
    local log; log="$(fetch "$RAW_BASE/CHANGELOG.md" 2>/dev/null | sed -n '1,14p' || true)"
    [[ -n "$log" ]] && { echo; hr; say "${B}What's new${R}"; printf '%s\n' "$log" | sed 's/^/    /'; hr; }
  fi
  confirm "Update to v$rem? (your branding is kept)" y || { say "Cancelled."; return; }
  local cfg; cfg="$(STATE="$STATE_FILE" TEPER_ANS="{}" py_cfg)"
  local tmp; tmp="$(mktemp)"
  step "Downloading v$rem ..."; local src; src="$(get_template "$tmp")"; ok "Source: $src"
  py_apply "$tmp" "$cfg"; backup_current
  install -m 644 "$tmp" "$TARGET_FILE"; py_save_state "$rem" "$cfg"
  rm -f "$tmp"; ok "Updated v${cur:-?} ${ARW} v$rem  ${D}(previous file kept in .teper-backups)${R}"
  install_cli; restart_panel
}

do_brand() {
  need_root; need_cmds; check_pasarguard
  [[ -f "$STATE_FILE" && -f "$TARGET_FILE" ]] || die "TeperTemplate is not installed yet. Choose 'Install' first."
  collect_config
  local cfg; cfg="$(STATE="$STATE_FILE" TEPER_ANS="$ANS_JSON" py_cfg)"
  echo; hr; say "${B}Summary${R}"; summary "$cfg"; hr
  confirm "Apply these changes?" y || { say "Cancelled."; return; }
  backup_current; py_apply "$TARGET_FILE" "$cfg"; py_save_state "$(installed_version)" "$cfg"
  ok "Branding updated"; restart_panel
}

do_status() {
  need_cmds
  local cur rem; cur="$(installed_version)"; rem="$(remote_version)"
  hr; say "${B}Status${R}"
  say "  Template file : $([[ -f $TARGET_FILE ]] && echo "$TARGET_FILE" || echo "not found")"
  say "  Installed     : $([[ -n $cur ]] && echo "v$cur" || echo "not installed by TeperTemplate")"
  say "  Latest (repo) : $([[ -n $rem ]] && echo "v$rem" || echo "unavailable")"
  [[ -n "$cur" && -n "$rem" ]] && { if ver_gt "$rem" "$cur"; then say "  ${YEL}Update available${R}  → run: ${B}teper update${R}"; else say "  ${GRN}Up to date${R}"; fi; }
  if [[ -f "$ENV_FILE" ]]; then
    say "  .env          : CUSTOM_TEMPLATES_DIRECTORY=$(env_get CUSTOM_TEMPLATES_DIRECTORY)"
    say "                  SUBSCRIPTION_PAGE_TEMPLATE=$(env_get SUBSCRIPTION_PAGE_TEMPLATE)"
  fi
  if [[ -f "$STATE_FILE" ]]; then say ""; say "  Branding:"; summary "$(STATE="$STATE_FILE" TEPER_ANS="{}" py_cfg)"; fi
  hr
}

do_uninstall() {
  need_root; need_cmds; check_pasarguard
  [[ -f "$STATE_FILE" ]] || warn "No TeperTemplate state file found; continuing anyway."
  local d=n; (( YES )) && d=y
  confirm "Remove TeperTemplate and restore the previous subscription page?" "$d" || { say "Cancelled."; return; }
  local orig="$BACKUP_DIR/original-before-teper.html"
  if [[ -f "$orig" ]]; then cp -p "$orig" "$TARGET_FILE"; ok "Restored your previous template"
  else rm -f "$TARGET_FILE"; py_env_comment SUBSCRIPTION_PAGE_TEMPLATE; ok "Removed template and disabled SUBSCRIPTION_PAGE_TEMPLATE (panel default page is used)"; fi
  rm -f "$STATE_FILE" "$CLI_PATH"
  confirm "Also delete backups in $BACKUP_DIR?" n && rm -rf "$BACKUP_DIR" || true
  restart_panel
}

usage() {
cat <<EOF
TeperTemplate installer

Usage: sudo bash install.sh [command] [options]

Commands
  install       Install the template (asks for brand name, logo, ...)
  update        Update to the latest GitHub version, keeping your branding
  brand         Change brand name / logo / colors without reinstalling
  status        Show installed vs. latest version
  uninstall     Remove it and restore your previous page
  (none)        Interactive menu

Options
  -y, --yes               Non-interactive (use flags / saved values)
  --name TEXT             Brand name shown in the logo
  --subtitle-fa TEXT      Persian tagline          --subtitle-en TEXT   English tagline
  --logo URL              https image URL ('-' = default shield logo)
  --support LINK          @telegram_id, t.me/..., https://...
  --accent NAME|#HEX      indigo emerald rose amber sky violet fuchsia pink red orange lime teal cyan blue, or #rrggbb
  --bg-dark #HEX          background of the dark theme  ('-' = built-in default)
  --bg-light #HEX         background of the light theme ('-' = built-in default)
  --lang fa|en            default language         --theme dark|light|auto
  --force                 reinstall even if the version is the same
  --remote                ignore a local index.html and download from GitHub
  --branch NAME           GitHub branch (default: $BRANCH)
  --no-restart            do not restart Pasarguard
  -h, --help              this help
EOF
}

# ---- args -------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    install|update|brand|status|uninstall) ACTION="$1";;
    -y|--yes) YES=1;; --force) FORCE=1;; --remote) USE_REMOTE=1;; --no-restart) NO_RESTART=1;;
    --name) OPT_NAME="${2:?}"; HAVE_NAME=1; shift;;
    --subtitle-fa) OPT_SUB_FA="${2:?}"; HAVE_SUB_FA=1; shift;;
    --subtitle-en) OPT_SUB_EN="${2:?}"; HAVE_SUB_EN=1; shift;;
    --logo) OPT_LOGO="${2:?}"; HAVE_LOGO=1; shift;;
    --support) OPT_SUPPORT="${2:?}"; HAVE_SUPPORT=1; shift;;
    --accent) OPT_ACCENT="${2:?}"; HAVE_ACCENT=1; shift;;
    --bg-dark) OPT_BGD="${2:?}"; HAVE_BGD=1; shift;;
    --bg-light) OPT_BGL="${2:?}"; HAVE_BGL=1; shift;;
    --lang) OPT_LANG="${2:?}"; HAVE_LANG=1; shift;;
    --theme) OPT_THEME="${2:?}"; HAVE_THEME=1; shift;;
    --branch) BRANCH="${2:?}"; RAW_BASE="https://raw.githubusercontent.com/$GH_USER/$REPO_NAME/$BRANCH"; shift;;
    -h|--help) usage; exit 0;;
    *) die "Unknown option: $1  (try --help)";;
  esac; shift
done

# ---- main -------------------------------------------------------------------
menu() {
  while :; do
    local cur rem="" tag=""; cur="$(installed_version 2>/dev/null || true)"
    command -v curl >/dev/null 2>&1 && rem="$(curl -fsSL --max-time 4 "$RAW_BASE/VERSION" 2>/dev/null | tr -d '[:space:]' | head -c 32 || true)"
    [[ -z "$rem" ]] && rem="$(local_version)"
    banner "${rem:-$cur}"
    if [[ -n "$cur" ]]; then
      if [[ -n "$rem" ]] && ver_gt "$rem" "$cur"; then tag="${YEL}update available: v$cur ${ARW} v$rem${R}"; else tag="${GRN}installed v$cur${R}"; fi
    else tag="${D}not installed${R}"; fi
    say "Status: $tag"; echo
    printf '    %s1%s  Install\n    %s2%s  Update            %s(keeps your branding)%s\n    %s3%s  Change branding   %s(name, logo, colors)%s\n    %s4%s  Status\n    %s5%s  Uninstall\n    %s0%s  Exit\n\n' \
      "$B$ACC" "$R" "$B$ACC" "$R" "$D" "$R" "$B$ACC" "$R" "$D" "$R" "$B$ACC" "$R" "$B$ACC" "$R" "$B$ACC" "$R"
    local c; ask c "Select" ""
    case "$c" in
      1) do_install;; 2) do_update;; 3) do_brand;; 4) do_status;; 5) do_uninstall;; 0|q|Q|"") echo; exit 0;;
      *) warn "Invalid choice"; sleep 1; continue;;
    esac
    echo; ask c "Press Enter to return to the menu (or type 0 to exit)" ""; [[ "$c" == 0 ]] && exit 0
  done
}

if [[ -z "$ACTION" ]]; then
  (( YES )) && die "Specify a command with --yes (install | update | brand | status | uninstall)."
  have_tty || die "No terminal available. Use: bash install.sh install --yes --name ..."
  menu
else
  banner "$(remote_version 2>/dev/null || local_version)"
  case "$ACTION" in install) do_install;; update) do_update;; brand) do_brand;; status) do_status;; uninstall) do_uninstall;; esac
fi
