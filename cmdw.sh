#!/bin/bash
#######################################
# This is a command line wrapper to support timestamping
# start/stop times of command executions. This can also
# act as a template for custom command logging.
#
# VERSION: v0.1.1
#
# Installation:
# 1. Write this script to your home folder as `.cmdw`:
#    vim ~/.cmdw
# 2. Source the cmdw script:
#    source ~/.cmdw
# 3. For persistence, add it to your .bashrc or similar:
#    source "$HOME/.cmdw"
#
# History size:
# If required, the user can modify the size of the
# maintained history file by setting CMDWSIZE as an
# environment variable (Default: 3,000):
#    export CMDWSIZE=1000
#
# Command referencing:
# 1. List the executed commands in .cmdw_history with
#    line numbers via:
#    cat -n .cmdw_history | grep '#'
# 2. Then, grab the command and its timestamps using
#    (where `N` is the identified line number):
#    sed -n 'N,$p' .cmdw_history | head -n3
# 3. For easy referencing, use the builtin function:
#    cmdw_history
#    cmdw_history <id>
#
# Enable/Disable:
# By default, cmdw is enabled. To disable the wrapper,
# use the built in functions:
#    cmdw_disable
#    cmdw_enable
# Or export the following variable to disable the wrapper:
#    export CMDW_ENABLE=0
# and to re-enable the wrapper:
#    export CMDW_ENABLE=1
# To default disable the wrapper, add the following to
# your .bashrc or similar after cmdw is sourced:
#    export CMDW_ENABLE=0
#
# Ignoring commands:
# Commands to be ignored by cmdw are stored in the
# `CMDW_IGNORE` environment variable. The user can
# directly modify this array in a given terminal
# session or globally in their .bashrc or similar.
# To add a command to the list, whether globally or
# locally per session:
#    CMDW_IGNORE+=('command')
# And to allow the cmdw wrapper to log on every command:
#    CMDW_IGNORE=()
#######################################

# Validate the current terminal is Bash or Zsh.
[ -n "$BASH_VERSION" -o -n "$ZSH_VERSION" ] || return 0

# Validate the current shell is interactive.
[[ $- == *i* ]] || return 0

# Avoid duplicate inclusions of this wrapper.
[[ "${__cmdw_imported:-}" == 'defined' ]] && return 0

# Define the import of this wrapper.
__cmdw_imported='defined'

# >----- START CMDW HANDLING -----< #

# Generate a log file, similar to .bash_history, but with
# timestamps. Allow the user to specify a custom CMDWSIZE
# via exporting, or use a default value of 3,000 lines.
__cmdw_history_file="$HOME/.cmdw_history"
CMDWSIZE="${CMDWSIZE:-3000}"

# Ignore list for the cmdw wrapper to avoid logging and
# performing actions on. The user can expand this list
# in the .bashrc by specifying, after .cmdw has been
# sourced, `CMDW_IGNORE+=('command')`. The user can also
# extend the ignore list per session by adding to the
# list within a terminal session with the same command.
CMDW_IGNORE=( 'clear' 'cmdw_enable' 'cmdw_disable' 'cmdw_history'
              'cmdw_history +[0-9]{1,}' )

# Enable the wrapper by default.
CMDW_ENABLE=1

# Enable/Disable functions for easy toggling.
cmdw_enable() { export CMDW_ENABLE=1; }
cmdw_disable() { export CMDW_ENABLE=0; }

# Quick reference of cmdw wrapper history.
cmdw_history() {
    local __cmdw_id=$1
    if [ -n "$__cmdw_id" ]; then
        sed -n ''"$__cmdw_id"',$p' "$HOME/.cmdw_history" | head -n3
    else
        grep -n '^#' "$HOME/.cmdw_history" | \
        sed -E 's/^([0-9]{1,}):# ?(.*)$/ \1   \2/'
    fi
}

# Trim leading and trailing whitespace from $2 and write the
# data to the variable name passed as $1. This is a
# reimplementation of the bash-preexec function because:
# 1) bash-preexec is not always going to be installed
# 2) The bash-preexec handling does not expand properly on Zsh
__cmdw_trim_whitespace() {
    local var=${1:?}
    local text=${2:-}
    text="$(echo -e "${text}" | sed -e 's/^[[:space:]]*// ; s/[[:space:]]*$//')"
    printf -v "$var" '%s' "$text"
}

# Although we can check for the presence of an item in
# an array, we loop over the ignore list to allow the
# capabilities of using RegExp's as a way to deny
# wrapping a command.
__cmdw_check_array() {
    local __command=${1:-}
    for item in "${CMDW_IGNORE[@]}"; do
        # In order to support older versions of bash, we
        # use grep instead of =~.
        # if [[ "$__command" =~ ^"$item";?$ ]]; then
        if grep -Eq "^$item;?$" <<< "$__command"; then
            return 0
        fi
    done
    return 1
}

# Set __cmdw_login to avoid execution of this wrapper on
# login.
__cmdw_login=1

# In order to preserve the initial timestamp collected
# before the execution of the users command, set
# __cmdw_preexec_enable to handle this. This is because the DEBUG
# trap will also execute before the PROMPT_COMMAND/precmd
# calls so we only want to execute once before that and
# then re-enable this once we have handled post-execution.
__cmdw_preexec_enable=1

# Perform pre-command execution handling to collect the
# initial date timestamp.
__cmdw_preexec() {
    # Only perform pre-handling when the cmdw wrapper is
    # enabled. Check if CMDW_ENABLE is set or if CMDW_ENABLE
    # is not `1`.
    [[ -z "${CMDW_ENABLE:-}" || "$CMDW_ENABLE" -ne 1 ]] && return 0

    # Only handle pre-execution once per command - Do not
    # perform __cmdw_preexec handling on post-exec processing.
    [ -z "${__cmdw_preexec_enable:-}" ] && return 0
    unset __cmdw_preexec_enable

    # Grab the start timestamp pre-execution.
    __cmdw_start_date="$(date -u)"
}

# Perform post-command execution handling to collect the
# stop date timestamp and log our data.
__cmdw_precmd() {
    # Reset __cmdw_preexec_enable after post-execution handling
    # so the wrapper will run on next command.
    __cmdw_preexec_enable=1

    # Avoid wrapper handling at first login.
    if [ -n "$__cmdw_login" ]; then
        unset __cmdw_login
        return 0
    fi

    # Only perform post-handling when the cmdw wrapper is
    # enabled. Check if CMDW_ENABLE is set or if CMDW_ENABLE
    # is not `1`.
    [[ -z "${CMDW_ENABLE:-}" || "$CMDW_ENABLE" -ne 1 ]] && return 0

    # Grab the stop timestamp post-execution.
    __cmdw_stop_date="$(date -u)"

    # Logging & Output

    # Grab the last command from history to ensure we
    # capture all pipes and redirections.
    local __hist_len
    local __cmdw_command

    # Determine the formatting for the history command
    # since bash and zsh vary.
    [ -n "$BASH_VERSION" ] && __hist_len=1 || __hist_len=-1

    # Collect last command from history.
    __cmdw_command=$(
        export LC_ALL=C
        HISTTIMEFORMAT= builtin history $__hist_len | sed '1 s/^ *[0-9][0-9]*[* ] //'
    )

    # Ensure scenarios like tab-completions don't keep trailing
    # whitespace. This is to ensure our command compare on the
    # next line is accurate.
    __cmdw_trim_whitespace __cmdw_command "$__cmdw_command"

    # Avoid timestamping commands specified in the CMDW_IGNORE
    # list as well as empty commands.
    __cmdw_check_array "$__cmdw_command" || \
        [ -z "$__cmdw_start_date" ] && \
        return 0

    # Grep commands via '#' for easy cross-reference.
    # Based on the shell environment, we need to account for commands
    # than span multiple lines. In Bash, we set the `cmdhist` option
    # which will collapse all commands for easy referencing, but in
    # zsh we need to account for multi-line commands. As a result,
    # we need to conditionally transform the command by replacing
    # newlines with escaped newline characters in order to preserve
    # the original state while collapsing to a single line in our
    # log history.
    echo "# ""$__cmdw_command" | \
    ( [[ "$__cmdw_command" == *$'\n'* ]] && \
      sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' || \
      awk '{print $0}') \
    >> $__cmdw_history_file

    echo ""  # For cleaner terminal output
    echo -e "start    $__cmdw_start_date" | tee -a $__cmdw_history_file
    echo -e "stop     $__cmdw_stop_date" | tee -a $__cmdw_history_file

    # Maintain log file size by writing a temp log file of the
    # specified log size and moving it back to our history file
    # location. This is to aviod storing too many lines in memory
    # when trying to truncate the log data. First, write the last
    # N lines of the log file to a temp location.
    local __cmdw_history_file_bak="/tmp/$(basename "$__cmdw_history_file").tmp"
    tail -"$CMDWSIZE" "$__cmdw_history_file" > "$__cmdw_history_file_bak"
    # Next, move the temp file to overwrite the existing log
    # file.
    mv "$__cmdw_history_file_bak" "$__cmdw_history_file"
    # Finally, remove the temp log file.
    rm -rf "$__cmdw_history_file_bak" > /dev/null 2>&1

    # We use these to track preexec and precmd calls, so we
    # unset set them for each command rotation.
    unset __cmdw_start_date
    unset __cmdw_stop_date
}

# >----- END CMDW HANDLING -----< #

__install_bash_preexec () {
# >----- START BASH-PREEXEC HANDLING -----< #
# https://github.com/rcaloras/bash-preexec/blob/master/bash-preexec.sh
#
# The following chunk of code, bash-preexec.sh, is
# licensed like this:
# The MIT License
#
# Copyright (c) 2017 Ryan Caloras and contributors (see https://github.com/rcaloras/bash-preexec)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Author: Ryan Caloras (ryan@bashhub.com)
# Forked from Original Author: Glyph Lefkowitz
#
# V0.4.1

# Avoid duplicate inclusion
if [[ "${__bp_imported:-}" == "defined" ]]; then
    return 0
fi
__bp_imported="defined"

# Should be available to each precmd and preexec
# functions, should they want it. $? and $_ are available as $? and $_, but
# $PIPESTATUS is available only in a copy, $BP_PIPESTATUS.
# TODO: Figure out how to restore PIPESTATUS before each precmd or preexec
# function.
__bp_last_ret_value="$?"
BP_PIPESTATUS=("${PIPESTATUS[@]}")
__bp_last_argument_prev_command="$_"

__bp_inside_precmd=0
__bp_inside_preexec=0

# Initial PROMPT_COMMAND string that is removed from PROMPT_COMMAND post __bp_install
__bp_install_string=$'__bp_trap_string="$(trap -p DEBUG)"\ntrap - DEBUG\n__bp_install'

# Fails if any of the given variables are readonly
# Reference https://stackoverflow.com/a/4441178
__bp_require_not_readonly() {
  local var
  for var; do
    if ! ( unset "$var" 2> /dev/null ); then
      echo "bash-preexec requires write access to ${var}" >&2
      return 1
    fi
  done
}

# Remove ignorespace and or replace ignoreboth from HISTCONTROL
# so we can accurately invoke preexec with a command from our
# history even if it starts with a space.
__bp_adjust_histcontrol() {
    local histcontrol
    histcontrol="${HISTCONTROL//ignorespace}"
    # Replace ignoreboth with ignoredups
    if [[ "$histcontrol" == *"ignoreboth"* ]]; then
        histcontrol="ignoredups:${histcontrol//ignoreboth}"
    fi;
    export HISTCONTROL="$histcontrol"
}

# This variable describes whether we are currently in "interactive mode";
# i.e. whether this shell has just executed a prompt and is waiting for user
# input.  It documents whether the current command invoked by the trace hook is
# run interactively by the user; it's set immediately after the prompt hook,
# and unset as soon as the trace hook is run.
__bp_preexec_interactive_mode=""

# Trims leading and trailing whitespace from $2 and writes it to the variable
# name passed as $1
__bp_trim_whitespace() {
    local var=${1:?} text=${2:-}
    text="${text#"${text%%[![:space:]]*}"}"   # remove leading whitespace characters
    text="${text%"${text##*[![:space:]]}"}"   # remove trailing whitespace characters
    printf -v "$var" '%s' "$text"
}


# Trims whitespace and removes any leading or trailing semicolons from $2 and
# writes the resulting string to the variable name passed as $1. Used for
# manipulating substrings in PROMPT_COMMAND
__bp_sanitize_string() {
    local var=${1:?} text=${2:-} sanitized
    __bp_trim_whitespace sanitized "$text"
    sanitized=${sanitized%;}
    sanitized=${sanitized#;}
    __bp_trim_whitespace sanitized "$sanitized"
    printf -v "$var" '%s' "$sanitized"
}

# This function is installed as part of the PROMPT_COMMAND;
# It sets a variable to indicate that the prompt was just displayed,
# to allow the DEBUG trap to know that the next command is likely interactive.
__bp_interactive_mode() {
    __bp_preexec_interactive_mode="on";
}


# This function is installed as part of the PROMPT_COMMAND.
# It will invoke any functions defined in the precmd_functions array.
__bp_precmd_invoke_cmd() {
    # Save the returned value from our last command, and from each process in
    # its pipeline. Note: this MUST be the first thing done in this function.
    __bp_last_ret_value="$?" BP_PIPESTATUS=("${PIPESTATUS[@]}")

    # Don't invoke precmds if we are inside an execution of an "original
    # prompt command" by another precmd execution loop. This avoids infinite
    # recursion.
    if (( __bp_inside_precmd > 0 )); then
      return
    fi
    local __bp_inside_precmd=1

    # Invoke every function defined in our function array.
    local precmd_function
    for precmd_function in "${precmd_functions[@]}"; do

        # Only execute this function if it actually exists.
        # Test existence of functions with: declare -[Ff]
        if type -t "$precmd_function" 1>/dev/null; then
            __bp_set_ret_value "$__bp_last_ret_value" "$__bp_last_argument_prev_command"
            # Quote our function invocation to prevent issues with IFS
            "$precmd_function"
        fi
    done
}

# Sets a return value in $?. We may want to get access to the $? variable in our
# precmd functions. This is available for instance in zsh. We can simulate it in bash
# by setting the value here.
__bp_set_ret_value() {
    return ${1:-}
}

__bp_in_prompt_command() {

    local prompt_command_array
    IFS=$'\n;' read -rd '' -a prompt_command_array <<< "$PROMPT_COMMAND"

    local trimmed_arg
    __bp_trim_whitespace trimmed_arg "${1:-}"

    local command trimmed_command
    for command in "${prompt_command_array[@]:-}"; do
        __bp_trim_whitespace trimmed_command "$command"
        if [[ "$trimmed_command" == "$trimmed_arg" ]]; then
            return 0
        fi
    done

    return 1
}

# This function is installed as the DEBUG trap.  It is invoked before each
# interactive prompt display.  Its purpose is to inspect the current
# environment to attempt to detect if the current command is being invoked
# interactively, and invoke 'preexec' if so.
__bp_preexec_invoke_exec() {

    # Save the contents of $_ so that it can be restored later on.
    # https://stackoverflow.com/questions/40944532/bash-preserve-in-a-debug-trap#40944702
    __bp_last_argument_prev_command="${1:-}"
    # Don't invoke preexecs if we are inside of another preexec.
    if (( __bp_inside_preexec > 0 )); then
      return
    fi
    local __bp_inside_preexec=1

    # Checks if the file descriptor is not standard out (i.e. '1')
    # __bp_delay_install checks if we're in test. Needed for bats to run.
    # Prevents preexec from being invoked for functions in PS1
    if [[ ! -t 1 && -z "${__bp_delay_install:-}" ]]; then
        return
    fi

    if [[ -n "${COMP_LINE:-}" ]]; then
        # We're in the middle of a completer. This obviously can't be
        # an interactively issued command.
        return
    fi
    if [[ -z "${__bp_preexec_interactive_mode:-}" ]]; then
        # We're doing something related to displaying the prompt.  Let the
        # prompt set the title instead of me.
        return
    else
        # If we're in a subshell, then the prompt won't be re-displayed to put
        # us back into interactive mode, so let's not set the variable back.
        # In other words, if you have a subshell like
        #   (sleep 1; sleep 2)
        # You want to see the 'sleep 2' as a set_command_title as well.
        if [[ 0 -eq "${BASH_SUBSHELL:-}" ]]; then
            __bp_preexec_interactive_mode=""
        fi
    fi

    if  __bp_in_prompt_command "${BASH_COMMAND:-}"; then
        # If we're executing something inside our prompt_command then we don't
        # want to call preexec. Bash prior to 3.1 can't detect this at all :/
        __bp_preexec_interactive_mode=""
        return
    fi

    local this_command
    this_command=$(
        export LC_ALL=C
        HISTTIMEFORMAT= builtin history 1 | sed '1 s/^ *[0-9][0-9]*[* ] //'
    )

    # Sanity check to make sure we have something to invoke our function with.
    if [[ -z "$this_command" ]]; then
        return
    fi

    # Invoke every function defined in our function array.
    local preexec_function
    local preexec_function_ret_value
    local preexec_ret_value=0
    for preexec_function in "${preexec_functions[@]:-}"; do

        # Only execute each function if it actually exists.
        # Test existence of function with: declare -[fF]
        if type -t "$preexec_function" 1>/dev/null; then
            __bp_set_ret_value ${__bp_last_ret_value:-}
            # Quote our function invocation to prevent issues with IFS
            "$preexec_function" "$this_command"
            preexec_function_ret_value="$?"
            if [[ "$preexec_function_ret_value" != 0 ]]; then
                preexec_ret_value="$preexec_function_ret_value"
            fi
        fi
    done

    # Restore the last argument of the last executed command, and set the return
    # value of the DEBUG trap to be the return code of the last preexec function
    # to return an error.
    # If `extdebug` is enabled a non-zero return value from any preexec function
    # will cause the user's command not to execute.
    # Run `shopt -s extdebug` to enable
    __bp_set_ret_value "$preexec_ret_value" "$__bp_last_argument_prev_command"
}

__bp_install() {
    # Exit if we already have this installed.
    if [[ "${PROMPT_COMMAND:-}" == *"__bp_precmd_invoke_cmd"* ]]; then
        return 1;
    fi

    trap '__bp_preexec_invoke_exec "$_"' DEBUG

    # Preserve any prior DEBUG trap as a preexec function
    local prior_trap=$(sed "s/[^']*'\(.*\)'[^']*/\1/" <<<"${__bp_trap_string:-}")
    unset __bp_trap_string
    if [[ -n "$prior_trap" ]]; then
        eval '__bp_original_debug_trap() {
          '"$prior_trap"'
        }'
        preexec_functions+=(__bp_original_debug_trap)
    fi

    # Adjust our HISTCONTROL Variable if needed.
    __bp_adjust_histcontrol

    # Issue #25. Setting debug trap for subshells causes sessions to exit for
    # backgrounded subshell commands (e.g. (pwd)& ). Believe this is a bug in Bash.
    #
    # Disabling this by default. It can be enabled by setting this variable.
    if [[ -n "${__bp_enable_subshells:-}" ]]; then

        # Set so debug trap will work be invoked in subshells.
        set -o functrace > /dev/null 2>&1
        shopt -s extdebug > /dev/null 2>&1
    fi;

    local existing_prompt_command
    # Remove setting our trap install string and sanitize the existing prompt command string
    existing_prompt_command="${PROMPT_COMMAND//$__bp_install_string[;$'\n']}" # Edge case of appending to PROMPT_COMMAND
    existing_prompt_command="${existing_prompt_command//$__bp_install_string}"
    __bp_sanitize_string existing_prompt_command "$existing_prompt_command"

    # Install our hooks in PROMPT_COMMAND to allow our trap to know when we've
    # actually entered something.
    PROMPT_COMMAND=$'__bp_precmd_invoke_cmd\n'
    if [[ -n "$existing_prompt_command" ]]; then
        PROMPT_COMMAND+=${existing_prompt_command}$'\n'
    fi;
    PROMPT_COMMAND+='__bp_interactive_mode'

    # Add two functions to our arrays for convenience
    # of definition.
    precmd_functions+=(precmd)
    preexec_functions+=(preexec)

    # Invoke our two functions manually that were added to $PROMPT_COMMAND
    __bp_precmd_invoke_cmd
    __bp_interactive_mode
}

# Sets an installation string as part of our PROMPT_COMMAND to install
# after our session has started. This allows bash-preexec to be included
# at any point in our bash profile.
__bp_install_after_session_init() {
    # Make sure this is bash that's running this and return otherwise.
    if [[ -z "${BASH_VERSION:-}" ]]; then
        return 1;
    fi

    # bash-preexec needs to modify these variables in order to work correctly
    # if it can't, just stop the installation
    __bp_require_not_readonly PROMPT_COMMAND HISTCONTROL HISTTIMEFORMAT || return

    local sanitized_prompt_command
    __bp_sanitize_string sanitized_prompt_command "$PROMPT_COMMAND"
    if [[ -n "$sanitized_prompt_command" ]]; then
        PROMPT_COMMAND=${sanitized_prompt_command}$'\n'
    fi;
    PROMPT_COMMAND+=${__bp_install_string}
}

# Run our install so long as we're not delaying it.
if [[ -z "${__bp_delay_install:-}" ]]; then
    __bp_install_after_session_init
fi;

# >----- END BASH-PREEXEC HANDLING -----< #
}

# >----- INITIALIZE -----< #

# When in a bash shell, install bash-preexec for better
# handling.
if [ -n "$BASH_VERSION" ]; then
    # First, we want to enable `cmdhist` to allow command
    # history to be collapsed for easier parsing.
    shopt -s cmdhist > /dev/null 2>&1

    __install_bash_preexec
    if [[ "$PROMPT_COMMAND" == *'__bp_trap_string'* ]]; then
        # Because bash-preexec is being invoked within the context
        # of this script, we must manually trigger the install
        # instead of relying on PROMPT_COMMAND to trigger it.
        __bp_trap_string="$(trap -p DEBUG)"
        trap - DEBUG
        __bp_install
        unset -f __bp_install
    fi
    unset -f __install_bash_preexec
fi

# If bash-preexec has been installed or we are running in
# a zsh shell, set up preexec/precmd - otherwise set up
# default bash trap/prompt_command. In bash, checking for
# function declarations isn't enough since bash-preexec could
# fail when certain variables are not modifiable while
# declaring function names. So instead, we check if the
# bash-preexec caller has been set as the DEBUG trap.
trap -p DEBUG | grep '__bp_preexec_invoke_exec' > /dev/null 2>&1 || \
    [ -n "$ZSH_VERSION" ] && \
    __preexec_enable=1

# Determine the type of shell and environment we have, and
# configure the wrapper accordingly.
if [ -n "$__preexec_enable" ]; then
    preexec_functions+=(__cmdw_preexec)
    precmd_functions+=(__cmdw_precmd)
    # Clean up environment variable.
    unset __preexec_enable
else
    # Use trap DEBUG to execute the __cmdw_preexec function
    # prior to user's command being executed.
    trap '__cmdw_preexec' DEBUG
    # Use 'PROMPT_COMMAND' to execute the __cmdw_precmd function
    # after a user's command and prior to the next prompt display.
    PROMPT_COMMAND=__cmdw_precmd
fi
