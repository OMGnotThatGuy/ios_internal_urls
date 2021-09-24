#!/usr/bin/env bash

set -o errexit

BASE_DIR='/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources'
ROOT_DIR="${BASE_DIR}/RuntimeRoot"

function warn() {
    echo "$1" 1>&2
}


function err() {
    echo "$*" 1>&2
    exit 99
}


function check_effective_uid() {
    # Some files require root to read
    if [ "$EUID" -ne 0 ]; then
        warn "Not running as root! Re-running with sudo."
        sudo "$0"
        exit
    fi
}


function check_ios_root() {
    if [ ! -d "$ROOT_DIR" ]; then
        warn "Directory not found: $ROOT_DIR"
        err '--->Can''t find working dir. Is Xcode installed?<---'
    fi
}


function print_ios_version() {
    local sim_plist="${BASE_DIR}/profile.plist"
    local ios_version
    if [ -f "$sim_plist" ]; then
        ios_version="$(plutil -p "$sim_plist" | grep defaultVersionString | awk '{print $NF}' | tr -d '"')"
        if [ -n "$ios_version" ]; then
            printf "$ios_version"
            return 0
        fi
    fi
    printf "UNKNOWN_FIX_ME"
}


function print_header() {
    echo "file_count|filename|key|url"
}


function print_footer() {
    printf '"# %s\t\tiOS %s\t\tExtracted:%s"\n' "OMGnotThatGuy" "$(print_ios_version)" "$(date '+%Y-%m-%d')"
}


function process_plist() {
    # Some URLs look like they have spaces in them. Weird. Clean them up. Test later...
    # SettingsSearchManifest-HomeScreeniPad.plist: "prefs:root= HOME_SCREEN_DOCK#BADGES_IN_APP_LIBRARY"
    plutil -p "$1" \
    | egrep '"(prefs|bridge):' \
    | perl -pe 's/ //g and s/=>/|/g and s/^\s*(.*)/$ENV{i}|$ENV{path}|\1/g'
    return ${PIPESTATUS[0]}
}

##############
### main() ###
##############
export path
export i=0

check_effective_uid
check_ios_root
cd "$ROOT_DIR" || err "Couldn't cd to \$ROOT_DIR"

print_header
while IFS= read -r -d $'\0' path
do
    let "i = i + 1"
    process_plist "$path" || warn "FAILED to decode file: $path"
done < <(find -L . -type f -name '*.plist' -print0)
print_footer

# For only searching SettingsSearchManifest plist files
# done < <(find . -name '*SettingsSearchManifest*plist' -print0)
# print_footer
