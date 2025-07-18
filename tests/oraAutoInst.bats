#!/usr/bin/env bats

# BATS test file for ora_bkup_nfs.sh shell script
# NOTE:
#  need to create test for failed os pre-checks

# static locations
script_file=oraAutoInst.sh
install_dir=/u01/app/scripts
test_dir=$HOME/test

# this is run before all tests once
setup_file () {
echo " S Test Name                                                                              RC " >&3
echo " - -------------------------------------------------------------------------------------- ---" >&3

}

# Load a library from the `${BATS_TEST_DIRNAME}/test_helper' directory.
#
# Globals:
#   none
# Arguments:
#   $1 - name of library to load
# Returns:
#   0 - on success
#   1 - otherwise
load_lib() {
  local name="$1"
  load "${BATS_ROOT}/test_helper/${name}/load"
}

load_lib bats-assert
load_lib bats-support

# setup is run before each test is execute
setup () {

  # Allways return no error
  return 0
}

# Clean up after each test
teardown () {

  # cleanup copies of autoupgrade
  [ -f "/u01/app/oracle/stage/autoupgrade.jar.$( /bin/date +%Y%m%d )" ] && /bin/rm -f "/u01/app/oracle/stage/autoupgrade.jar.$( /bin/date +%Y%m%d )"
  [ -f "/u01/app/oracle/stage/autoupgrade.jar" ] && /bin/rm -f "/u01/app/oracle/stage/autoupgrade.jar"
  [ -f "${adir}/autoupgrade.jar" ] && /bin/rm -f "${adir}/autoupgrade.jar"
  [ -f "${adir}/autoupgrade.jar.$( /bin/date +%Y%m%d )" ] && /bin/rm -f "${adir}/autoupgrade.jar.$( /bin/date +%Y%m%d )"

  # Allways return no error
  return 0
}

# Test - help mode short
@test "${script_file} - help mode short                                                      (0)" {

  run ${install_dir}/${script_file} -h
  assert_success
}

# Test - help mode long 
@test "${script_file} - help mode long                                                       (0)" {

  run ${install_dir}/${script_file} -h
  assert_success
}
# Test - version mode
@test "${script_file} - version mode                                                         (0)" {

  run ${install_dir}/${script_file} -v
  assert_success
}

# Test - version mode long 
@test "${script_file} - version mode long                                                    (0)" {

  run ${install_dir}/${script_file} --version
  assert_success
}

# Test - no parameters passed
@test "${script_file} - no parameters passed                                                 (1)" {

  run ${install_dir}/${script_file} 
  assert_failure 1
}

# Test - mode passed with no parameter             
@test "${script_file} - mode passed with no parameter                                        (1)" {

  script_mode=""
  run ${install_dir}/${script_file} --mode ${script_mode}
  assert_failure 1
}

# Test - auto_down with invalid directory          
@test "${script_file} - auto_down with invalid directory                                     (2)" {

  script_mode="auto_down"
  adir=/root
  run ${install_dir}/${script_file} --mode ${script_mode} --autodir ${adir}
  assert_failure 2
}

# Test - auto_down with default directory          
@test "${script_file} - auto_down with default directory                                     (0)" {

  script_mode="auto_down"
  adir=
  run ${install_dir}/${script_file} --mode ${script_mode} 
  assert_success
}

# Test - auto_down with custom directory          
@test "${script_file} - auto_down with custom directory                                      (0)" {

  script_mode="auto_down"
  adir=/home/oracle
  run ${install_dir}/${script_file} --mode ${script_mode} --autodir ${adir}
  assert_success
}

# Test - auto_down with custom directory pre-existing file
@test "${script_file} - auto_down with custom directory pre-existing file                    (0)" {

  script_mode="auto_down"
  adir=/home/oracle
  touch ${adir}/autoupgrade.jar
  run ${install_dir}/${script_file} --mode ${script_mode} --autodir ${adir}
  assert_output --partial 'previous version renamed to'
}

# Test - pre_check java or preinstall rpm missing
@test "${script_file} - pre_check failure                                                    (3)" {

  script_mode="pre_check"
  run ${install_dir}/${script_file} --mode ${script_mode} 
  assert_failure 3
}

# Test - pre_check success
@test "${script_file} - pre_check success                                                    (0)" {

  script_mode="pre_check"
  run ${install_dir}/${script_file} --mode ${script_mode} 
  assert_success
}

