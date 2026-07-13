#!/usr/bin/env bash
set -euo pipefail

repo_dir="${WILDCARD_REPO_DIR:-$HOME/wildcard}"
repo_url="git@github.com:nisargpatel0505-lang/wildcard.git"
ssh_command="ssh -i $HOME/.ssh/wildcard_github -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

if [[ -e "$repo_dir" && ! -d "$repo_dir/.git" ]]; then
  echo "$repo_dir exists but is not a Git clone" >&2
  exit 2
fi

if [[ ! -d "$repo_dir/.git" ]]; then
  GIT_SSH_COMMAND="$ssh_command" git clone "$repo_url" "$repo_dir"
fi

git -C "$repo_dir" config core.sshCommand "ssh -i ~/.ssh/wildcard_github -o IdentitiesOnly=yes"
chmod +x "$repo_dir/deploy/update-pi.sh"
ln -sfn "$repo_dir/deploy/update-pi.sh" "$HOME/update-wildcard-from-github.sh"
"$HOME/update-wildcard-from-github.sh"

