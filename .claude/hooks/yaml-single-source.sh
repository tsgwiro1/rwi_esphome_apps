#!/bin/bash
# Erzwingt vor jedem Commit mit gestagter YAML die Einzelquellen-Pruefung:
# Jeder Parameter, jede Konfiguration steht nur an EINER Stelle in der YAML.
#
# Aufruf 1 (durch den PreToolUse-Hook): liest das Hook-JSON von stdin, blockiert
#   den Commit und schreibt die zu pruefenden Zeilen nach stderr.
# Aufruf 2 (durch Claude, nach der Pruefung): mit --ok, setzt die Marke fuer
#   genau diesen Stand des Index; der naechste Commit laeuft dann durch.
#
# Die Marke haengt am Inhalt des Index. Wird nach der Pruefung noch etwas
# gestaged oder geaendert, verfaellt sie und die Pruefung wird erneut verlangt.

set -u

if [ "${1:-}" != "--ok" ]; then
  # stdin ist das Hook-JSON. Alles ausser einem git commit geht sofort durch -
  # auch verkettete Formen wie "cd x && git commit" oder "git -C . commit".
  CMD=$(cat | sed 's/[[:cntrl:]]/ /g')
  echo "$CMD" | grep -qE 'git[^;&|]*\bcommit\b' || exit 0
fi

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

STAGED_YAML=$(git diff --cached --name-only --diff-filter=ACMR -- '*.yaml' '*.yml')
[ -z "$STAGED_YAML" ] && exit 0

KEY=$(git diff --cached -- '*.yaml' '*.yml' | shasum | cut -d' ' -f1)
MARK="$(git rev-parse --git-dir)/claude-yaml-single-source"

if [ "${1:-}" = "--ok" ]; then
  echo "$KEY" > "$MARK"
  echo "Einzelquellen-Pruefung quittiert. Der Commit laeuft jetzt durch."
  exit 0
fi

[ -f "$MARK" ] && [ "$(cat "$MARK")" = "$KEY" ] && exit 0

{
  echo "EINZELQUELLEN-PRUEFUNG (Repo-Regel, gilt fuer jeden Chat)"
  echo
  echo "Alle Parameter und Konfigurationen stehen nur an EINER Stelle in der YAML."
  echo "Keine Doppelung. Gestagt sind:"
  echo "$STAGED_YAML" | sed 's/^/  /'
  echo
  echo "Diese Zeilen kommen neu dazu oder aendern sich - jede einzeln pruefen:"
  git diff --cached -U0 -- '*.yaml' '*.yml' \
    | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+//' \
    | grep -vE '^\s*#' \
    | grep -E '(^\s*[a-z_0-9]+:\s*\S)|[0-9]+\.[0-9]+|\b[0-9]{2,}\b' \
    | head -60 | sed 's/^/  /'
  echo
  echo "Fuer jeden Wert beantworten:"
  echo "  1. Steht derselbe Wert schon woanders - in substitutions, in einem"
  echo "     zweiten Lambda, als Default eines number/select, oder in common/?"
  echo "  2. Wenn ja: EINE Stelle ist die Quelle (substitution oder id()), die"
  echo "     andere referenziert sie. Literal kopieren ist nicht zulaessig."
  echo "  3. Grenzfaelle nennen statt stillschweigend durchwinken."
  echo
  echo "Danach quittieren und den Commit wiederholen:"
  echo "  .claude/hooks/yaml-single-source.sh --ok"
} >&2
exit 2
