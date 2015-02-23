#
# b0rked
#
# Quick system diagnostics.
# Inspired by: http://devo.ps/blog/troubleshooting-5minutes-on-a-yet-unknown-box/
#

#
# Checks - Disk/FS
#
check_fs() { 
    section "Disk/File System"
}

check_fs_disk_uncorrectable_error() {
    if [[ $(dmesg | grep "UncorrectableError") ]]; then
        fail "Uncorrectable drive error found in dmesg"
    else
        pass "No uncorrectable drive errors detected"
    fi
}

check_fs_usage_space() { 
    if [[ $(df | awk '{print $5}' | egrep '(9[0-9]|100)%') ]]; then
        fail "Disk usage for one or more volumes is over 90%"
    else
        pass "Disk usage is under 90% for one or more volumes"
    fi
}

check_fs_usage_inode() { 
    if [[ $(df -i | awk '{print $5}' | egrep '(9[0-9]|100)%') ]]; then
        fail "Inode usage for one or more volumes is over 90%"
    else
        pass "Inode usage is under 90% for all volumes"
    fi
}

check_fs_mounted_rw() { 
    if [[ $(dmesg | grep 'Remounting filesystem read-only') ]]; then
        fail "Filesystem re-mounted read-only"
    else
        pass "No filesystems remounted as read-only"
    fi
}

check_fs_swap() {
    TOTAL=$(grep 'SwapTotal' /proc/meminfo | awk '{print $2}')
    FREE=$(grep 'SwapFree' /proc/meminfo | awk '{print $2}')

    if [[ "$TOTAL" -eq "0" ]]; then
        info "Swap not available"
        return
    fi

    if [[ $(($FREE / $TOTAL)) -gt "25" ]]; then
        fail "Swap usage over 25%"
    else
        pass "Swap usage under 25%"
    fi
}


#
# Checks - Kernel
#
check_kernel() {
    section "Kernel"
}

check_kernel_hung_tasks() {
    if [[ $(dmesg | grep -q "hung_task_timeout_secs") ]]; then
        fail "Hung tasks found in dmesg output"
    else
        pass "No hung tasks in dmesg output"
    fi
}

check_kernel_lockup() {
    if [[ $(dmesg | grep "BUG: soft lockup") ]]; then
        fail "CPU soft lockup detected!"
    else
        pass "CPU soft lockup not detected"
    fi
}


#
# Checks - NFS (if enabled in the kernel)
#
check_nfs_timeout() {
    if [[ $(grep '^nfs' /proc/modules) ]]; then
        section "NFS"
    fi

    if [[ $(dmesg | grep "nfs: server .* not responding") ]]; then
        fail "NFS timeouts detected"
    else
        pass "No NFS timeouts detected"
    fi
}

#
# Checks - Memory/Vm
#
check_mem() { 
    section "Memory"
}

check_mem_oom_killer() {
    if [[ $(dmesg | grep 'invoked oom-killer') ]]; then
        fail "Out of memory killer triggered for:"

        DEAD=$(dmesg | grep "Out of Memory: Killed process" | awk -vRS=")" -vFS="(" '{print $2}')

        while read KILLED; do
            echo "     $KILLED"
        done <<< "$DEAD"
    else
        pass "Out of memory killer not triggered"
    fi
}

check_mem_usage() {
    PERCENTAGE=$(free -m | awk 'NR==2{printf "%d", $3*100/$2 }')
    OUTPUT=$(free -m | awk 'NR==2{printf "%s/%sMB - %.2f%\n", $3,$2,$3*100/$2 }')

    if [[ "$PERCENTAGE" -gt "90" ]]; then
        fail "Memory usage over 90% ($OUTPUT)"
    else
        pass "Memory usage under 90% ($OUTPUT)"
    fi
}


#
# Checks - Misc
#
check_misc() { 
    section "Misc"
}

check_misc_uptime() {
    UPTIME="$(cat /proc/uptime | grep -o '^[0-9]\+')"

    if [[ "$UPTIME" -gt "1800" ]]; then
        pass "Server has been up for more than an hour"
    else
        fail "Rebooted $(($UPTIME / 60)) minutes ago"
    fi
}

check_misc_users() {
    USERS=$(w | tail -n +3)
    COUNT=$(echo "$USERS" | wc -l)

    info "Currently $COUNT user(s) logged in:"

    while read USER; do
        echo "      - " $(echo "$USER" | cut -d " " -f1)
    done <<< "$USERS"
}


#
# Checks - Network
#
check_net() { 
    section "Network"
}

check_net_google_connectivity() {
    if [[ $(ping -c 1 8.8.8.8 &> /dev/null) ]]; then
        fail "Can't reach Google DNS"
    else
        pass "Can reach Google DNS"
    fi
}

check_net_dns_resolution() {
    return #TODO
}

#
# Output Helpers
#

COLOURS=$(tput colors)

pass() {
    if [[ $COLOURS -ge 8 ]]; then
        echo -e "  \033[32m✓\033[00m $1"
    else
        echo "PASS: $1"
    fi
}

fail() {
    if [[ $COLOURS -ge 8 ]]; then
        echo -e "  \033[31m×\033[00m $1"
    else
        echo "FAIL: $1"
    fi
}

info() {
    if [[ $COLOURS -ge 8 ]]; then
        echo -e "  \033[33m?\033[00m $1"
    else
        echo "INFO: $1"
    fi
}

section() {
    if [[ $COLOURS -ge 8 ]]; then
        echo -e "\033[36m-\033[00m $1"
    else
        echo "$1"
    fi
}

#
# Run the Checks
#
if [ -n "$ZSH_VERSION" ]; then
   CHECKS=$(print -l ${(ok)functions} | grep '^check' | sort)
elif [ -n "$BASH_VERSION" ]; then
   CHECKS=$(declare -F | cut -d " " -f3 | grep '^check_' | sort)
else
   fail "Unknown shell" && exit
fi

for CHECK in $(echo $CHECKS); do
    eval $CHECK
done
