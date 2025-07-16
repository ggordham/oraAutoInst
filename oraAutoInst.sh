#!/bin/bash
# oraAutoInst.sh

# Used to setup or install an Oracle database software home using 
# the autoupgrade tool from Oracle.
#
# Internal settings, export empty variable that is set by library
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Static settings
autoup_latest=https://download.oracle.com/otn-pub/otn_software/autoupgrade.jar
ora_base=/u01/app/oracle
stg_dir=/u01/app/oracle/stage
ora_home=/u01/app/oracle/product/19/dbhome_1
auto_dir=${stg_dir}
error_code=0

# set parameters to exit on unbound variable and return any error in pipe
set -uo pipefail

# retun command line help information
function help_oraAutoInst {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   used to stage Oracle DB software using the  " >&2
  echo "   AUTOUPGRADE tool.                           " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]        " >&2
  echo "-h          give this help screen               " >&2
  echo "--download   only download autoupgrade          " >&2
  echo "--oraver [Oracle version]                       " >&2
  echo "--orabase [Oracle base]                         " >&2
  echo "--orahome [Oracle home]                         " >&2
  echo "--autodir [autoupgrade directory]               " >&2
  echo "--stgdir  [Staging Directory]                   " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode, disable DBCA run " >&2
  echo "--version | -v Show the script version          " >&2
  echo >&2
  echo "DEFAULTS:                                       " >&2
  echo "  oraver:  latest                               " >&2
  echo "  orabase: /u01/app/oracle                      " >&2
  echo "  orahome: \$ORACLE_BASE/product/19/dbhome_1    " >&2
  echo "  stgdir:  /u01/app/oracle/stage                " >&2
  echo "  autodir: /u01/app/oracle/stage                " >&2
  echo >&2
  echo "Note: autoupgrade will be placed in any new home" >&2
  echo "     under \$ORACLE_HOME/rdbms/admin            " >&2

}

#check command line options
function checkopt_oraAutoInst {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long help,debug,test,version,download,autodir:,oraver:,stgdir:,orabase:,orahome: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
        "-h"|"--help") help_oraSwStg                          #  help
                     exit 1;;
          "--oraver") ora_ver="$2"
                     shift 2;;
          "--autodir") auto_dir="$2"
                     shift 2;;
          "--stgdir") stg_dir="$2"
                     shift 2;;
          "--orabase") ora_base="$2"
                     shift 2;;
           "--orahome") ora_home="$2"
                     shift 2;;
           "--downlaod") DOWNLOAD_ONLY=TRUE
                     shift;;
           "--debug") DEBUG=TRUE                         # debug mode
                     set -x
                     shift ;;
           "--test") TEST=TRUE                           # test mode
                     shift ;;
           "--version"|"-v") echo "$SCRIPTNAME version: $SCRIPTVER" >&2
                     exit 0;;
                "--") shift; break;;                             # finish parsing
                  *) echo "ERROR! Bad command line option passed: $1"
                     (( badopt=1 ))
                     break ;;                                    # unknown flag
        esac
    done
  fi

  return $badopt

}

############################################################################################
# start here

# verify that we are root to run this script
if [ "x$USER" = "xroot" ];then echo "ERROR! Run this script as the ORACLE software owner!" ; exit 1; fi

OPTIONS=$@

if checkopt_oraAutoInst "$OPTIONS" ; then

    echo "${SCRIPTNAME} start $(/bin/date)"
    if [ "$DEBUG" == "TRUE" ]; then echo "INFO: DEBUG Mode Enabled!" ; fi
    if [ "$TEST" == "TRUE" ]; then echo "INFO: TEST Mode Enabled, commands will not be run." ; fi

    # check if we are in download only mode
    if [ "${DOWNLOAD_ONLY}" == "TRUE" ]; then
        echo "INFO: only downloading latest autoupgrade.jar"
        echo "INFO: AUTOUPGRADE: $auto_dir"

    else

        # provide basic output
        echo "INFO: Settings:"
        echo "INFO: STAGING:     $stg_dir"
        echo "INFO: AUTOUPGRADE: $auto_dir"
        echo "INFO: ORACLE_BASE: $ora_base"
 
        # setup ora_home
        if [ -z "${ora_home:-}" ]; then ora_home="${ora_base}/product/19/dbhome_1"; fi
        echo "INFO: ORACLE_HOME: $ora_home"
 
        # check version information
        echo "INFO: VERSION:     $ora_ver"
    fi # check for download only
else
    echo "ERROR - invalid command line parameters" >&2
    error_code=2
fi

exit $error_code

#END

