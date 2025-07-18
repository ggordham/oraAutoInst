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
ora_base=/u01/app/oracle
stg_dir=/u01/app/oracle/stage
ora_home=/u01/app/oracle/product/19/dbhome_1
auto_dir=${stg_dir}
error_code=0
ALL_SCRIPT_MODES="auto_down install pre_check down_only"

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
  echo "Usage: $SCRIPTNAME [-h --debug --test ]         " >&2
  echo "-h          give this help screen               " >&2
  echo "--mode    [script_mode]                         " >&2
  echo "--oraver  [Oracle version]                      " >&2
  echo "--orabase [Oracle base]                         " >&2
  echo "--orahome [Oracle home]                         " >&2
  echo "--autodir [autoupgrade directory]               " >&2
  echo "--logdir  [log directory]                       " >&2
  echo "--stgdir  [Staging Directory]                   " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode, disable DBCA run " >&2
  echo "--version | -v Show the script version          " >&2
  echo >&2
  echo "MODES:                                          " >&2
  echo "  auto_down - only download autoupgrade         " >&2
  echo "  pre_check - run OS pre-checks                 " >&2
  echo "  down_only - download Oracle software & patches" >&2
  echo "  install   - install ORACLE_HOME               " >&2
  echo >&2
  echo "DEFAULTS:                                       " >&2
  echo "  oraver:  latest                               " >&2
  echo "  orabase: /u01/app/oracle                      " >&2
  echo "  orahome: \$ORACLE_BASE/product/19/dbhome_1    " >&2
  echo "  logdir:  /u01/app/oracle/admin/autoup         " >&2
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
    my_opts=$(getopt -o hv --long help,debug,test,version,mode:,logdir:,,autodir:,oraver:,stgdir:,orabase:,orahome: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
        "-h"|"--help") help_oraAutoInst                          #  help
                     exit 0;;
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
           "--logdir") log_dir="$2"
                     shift 2;;
           "--mode") script_mode="$2"
                     script_mode="${script_mode^^}"   # change to uppercase
                     shift 2;;
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

# Simple function to see if a value exists in a space separated list of values
#  usage  inList "A B C D" "B"
function inList {

  local my_list="$1"
  local my_item="$2"
  local my_result

  if [[ $my_list =~ (^|[[:space:]])"$my_item"($|[[:space:]]) ]] ; then
    my_result=0  # TRUE item is in list
  else
    my_result=1  # FALSE item is not in list
  fi
  # return results
  return $my_result
}

# dwnld_autoupgrade TARGET_DIR
#  Downloads the latest version of AUTOUPGRADE to the TARGET_DIR
dwnld_autoupgrade () {

  local my_return=0
  local my_target="$1"
  local my_autoup_latest=https://download.oracle.com/otn-pub/otn_software/autoupgrade.jar
  local my_newname

  # check target directory exists and we can use it
  if [ -d "${my_target}" ]  && [ -w "${my_target}" ]; then
      echo "INFO: AUTOUPGRADE traget direcotry exists and is writable."
  elif /bin/mkdir -p "${my_target}"; then
      echo "INFO: AUTOUPGRADE traget direcotry created."
  else
      echo "ERROR: AUTOUPGRADE traget directory does not exist and could not be created!" >&2
      return 2
  fi

  # check if an autoupgrade is in the target directory and rename
  if [ -f "${my_target}/autoupgrade.jar" ]; then
      my_newname="autoupgrade.jar.$( /bin/date +%Y%m%d )"
      /bin/mv "${my_target}/autoupgrade.jar" "${my_target}/${my_newname}"
      echo "INFO: previous version renamed to: ${my_newname}"
  fi

  # now download the latest version from the internet
  if ! cd "${my_target}"; then  
      echo "ERROR: cloud not change into AUTOUPGRADE direcotry!"; 
      my_return=2
  else
      if ! /bin/curl -O -L "${my_autoup_latest}" ; then
          echo "ERROR: Could not download autoupgrade.jar from: ${my_autoup_latest}" >&2
          my_return=2
      fi
      # change back to original directory
      cd - || my_return=2
  fi

  # return error info
  return $my_return

}

# pre_checks
#
# Used to check OS for pre-install requirements
# only looks for openjdk and preinstall RPM right now
# for redhat it only looks at openjdk
pre_checks () {

    local my_java_list="java-1.8.0-openjdk java-11-openjdk java-17-openjdk java-21-openjdk"
    local my_preinstall=oracle-database-preinstall-19c
    local my_rpm_tool
    local my_install=FALSE
    local my_rpm
    local my_error

    # check for openjdk
    my_rpm_tool="/usr/bin/yum -q" && [ -f /usr/bin/dnf ] && my_rpm_tool="/usr/bin/dnf list installed"
    for rpm in ${my_java_list}; do
       if ${my_rpm_tool} "${rpm}" >/dev/null 2>&1; then
           my_install=TRUE
           my_rpm=${rpm}
       fi
     done;

     # if installed give message, if not fail
     if [ "${my_install}" == "TRUE" ]; then
         echo "INFO: detected java: ${my_rpm}"
         my_error=0
     else
         echo "ERROR: Java not detected, please install OpenJDK rpm from list:" >&2
         echo "   ${my_java_list}" >&2
         my_error=3
     fi

     # check if we are running Oracle Linux and if preinstall RPM is installed 
     if [ "$(/bin/grep -E '^NAME=' /etc/os-release | /bin/cut -f2 -d= | /bin/tr -d '"')" == "Oracle Linux Server" ]; then
         echo "INFO: Oracle Linux detected, checking for database preinstall rpm."
         my_rpm_tool="/usr/bin/yum -qa" && [ -f /usr/bin/dnf ] && my_rpm_tool="/usr/bin/dnf list installed"
         my_install=$( ${my_rpm_tool} 2>/dev/null | /bin/grep "${my_preinstall}" | /bin/wc -l )
         if (( my_install > 0 )); then
             echo "INFO: detected preinstall rpm: $my_preinstall"
         else
             echo "ERROR: missing preinstall rpm: $my_preinstall"
             my_error=3
         fi
     else
         echo "INFO: Other OS detected, please manually verify OS preinstall requirements."
     fi

     return $my_error
}

############################################################################################
# start here

# verify that we are root to run this script
if [ "x$USER" = "xroot" ];then echo "ERROR! Run this script as the ORACLE software owner!" ; exit 1; fi

OPTIONS=$@

if checkopt_oraAutoInst "$OPTIONS" ; then

    # check that a script mode has been provided
    if [ -z "${script_mode:-}" ]; then
        echo "ERROR! no scirpt mode provided." >&2
        exit 1
    elif ! inList "${ALL_SCRIPT_MODES^^}" "${script_mode}" ; then
        echo "ERROR! invalid script mode, use one of: " >&2
        echo "   ${ALL_SCRIPT_MODES}" >&2
        echo "    or run with --help | -h for more information" >&2
        exit 1
    fi

    # Start script output
    echo "${SCRIPTNAME} start $(/bin/date)"
    if [ "$DEBUG" == "TRUE" ]; then echo "INFO: DEBUG Mode Enabled!" ; fi
    if [ "$TEST" == "TRUE" ]; then echo "INFO: TEST Mode Enabled, commands will not be run." ; fi

    # script modes
    case "${script_mode}" in
        "AUTO_DOWN") # autoupgrade download only mode
            echo "INFO: only downloading latest autoupgrade.jar"
            echo "INFO: AUTOUPGRADE: $auto_dir"
 
            # downlaod autoupgrade
            dwnld_autoupgrade "${auto_dir}"
            error_code=$?
            ;;

        "PRE_CHECK")
            echo "INFO: only running OS pre-checks."              
            pre_checks
            error_code=$?
            ;;

        "DOWN_ONLY") 
            ;;

        "INSTALL") # full install mode
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
            ;;

        *) # invalid script mode, code should never get here.
            echo "ERROR! invalid script mode: ${script_mode}" >&2
            error_code=1
            ;;
    esac

else
    echo "ERROR - invalid command line parameters" >&2
    error_code=1
fi

exit $error_code

#END

