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
OPT_NAME=""; OPT_SUB_FA=""; OPT_SUB_EN=""; OPT_LOGO=""; OPT_SUPPORT=""; OPT_ACCENT=""; OPT_LANG=""; OPT_THEME=""
HAVE_NAME=0; HAVE_SUB_FA=0; HAVE_SUB_EN=0; HAVE_LOGO=0; HAVE_SUPPORT=0; HAVE_ACCENT=0; HAVE_LANG=0; HAVE_THEME=0

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
d = {"name":"Teper","subtitle":{"fa":"پنل اشتراک","en":"Subscription panel"},"logoUrl":"","supportUrl":"","accent":"indigo","lang":"fa","theme":"dark","credit":True}
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
pick_accent() {
  local cur="${1:-indigo}" a
  say "Accent color:" >&2
  printf '    %s1%s \033[48;5;105m  \033[0m Indigo   %s2%s \033[48;5;79m  \033[0m Emerald   %s3%s \033[48;5;204m  \033[0m Rose\n' "$B" "$R" "$B" "$R" "$B" "$R" >&2
  printf '    %s4%s \033[48;5;214m  \033[0m Amber    %s5%s \033[48;5;75m  \033[0m Sky\n' "$B" "$R" "$B" "$R" >&2
  say "  ${D}or type: violet fuchsia pink red orange lime teal cyan blue, or a hex like #ff5a5f${R}" >&2
  local def=1; case "$cur" in indigo) def=1;; emerald) def=2;; rose) def=3;; amber) def=4;; sky) def=5;; *) def="$cur";; esac
  ask a "Choose 1-5 / name / #hex" "$def"
  case "$a" in
    1|indigo) echo indigo;; 2|emerald) echo emerald;; 3|rose) echo rose;; 4|amber) echo amber;; 5|sky) echo sky;;
    violet|fuchsia|pink|red|orange|lime|teal|cyan|blue) echo "$a";;
    *) if [[ "$a" =~ ^#[0-9A-Fa-f]{6}$ ]]; then echo "$a"; else echo indigo; fi;;
  esac
}
collect_config() { # fills ANS_JSON using saved values as defaults
  local cur; cur="$(STATE="$STATE_FILE" TEPER_ANS="{}" py_cfg)"
  getc() { CUR="$cur" python3 -c 'import json,os,sys;d=json.loads(os.environ["CUR"]);k=sys.argv[1].split(".");
for x in k: d=d[x]
print(d)' "$1"; }
  local name sfa sen logo support accent lang theme v
  name="$(getc name)"; sfa="$(getc subtitle.fa)"; sen="$(getc subtitle.en)"; logo="$(getc logoUrl)"; support="$(getc supportUrl)"; accent="$(getc accent)"; lang="$(getc lang)"; theme="$(getc theme)"
  (( HAVE_NAME ))    && name="$OPT_NAME"
  (( HAVE_SUB_FA ))  && sfa="$OPT_SUB_FA"
  (( HAVE_SUB_EN ))  && sen="$OPT_SUB_EN"
  (( HAVE_LOGO ))    && logo="$OPT_LOGO"
  (( HAVE_SUPPORT )) && support="$OPT_SUPPORT"
  (( HAVE_ACCENT ))  && accent="$OPT_ACCENT"
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
    (( HAVE_LANG )) || { ask lang "Default language (fa/en)" "$lang"; }
    (( HAVE_THEME )) || { ask theme "Default theme (dark/light/auto)" "$theme"; }
  else
    v="$(norm_support "$support")"; [[ "$v" == INVALID ]] && die "Invalid --support value."; support="$v"
    [[ "$logo" =~ ^(-|none)$ ]] && logo=""
    [[ -z "$logo" || "$logo" =~ ^https:// ]] || die "--logo must be an https:// URL."
  fi
  ANS_JSON="$(N="$name" A="$sfa" E="$sen" L="$logo" S="$support" C="$accent" G="$lang" T="$theme" python3 -c '
import json,os;e=os.environ
print(json.dumps({"name":e["N"],"subtitle":{"fa":e["A"],"en":e["E"]},"logoUrl":e["L"],"supportUrl":e["S"],"accent":e["C"],"lang":e["G"],"theme":e["T"]}, ensure_ascii=False))')"
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
        ("Support", c["supportUrl"] or "(none)"), ("Accent", c["accent"]), ("Language", c["lang"]), ("Theme", c["theme"])]
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
