# Connect a Flatpak Firefox-based browser (Zen, Firefox, LibreWolf...) to 1Password
setup-1password-flatpak BROWSER="":
    #!/usr/bin/env bash
    set -euo pipefail
    browser="{{ BROWSER }}"
    if [[ -z "$browser" ]]; then
        mapfile -t browsers < <(find "${HOME}/.var/app" -mindepth 3 -maxdepth 6 -name prefs.js \
            -not -path '*/cache/*' -printf '%P\n' 2>/dev/null | cut -d/ -f1 | sort -u)
        if [[ ${#browsers[@]} -eq 0 ]]; then
            echo "No Flatpak Firefox-based browser with a profile found; launch it once first."
            exit 1
        fi
        browser="$(gum choose --header "Browser to connect to 1Password:" "${browsers[@]}")"
    fi
    mapfile -t profiles < <(find "${HOME}/.var/app/${browser}" -maxdepth 5 -name prefs.js \
        -not -path '*/cache/*' -printf '%h\n' 2>/dev/null)
    if [[ ${#profiles[@]} -eq 0 ]]; then
        echo "No profile found for ${browser}; launch it once first."
        exit 1
    fi
    flatpak override --user --talk-name=org.freedesktop.NativeMessagingProxy "${browser}"
    pref='user_pref("widget.use-xdg-desktop-portal.native-messaging-proxy", 2);'
    for profile in "${profiles[@]}"; do
        grep -qxF "${pref}" "${profile}/user.js" 2>/dev/null || echo "${pref}" >> "${profile}/user.js"
    done
    echo "Done. Restart ${browser} and 1Password."
