#!/usr/bin/env bash
set -xeuo pipefail

# Spicy fork from the niri-spicy stage
dnf5 install -y /niri-spicy-rpms/niri-*.rpm
rpm -q niri --qf '%{NAME} %{VERSION}-%{RELEASE}\n' | grep spicy

dnf5 -y copr enable codifryed/CoolerControl
dnf5 install -y coolercontrol liquidctl
dnf5 -y copr disable codifryed/CoolerControl

# Ghostty
dnf5 install -y --nogpgcheck \
  --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
  terra-release
dnf5 install -y ghostty
dnf5 remove -y terra-release terra-gpg-keys

# 1pass via RPM instead of flatpak for better integration with
# desktop applications
#
# Repo setup: https://support.1password.com/install-linux/ (repo_gpgcheck
# dropped, as in the RPM's own postinst: RHBZ 1768206)
#
# /opt lives in /var, which bootc only populates on first deploy: install to
# /usr/lib and link it back. Groups get pinned GIDs, otherwise postinst takes
# GID 1000. Adapted from the BlueBuild bling installer
# (blue-build/modules modules/bling/installers/1password.sh) and
# bsherman/bos build_scripts/desktop-1password.sh.
rpm --import https://downloads.1password.com/linux/keys/1password.asc
cat > /etc/yum.repos.d/1password.repo <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF
groupadd -g 1500 onepassword
groupadd -g 1501 onepassword-mcp
groupadd -g 1502 onepassword-cli
mkdir -p /var/opt
dnf5 install -y 1password 1password-cli
rm /etc/yum.repos.d/1password.repo
mv /var/opt/1Password /usr/lib/1Password
echo 'L /opt/1Password - - - - /usr/lib/1Password' > /usr/lib/tmpfiles.d/1password.conf
printf 'g onepassword 1500\ng onepassword-mcp 1501\ng onepassword-cli 1502\n' > /usr/lib/sysusers.d/1password.conf

# Polkit policy lists local users as owners, so render it at boot. Same
# logic as the RPM's postinst and install_biometrics_policy.sh.
rm /usr/share/polkit-1/actions/com.1password.1Password.policy
cat > /usr/libexec/1password-polkit-policy <<'EOF'
#!/usr/bin/bash
set -euo pipefail
owners="$(cut -d: -f1,3 /etc/passwd | grep -E ':[0-9]{4}$' | cut -d: -f1 | head -n 10 | sed 's/^/unix-user:/' | tr '\n' ' ')"
mkdir -p /etc/polkit-1/actions
sed "s/\${POLICY_OWNERS}/${owners}/" /usr/lib/1Password/com.1password.1Password.policy.tpl \
  > /etc/polkit-1/actions/com.1password.1Password.policy.tmp
mv /etc/polkit-1/actions/com.1password.1Password.policy.tmp /etc/polkit-1/actions/com.1password.1Password.policy
EOF
chmod 755 /usr/libexec/1password-polkit-policy
cat > /usr/lib/systemd/system/1password-polkit-policy.service <<'EOF'
[Unit]
Description=Generate 1Password polkit policy for local users
Before=polkit.service

[Service]
Type=oneshot
ExecStart=/usr/libexec/1password-polkit-policy

[Install]
WantedBy=multi-user.target
EOF
systemctl enable 1password-polkit-policy.service

# Flatpak browser integration, see `zjust setup-1password-flatpak`.
# https://github.com/flatpak/xdg-native-messaging-proxy, Firefox 157+
# (https://bugzilla.mozilla.org/show_bug.cgi?id=1955255)
dnf5 install -y xdg-native-messaging-proxy
printf '\nxdg-native-messaging-proxy\n' >> /etc/1password/custom_allowed_browsers

# 1Password's "start at login" (~/.config/autostart) races DMS, and Electron only registers its tray icon if the
# StatusNotifierWatcher is already up. dms.service is Type=notify, so ordering after it is enough.
mkdir -p /usr/lib/systemd/user/app-com.onepassword.OnePassword@autostart.service.d
cat > /usr/lib/systemd/user/app-com.onepassword.OnePassword@autostart.service.d/after-dms.conf <<'EOF'
[Unit]
After=dms.service
EOF

# niri: additions to Zirconium's defaults through its system-wide override (zirconium.kdl includes /etc/niri/local.kdl,
# ahead of DMS's configs), and niri-hdr, whose ~/.config/niri/hdr.kdl they include. ~/.config/niri stays Zirconium's.
install -Dm644 /ctx/niri/porcoferrum.kdl /usr/share/porcoferrum/niri/porcoferrum.kdl
mkdir -p /etc/niri
echo 'include "/usr/share/porcoferrum/niri/porcoferrum.kdl"' > /etc/niri/local.kdl
install -Dm755 /ctx/niri/niri-hdr /usr/bin/niri-hdr

test -x /usr/bin/materia

# zjust recipes
install -m 644 /ctx/70-porcoferrum.just /usr/share/zirconium/just/70-porcoferrum.just
echo 'import "/usr/share/zirconium/just/70-porcoferrum.just"' >> /usr/share/zirconium/just/00-start.just

dnf5 clean all
