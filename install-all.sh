#!/bin/bash
#######################################
# Automate the install process for .cmdw 
# wrapper for all users on a given system.
#
# Install:
#   source <(curl -s https://raw.githubusercontent.com/0xZDH/cmdw/master/install-all.sh)
#######################################

# Validate the current terminal is Bash or Zsh.
# Assume this is the terminal all users will use.
[ -n "$BASH_VERSION" -o -n "$ZSH_VERSION" ] || return 0

# Download cmdw.sh to our home directory. Force the file
# to be overwritten when it exists to allow for updates
# to be installed.
curl -s -o "$HOME/.cmdw" \
  -q "https://raw.githubusercontent.com/0xZDH/cmdw/master/cmdw.sh"

# Identify current shell type
[ -n "$ZSH_VERSION" ] && \
  shell_file=".zshrc" || \
  shell_file=".bashrc"

# Identify, bsaed on system, where the user's home directories
# are located
if [[ "$(uname)" == "Darwin" ]]; then
    # OS X
    home_dir="/Users"
else
    # Linux
    home_dir="/home"
fi

# Loop over all users on the system and set up cmdw for
# each user's profile
for user in $(ls "$home_dir"); do
    # Ignore the 'Shared' dir on OS X systems
    if [[ "$user" == "Shared" ]]; then
        continue
    fi

    # Define the user's home dir
    user_dir="$home_dir/$user"

    # Copy the .cmdw script to each user's home dir
    if [ "$HOME" != "$user_dir" ]; then
        cp "$HOME/.cmdw" "$user_dir/"
    fi

    # Add .cmdw to each user's shell profile
    [ ! "$( grep 'source $HOME/.cmdw' "$user_dir/$shell_file" )" ] && \
      echo '[ -f $HOME/.cmdw ] && source $HOME/.cmdw' >> "$user_dir/$shell_file"

    # Clean up
    unset user_dir
done

# Reload our shell profile
source "$HOME/$shell_file"

# Clean up
unset shell_file
unset home_dir