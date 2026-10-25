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

# An ssh:// or user@host: URL is a private repo. Materia's git client reads key files only (no ssh-agent): if the first
# of ~/.ssh/id_{ed25519,ecdsa,rsa} has no passphrase and can read the repo, that's used; otherwise the recipe makes a
# read-only deploy key, ~/.ssh/materia_ro. Each remote named after the host name (a private [Remotes] component) gets
# its own, ~/.ssh/materia_<remote>_ro. Rerunning keeps existing keys, and switches to your own key once it works.
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

    host=""
    case "${url}" in
        ssh://*)  host="$(sed -E 's#^ssh://([^@/]+@)?([^/:]+).*#\2#' <<<"${url}")" ;;
        *@*:*)    host="$(sed -E 's#^[^@]+@([^:]+):.*#\1#' <<<"${url}")" ;;
    esac

    # GitHub's host keys come from its API over HTTPS (remotes are assumed to be on GitHub); any other host's are yours
    # to add.
    if [[ "${host}" == github.com || $# -gt 0 ]] && ! ssh-keygen -F github.com -f "${HOME}/.ssh/known_hosts" >/dev/null 2>&1; then
        curl -fsSL https://api.github.com/meta | jq -r '.ssh_keys[] | "github.com " + .' >> "${HOME}/.ssh/known_hosts"
    fi
    if [[ -n "${host}" && "${host}" != github.com ]] && ! ssh-keygen -F "${host}" -f "${HOME}/.ssh/known_hosts" >/dev/null 2>&1; then
        echo "Add ${host}'s host key to ~/.ssh/known_hosts: Materia won't connect without it."
    fi

    # Can Materia read the repo, using key file $1 (or no key, for a public URL)? If not, ${why} says why.
    readable() {
        local ssh=()
        if [[ -n "${1:-}" ]]; then
            if ! ssh-keygen -y -P "" -f "$1" >/dev/null 2>&1; then
                why="$1 has a passphrase, which Materia can't use"
                return 1
            fi
            ssh=("GIT_SSH_COMMAND=ssh -i $1 -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes")
        fi
        why="$(env "${ssh[@]}" GIT_TERMINAL_PROMPT=0 git ls-remote "${url}" 2>&1 >/dev/null)" && return
        why="${why%%$'\n'*}"
        return 1
    }
    newkey() {
        [[ -f "${HOME}/.ssh/$1" ]] || ssh-keygen -q -t ed25519 -N "" -C "$(uname -n)-$1" -f "${HOME}/.ssh/$1"
    }
    env=("MATERIA_SOURCE__URL=${url}")
    [[ -z "${name}" ]] || env+=("MATERIA_HOSTNAME=${name}")
    keys=()
    key=""
    if [[ -n "${host}" ]]; then
        for k in id_ed25519 id_ecdsa id_rsa; do
            [[ -f "${HOME}/.ssh/${k}" ]] && { key="${HOME}/.ssh/${k}"; break; }
        done
        if [[ -n "${key}" ]] && readable "${key}"; then
            echo "Materia can read the repo with ${key}; no deploy key needed."
        else
            [[ -z "${key}" ]] || echo "${key} can't read the repo (${why}); using a deploy key."
            newkey materia_ro
            key="${HOME}/.ssh/materia_ro"
            env+=("MATERIA_GIT__PRIVATE_KEY=${key}")
            keys+=("materia_ro")
        fi
    fi
    for remote in "$@"; do
        [[ "${remote}" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Bad remote name: ${remote}" >&2; exit 1; }
        newkey "materia_${remote}_ro"
        keys+=("materia_${remote}_ro")
    done

    [[ ! -f "${cfg}/materia.env" ]] || cp "${cfg}/materia.env" "${cfg}/materia.env.bak"
    printf '%s\n' "${env[@]}" > "${cfg}/materia.env"
    systemctl --user enable --now podman.socket

    echo
    echo "Age recipient (encrypt the repo's attributes/<host>.age to it):"
    echo "    $(age-keygen -y "${cfg}/key.txt")"
    if [[ ${#keys[@]} -gt 0 ]]; then
        echo "Read-only deploy keys to add:"
        for k in "${keys[@]}"; do
            if [[ "${k}" == materia_ro ]]; then echo "  the repo (${url}):"; else r="${k#materia_}"; echo "  ${r%_ro}:"; fi
            echo "    $(cat "${HOME}/.ssh/${k}.pub")"
        done
    fi
    echo
    until readable "${key}"; do
        echo "Materia can't read ${url} yet: ${why}"
        if ! gum confirm "Check again?"; then
            echo "Once it can: systemctl --user start materia-update.service"
            exit 0
        fi
    done
    if gum confirm "Materia can read the repo. Start materia-update now?"; then
        systemctl --user start materia-update.service
    else
        echo "Later: systemctl --user start materia-update.service"
    fi
