#!/usr/bin/zsh

set -e


IP_CAMERA=192.168.0.1
URI_BASE="http://$IP_CAMERA/v1"
ESSID_CAMERA=GR_4CF5C6



usage="$0 Nimages
Nimages is how many most-recent photos to download
"

N=$1

[[ -z "$N" ]] && {
    echo $usage
    exit 1
}

function wifi_connect {
    ESSID=$1

    iwctl station $WLAN scan
    iwctl station $WLAN connect $ESSID
    sudo killall udhcpc || true
    sudo udhcpc -i $WLAN
}

function wifi_params {
    # Return first device that has an essid
    /sbin/iw dev \
    | awk '/Interface/ && $2              { interface=$2 }
           /ssid/      && $2 && interface { print interface,$2; exit}'
}

function wifi_reset {
    wifi_connect $ESSID_BASE
}



wifi_params | read WLAN ESSID_BASE

[[ -z "$ESSID_BASE" ]] && {
    echo "Couldn't get the WLAN interface and the current ESSID. Giving up" > /dev/stderr
    exit 1
}

echo $WLAN
echo $ESSID_BASE

wifi_connect $ESSID_CAMERA

photos_json=$(curl -s "$URI_BASE/photos")

[[ -z "$photos_json" ]] &&
    {
        echo "No 'photos' json output"
        wifi_reset
        exit 1
    }

dir_last=$(echo $photos_json |
           jq ".dirs[-1].name" |
           perl -nE '/[a-zA-Z0-9_]+/p && say ${^MATCH}')
[[ -z "$dir_last" ]] &&
    {
        echo "No last-directory found"
        wifi_reset
        exit 1
    }

photos_last=($(echo $photos_json |
               jq ".dirs[-1].files[-$N:]" |
               perl -nE '/R.*JPG/p && say ${^MATCH}'))
[[ -z "$photos_last" ]] &&
    {
        echo "No last photos found"
        wifi_reset
        exit 1
    }

for photo ($photos_last) {
    curl "$URI_BASE/photos/$dir_last/$photo" --output $photo
}

wifi_reset
