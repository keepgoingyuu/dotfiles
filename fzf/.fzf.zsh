# Setup fzf
# ---------
if [[ ! "$PATH" == */mnt/c/Users/user/.fzf/bin* ]]; then
  PATH="/mnt/c/Users/user/.fzf/bin:${PATH}"
fi

source <(fzf --zsh)
