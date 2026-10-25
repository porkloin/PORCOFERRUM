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

# An ssh:// or user@host: URL is a private repo, pulled with a read-only deploy key, ~/.ssh/materia_ro. Each remote
# named after the host name (a private [Remotes] component) gets its own, ~/.ssh/materia_<remote>_ro. Rerunning keeps
# existing keys.
# Point Materia at this machine's repo: setup-materia <repo url> [host name] [remote...]
[positional-arguments]
setup-materia URL HOSTNAME="" *REMOTES:
    #!/usr/bin/env bash
    set -euo pipefail
    url="$1" name="${2:-}"
    shift; shift || true
    cfg="${HOME}/.config/materia"
    mkdir -p "${cfg}" "${HOME}/.local/share" "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"

    # This machine's age key: decrypts attributes/<host>.age in the repo.
    if [[ ! -f "${cfg}/key.txt" ]]; then
        (umask 077; age-keygen -o "${cfg}/key.txt" 2>/dev/null)
    fi

    newkey() {
        [[ -f "${HOME}/.ssh/$1" ]] || ssh-keygen -q -t ed25519 -N "" -C "$(uname -n)-$1" -f "${HOME}/.ssh/$1"
    }
    env=("MATERIA_SOURCE__URL=${url}")
    [[ -z "${name}" ]] || env+=("MATERIA_HOSTNAME=${name}")
    keys=()
    host=""
    case "${url}" in
        ssh://*)  host="$(sed -E 's#^ssh://([^@/]+@)?([^/:]+).*#\2#' <<<"${url}")" ;;
        *@*:*)    host="$(sed -E 's#^[^@]+@([^:]+):.*#\1#' <<<"${url}")" ;;
    esac
    if [[ -n "${host}" ]]; then
        newkey materia_ro
        env+=("MATERIA_GIT__PRIVATE_KEY=${HOME}/.ssh/materia_ro")
        keys+=("materia_ro")
    fi
    for remote in "$@"; do
        [[ "${remote}" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Bad remote name: ${remote}" >&2; exit 1; }
        newkey "materia_${remote}_ro"
        keys+=("materia_${remote}_ro")
    done

    # GitHub's host keys come from its API over HTTPS (remotes are assumed to be on GitHub); any other host's are yours
    # to add.
    if [[ "${host}" == github.com || $# -gt 0 ]] && ! ssh-keygen -F github.com -f "${HOME}/.ssh/known_hosts" >/dev/null 2>&1; then
        curl -fsSL https://api.github.com/meta | jq -r '.ssh_keys[] | "github.com " + .' >> "${HOME}/.ssh/known_hosts"
    fi
    if [[ -n "${host}" && "${host}" != github.com ]] && ! ssh-keygen -F "${host}" -f "${HOME}/.ssh/known_hosts" >/dev/null 2>&1; then
        echo "Add ${host}'s host key to ~/.ssh/known_hosts: Materia won't connect without it."
    fi

    [[ ! -f "${cfg}/materia.env" ]] || cp "${cfg}/materia.env" "${cfg}/materia.env.bak"
    printf '%s\n' "${env[@]}" > "${cfg}/materia.env"
    systemctl --user enable --now podman.socket

    echo
    echo "Age recipient (encrypt the repo's attributes/<host>.age to it):"
    echo "    $(age-keygen -y "${cfg}/key.txt")"
    if [[ ${#keys[@]} -gt 0 ]]; then
        echo "Read-only deploy keys to add:"
        for key in "${keys[@]}"; do
            if [[ "${key}" == materia_ro ]]; then echo "  the repo (${url}):"; else k="${key#materia_}"; echo "  ${k%_ro}:"; fi
            echo "    $(cat "${HOME}/.ssh/${key}.pub")"
        done
    fi
    echo
    if gum confirm "Start materia-update now?"; then
        systemctl --user start materia-update.service
    else
        echo "Later: systemctl --user start materia-update.service"
    fi
