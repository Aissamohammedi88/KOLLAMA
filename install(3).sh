#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
#  install.sh — Cousin Runner v2.0 (remplace Ollama)
#  Python pur + llama-server statique — aucune dépendance, aucune compilation.
#  Identité : port 11435 (jamais 11434), home ~/.cousin, binaire "cousin".
# ════════════════════════════════════════════════════════════════════════
set -Eeuo pipefail
B='\033[1;34m'; G='\033[1;32m'; Y='\033[1;33m'; R='\033[1;31m'; N='\033[0m'
say(){ printf "${B}[*]${N} %s\n" "$1"; }
ok(){  printf "${G}[OK]${N} %s\n" "$1"; }
warn(){ printf "${Y}[!]${N}  %s\n" "$1"; }
err(){ printf "${R}[X]${N} %s\n" "$1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COUSIN_HOME="${COUSIN_HOME:-$HOME/.cousin}"
LOCAL_BIN="$HOME/.local/bin"

say "Installation de Cousin Runner v2.0..."
say "Identité : port 11435 — le port d'Ollama (11434) reste intouchable"

# --- Python (pré-requis unique)
command -v python3 >/dev/null 2>&1 || { err "python3 est requis (Python 3.8+). Installe-le : sudo apt install python3"; exit 1; }
PYV=$(python3 -c 'import sys; print("%d.%d"%sys.version_info[:2])')
ok "Python $PYV détecté"

# --- Home Cousin
mkdir -p "$COUSIN_HOME/models" "$COUSIN_HOME/bin" "$COUSIN_HOME/logs" "$LOCAL_BIN"

# --- Backend llama-server (statique, 0 .so)
say "Installation du backend llama-server (statique)..."
if [ -f "$SCRIPT_DIR/bin/llama-server" ]; then
  cp -f "$SCRIPT_DIR/bin/llama-server" "$COUSIN_HOME/bin/llama-server"
  chmod +x "$COUSIN_HOME/bin/llama-server"
  ok "Backend installé (statique — aucun .so)"
else
  err "bin/llama-server manquant dans $SCRIPT_DIR"
  exit 1
fi

# --- Binaire cousin (script Python)
say "Installation du binaire cousin..."
cp -f "$SCRIPT_DIR/cousin" "$LOCAL_BIN/cousin"
chmod +x "$LOCAL_BIN/cousin"
# aussi dans ~/.cousin/bin (fallback)
cp -f "$SCRIPT_DIR/cousin" "$COUSIN_HOME/bin/cousin"
chmod +x "$COUSIN_HOME/bin/cousin"
ok "Binaire cousin installé → $LOCAL_BIN/cousin"

# --- Modèles bundled (SmolLM2 fourni pour démarrage immédiat)
if ls "$SCRIPT_DIR/models/"*.gguf >/dev/null 2>&1; then
  say "Installation des modèles bundled..."
  for f in "$SCRIPT_DIR/models/"*.gguf; do
    name=$(basename "$f")
    if [ ! -f "$COUSIN_HOME/models/$name" ]; then
      cp -f "$f" "$COUSIN_HOME/models/"
    fi
  done
  ok "$(ls "$COUSIN_HOME/models/"*.gguf 2>/dev/null | wc -l) modèle(s) installé(s)"
fi

# --- Modèle auto-téléchargé (si aucun bundled — tarball slim ≤ 25 Mo)
if ! ls "$COUSIN_HOME/models/"*.gguf >/dev/null 2>&1; then
  say "Aucun modèle bundled — téléchargement auto de SmolLM2-135M-Instruct (Q4_0, ~88 Mo)..."
  say "  (depuis bartowski/SmolLM2-135M-Instruct-GGUF sur HuggingFace)"
  DEFAULT_REPO="bartowski/SmolLM2-135M-Instruct-GGUF"
  DEFAULT_FILE="SmolLM2-135M-Instruct-Q4_0.gguf"
  URL="https://huggingface.co/${DEFAULT_REPO}/resolve/main/${DEFAULT_FILE}"
  if command -v curl >/dev/null 2>&1; then
    if curl -L --fail --progress-bar -o "$COUSIN_HOME/models/$DEFAULT_FILE" "$URL" -H "User-Agent: cousin/2.0"; then
      ok "Modèle téléchargé : $DEFAULT_FILE ($(du -h "$COUSIN_HOME/models/$DEFAULT_FILE" | cut -f1))"
    else
      warn "Téléchargement échoué — tu pourras le faire manuellement :"
      warn "  cousin pull $DEFAULT_REPO"
    fi
  else
    warn "curl absent — télécharge manuellement : cousin pull $DEFAULT_REPO"
  fi
fi

# --- PATH
case ":$PATH:" in
  *":$LOCAL_BIN:"*) ;;
  *)
    warn "$LOCAL_BIN n'est pas dans ton PATH"
    warn "→ Ajoute dans ~/.bashrc : export PATH=\"$LOCAL_BIN:\$PATH\""
    warn "  (ou lance cousin via : $LOCAL_BIN/cousin)"
    ;;
esac

# --- Test
say "Test de l'installation..."
export PATH="$LOCAL_BIN:$PATH"
export COUSIN_HOME="$COUSIN_HOME"
V=$(cousin --version 2>&1 || $LOCAL_BIN/cousin --version 2>&1)
case "$V" in
  *2.*) ok "cousin $V" ;;
  *) err "cousin ne répond pas ($V)"; exit 1 ;;
esac
LV=$("$COUSIN_HOME/bin/llama-server" --version 2>&1 | head -1)
ok "backend : $LV"

# --- Modèles détectés
NM=$(cousin list 2>/dev/null | grep -c "\.gguf\|Q4_K\|Instruct" || true)
ok "Modèles disponibles : $NM (dépose d'autres .gguf dans $COUSIN_HOME/models/)"

echo
echo -e "${G}══════════════════════════════════════════════════════════════${N}"
echo -e "${G}  ✅  COUSIN INSTALLÉ${N}"
echo -e "${G}══════════════════════════════════════════════════════════════${N}"
echo -e "   Port      : ${B}11435${N} — ${G}NOTRE identité${N} (jamais 11434 d'Ollama)"
echo -e "   Home      : $COUSIN_HOME"
echo -e "   Binaire   : $LOCAL_BIN/cousin"
echo -e "   WebGUI    : ${B}http://localhost:11435${N}  (après : cousin web)"
echo -e ""
echo -e "   ${B}Démarre maintenant :${N}"
echo -e "     cousin web            # serveur + ouvre le navigateur"
echo -e "     cousin list           # voir les modèles"
echo -e "     cousin pull <repo>    # télécharger un modèle HuggingFace"
echo -e "     cousin run <modèle>   # chat dans le terminal"
echo -e ""
echo -e "   En hommage au créateur originel — Repose en paix."
echo -e "${G}══════════════════════════════════════════════════════════════${N}"
