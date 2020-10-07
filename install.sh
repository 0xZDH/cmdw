#!/bin/bash
#######################################
# Automate the install process for .cmdw 
# wrapper.
#
# Install:
#   source <(curl -s https://raw.githubusercontent.com/0xZDH/cmdw/master/install.sh)
#######################################

# Validate the current terminal is Bash or Zsh.
[ -n "$BASH_VERSION" -o -n "$ZSH_VERSION" ] || return 0

# Download cmdw.sh to our home directory. Force the file
# to be overwritten when it exists to allow for updates
# to be installed.
curl -s -o "$HOME/.cmdw" \
  -q "https://raw.githubusercontent.com/0xZDH/cmdw/master/cmdw.sh"

# Identify current shell type
[ -n "$ZSH_VERSION" ] && \
  shell_file="$HOME/.zshrc" || \
  shell_file="$HOME/.bashrc"

# Add .cmdw to our shell profile
[ ! "$( grep 'source $HOME/.cmdw' "$shell_file" )" ] && \
  echo '[ -f $HOME/.cmdw ] && source $HOME/.cmdw' >> "$shell_file"

# Reload our shell profile
source "$shell_file"

# Clean up
unset shell_file
