#!/usr/bin/env bash
# WorktreeCreate hook: cree reellement le worktree git et renvoie son chemin en texte brut sur stdout.
# Sans cet hook, EnterWorktree echoue avec "hook succeeded but returned no worktree path".
# IMPORTANT: seul le chemin doit sortir sur stdout (pas de JSON, pas de sortie git) : le
# runtime prend stdout tel quel comme chemin de destination.
set -euo pipefail

input=$(cat)
name=$(node -e "
let d={};
try{d=JSON.parse(require('fs').readFileSync(0,'utf8'));}catch(e){}
process.stdout.write(d.name||d.worktreeName||d.branch||'');
" <<< "$input" 2>/dev/null || true)

if [ -z "$name" ]; then
  name="worktree-$(date +%s)"
fi

# Convention NNNN-slug (CLAUDE.md) : un nom "worktree-<slug>" perd son prefixe generique.
case "$name" in
  worktree-*) branch="${name#worktree-}" ;;
  *) branch="$name" ;;
esac

repo_root=$(git rev-parse --show-toplevel)
dir="$repo_root/.claude/worktrees/$branch"

if git -C "$repo_root" worktree list --porcelain | grep -qx "worktree $dir"; then
  abspath="$dir"
else
  mkdir -p "$repo_root/.claude/worktrees" >&2
  git -C "$repo_root" fetch origin dev --quiet >&2 2>/dev/null || true
  base="HEAD"
  if git -C "$repo_root" rev-parse --verify origin/dev >/dev/null 2>&1; then
    base="origin/dev"
  elif git -C "$repo_root" rev-parse --verify dev >/dev/null 2>&1; then
    base="dev"
  fi
  if git -C "$repo_root" rev-parse --verify "$branch" >/dev/null 2>&1; then
    git -C "$repo_root" worktree add "$dir" "$branch" >&2
  else
    git -C "$repo_root" worktree add -b "$branch" "$dir" "$base" >&2
  fi
  abspath="$dir"
fi

printf '%s' "$abspath"
