# cmdw - Command Wrapper

This is a command line wrapper to support timestamping start/stop times of command executions. This can also act as a template for custom command logging. It currently aims to support both Bash and Zsh.

This tool implements [bash-preexec](https://github.com/rcaloras/bash-preexec) and is inspired by [bash-command-timer](https://github.com/jichu4n/bash-command-timer).

```bash
# -- Example Output
$ echo 'Command Wrapper!'
Command Wrapper!

start    Wed 07 Oct 2020 05:00:00 AM UTC
stop     Wed 07 Oct 2020 05:00:00 AM UTC
```

## Installation:
1. Write this script to your home folder as `.cmdw`:
    * `vim ~/.cmdw`
2. Source the cmdw script:
    * `source ~/.cmdw`
3. For persistence, add it to your .bashrc or similar:
    * `source "$HOME/.cmdw"`

Install one-liner: `source <(curl -s https://raw.githubusercontent.com/0xZDH/cmdw/master/install.sh)`

## History Size:
If required, the user can modify the size of the maintained history file by setting CMDWSIZE as an environment variable (Default: 3,000):
* `export CMDWSIZE=1000`

## Command Referencing:
1. List the executed commands in .cmdw_history with line numbers via:
    * `cat -n .cmdw_history | grep '#'`
2. Then, grab the command and its timestamps using (where `N` is the identified line number):
    * `sed -n 'N,$p' .cmdw_history | head -n3`

For easy referencing, use the builtin function:
* `cmdw_history`
* `cmdw_history <id>`

```bash
# -- Example history command output
$ cmdw_history 
 1   echo 'Command Wrapper!'

# -- Example grabbing specific history item to view timestamps
$ cmdw_history 1
# echo 'Command Wrapper!'
start    Wed 07 Oct 2020 05:00:00 AM UTC
stop     Wed 07 Oct 2020 05:00:00 AM UTC
```

## Enable/Disable:
By default, cmdw is enabled. To disable/enable the wrapper, use the built in functions:
* `cmdw_disable`
* `cmdw_enable`

Or export the following variable to disable the wrapper:
* `export CMDW_ENABLE=0`

And to re-enable the wrapper:
* `export CMDW_ENABLE=1`

To default disable the wrapper, add the following to your .bashrc or similar after cmdw is sourced:
* `export CMDW_ENABLE=0`

## Ignoring commands:
Commands to be ignored by cmdw are stored in the `CMDW_IGNORE` environment variable. The user can directly modify this array in a given terminal session or globally in their .bashrc or similar. To add a command to the list, whether globally or locally per session:
* `CMDW_IGNORE+=('command')`

And to allow the cmdw wrapper to log on every command:
* `CMDW_IGNORE=()`
