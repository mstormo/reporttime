#!/bin/bash
# --------------------------------------------------------------------------------------------------
# Copyright (C) 2011 Marius Storm-Olsen <marius_git@storm-olsen.com>
#
# reporttime.bash -- Bash support for ZSH-like REPORTTIME
#
# To use, just source this file. The script requires 'bc' for floating point calculations.
#
# The REPORTTIME variable defines how long a process must run before the execution time is reported.
# If the variable is not defined, it will be set to a default of 5 seconds. If you set it to 0, the
# execution time will always be reported. If you set it to "no", the time is never reported. This
# can be useful if you'd rather include the previous command's execution time in the bash prompt,
# for example, or if you only want the functionality to query the run time after the fact, by using
# the 'timelast' command.
#
# The $REPORTTIME_SCALE variable defines how many decimals you want in the resulting report (upto 9
# digits). If the variable is not defined, it will be set to a default of 3 decimals.
#
# The REPORTTIME_LOOP variable defines how many loops of running 'date' the script will use to
# calculate the average time stamp fetch impact. It will subtract this time to the general command
# execution time, to get as close to the actual number. (Since report time is not built into bash,
# we actually need execute additional commands to get the proper (and granulated enough) wall time.
# One *could* use the built in SECONDS, but that's sometimes not fine grained enough. The impact of
# calling date though is very low on modern systems.
#
# --------------------------------------------------------------------------------------------------
#
# Variables defined after a command executes, and usable in Bash prompts:
#   rtdays: Number of days the command executed
#   rthours: Number of hours the command executed
#   rtmins: Number of minutes the command executed
#   rtsecs: Number of seconds the command executed, including REPORTTIME_SCALE decimals
#   rttime: Pretty-printed elapsed time the command executed, in the format:
#             Xdays, HH:MM:SS.ddd
#           Where insignificant preceeding parts are left out, so you for example get
#             3:02:14.100
#           if the command ran for 3 hours + 2 minutes + 14.100 seconds
#   reporttime_exec_time: Number of total seconds the command executed, including REPORTTIME_SCALE
#                         decimals
# PS. If you are using the variables above in your Bash prompt, you would most likely want to set
#   REPORTTIME=-1
# to avoid the extra timing output after the command completes. (See REPORTTIME details above.) 
#
# --------------------------------------------------------------------------------------------------
# Note: this module requires 2 bash features which you must not otherwise be using: the "DEBUG"
# trap, and the "PROMPT_COMMAND" variable. preexec_install will override these and if you override
# one or the other this _will_ break.
# --------------------------------------------------------------------------------------------------
# This program is free software; you can redistribute it and/or modify it under the terms of the
# GNU General Public License as published by the Free Software Foundation; version 2 of the License.
# --------------------------------------------------------------------------------------------------

# If REPORTTIME is not already defined, make it 5 seconds by default
[[ -n $REPORTTIME ]] || REPORTTIME=5

# If REPORTTIME_SCALE is not defined, set it to 3 by default
[[ $REPORTTIME_SCALE ]] || REPORTTIME_SCALE=3

# If REPORTTIME_LOOP is not defined, set it to 5 by default
[[ $REPORTTIME_LOOP ]] || REPORTTIME_LOOP=5

# Prime PROMPT_COMMAND, or else preexec.bash will fail
[[ $PROMPT_COMMAND ]] || PROMPT_COMMAND=":"

# Source Glyph Lefkowitz's preexec implementation for Bash
source $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/preexec.bash

# Find the (somewhat) overhead of calling date to acquire the time stamp
reporttime_calculate_delta () {
  local reporttime_delta_start=$(date +%s.%N)
  for i in {1..$REPORTTIME_LOOP}; do
    local reporttime_delta_stop=$(date +%s.%N)
  done
  reporttime_delta=$(echo "scale=9;($reporttime_delta_stop - $reporttime_delta_start) / $REPORTTIME_LOOP" | bc)
}

# Define preexec, which is called right before executing the command.
# If the command happens to be 'timelast', set start time to 0, which turns off timing for that
# command.
preexec () {
  if [[ -z "$preexec_interactive_mode" ]]; then
    if [[ $1 == "timelast" ]]; then
        reporttime_exec_start=0
    else
        reporttime_exec_start=$(date +%s.%N)
    fi
  fi
}

# Define precmd, which is run right after the execution of the command has finished.
# Recalculate the execution time, and report if exec time is larger than REPORTTIME
# If REPORTTIME is set to "no", then the reporttime is never reported. This is useful if the report
# time is used in the bash prompt itself, for example.
precmd () {
  reporttime_exec_stop=$(date +%s.%N)
  if [[ $reporttime_exec_start != 0 ]]; then
    reporttime_exec_time=$(echo "scale=$REPORTTIME_SCALE;($reporttime_exec_stop-$reporttime_exec_start-$reporttime_delta)/1" | bc)
    reporttime_formattime
    if [[ $REPORTTIME != "no" ]] && [[ $REPORTTIME < $reporttime_exec_time ]]; then
      timelast
    fi
  fi
}

reporttime_formattime () {
  # Get time without fractions, since Bash cannot do floating point calculations
  local rtet_short=${reporttime_exec_time:0:-$(($REPORTTIME_SCALE+1))}
  [[ $rtet_short ]] || rtet_short=0 # Trunc <1sec to 0, and not empty
  rtdays=$(($rtet_short/86400))
  rthours=$((($rtet_short/3600)%24))
  rtmins=$((($rtet_short/60)%60))
  # Stick the fractions on at the end of seconds
  rtsecs=$(($rtet_short%60))${reporttime_exec_time:(-$(($REPORTTIME_SCALE+1)))}

  # Create a 'pretty' variable, which only displays the required parts
  rttime=""
  [[ $rtdays == 1 ]] && rttime="1day, "
  [[ $rtdays > 1 ]] && rttime="${rtdays}days, "
  [[ $rthours > 0 || $rttime ]] && rttime=$rttime$(printf "%02d:" $rthours)
  [[ $rtmins > 0 || $rttime ]] && rttime=$rttime$(printf "%02d:" $rtmins)
  rttime=$rttime$(printf "%0$(($REPORTTIME_SCALE+3)).${REPORTTIME_SCALE}f" $rtsecs)
  rttime=${rttime#0} # Remove preceeding 0s
}

# Command to report how long last process took to execute
timelast () {
  echo "real ${rttime}s"
}

# Activate reporttime support
reporttime_exec_start=0
reporttime_exec_stop=0
[[ -z $reporttime_delta ]] && reporttime_calculate_delta
preexec_install
