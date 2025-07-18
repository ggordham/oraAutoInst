#!/bin/bash

target=$1
install_dir=/u01/app/scripts
inst_user=oracle

file_list="../oraAutoInst.sh oraAutoInst.bats instbats.sh"

# check the install server
chk_srvr=$( ssh "${inst_user}"@"${target}" hostname -s )

if [ "${chk_srvr}" == "${target}" ]; then

    ssh "${inst_user}"@"${target}" "[ ! -d ${install_dir} ] && /bin/mkdir ${install_dir}"

    for file in ${file_list}; do
        scp "${file}" "${inst_user}"@"${target}":"${install_dir}"
    done;

    ssh "${inst_user}"@"${target}" "/bin/chmod +x ${install_dir}/*.sh"
else
    echo "ERROR! target server $target not detected, check: $chk_srvr" >&2
fi

# END
