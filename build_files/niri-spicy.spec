# losnoco's spicy niri fork. Built by build-niri-spicy.sh, which supplies
# niri_{version,release,srcdir,targetdir,compdir,ref} and smithay_ref.
#
# Named `niri`, not `niri-spicy`: 26.4.x outranks the Copr's
# 0.0.git.NNNN.hash, so this upgrades in place instead of needing a swap.

# Prebuilt binary, nothing to pull debuginfo from.
%global debug_package %{nil}
%global _build_id_links none

# %%{_userunitdir} comes from systemd-rpm-macros, %%{_licensedir} from
# redhat-rpm-config, which isn't installed here. An unresolved macro packages a
# directory named after itself instead of failing, so fill in what's missing.
%{?!_userunitdir:%global _userunitdir %{_prefix}/lib/systemd/user}
%{?!_licensedir:%global _licensedir %{_datadir}/licenses}

Name:           niri
Version:        %{niri_version}
Release:        %{niri_release}
Summary:        A scrollable-tiling Wayland compositor (losnoco spicy fork)

License:        GPL-3.0-or-later
URL:            https://github.com/losnoco/niri

Provides:       niri-spicy = %{version}-%{release}

# dlopen'd or spawned at runtime, so the dep generator misses them.
# xwayland-satellite is pulled in here and nowhere else.
Requires:       mesa-dri-drivers
Requires:       mesa-libEGL
Requires:       vulkan-loader
Requires:       xwayland-satellite == 0.8.1

%description
niri is a scrollable-tiling Wayland compositor.

This is losnoco's "spicy" fork (%{niri_ref}) built against losnoco's smithay
fork (%{smithay_ref}), which adds HDR output support, a Vulkan renderer,
window minimizing, per-output tearing control and xdg-decoration v2.

%install
install -Dpm0755 %{niri_targetdir}/release/niri \
    %{buildroot}%{_bindir}/niri
install -Dpm0755 %{niri_srcdir}/resources/niri-session \
    %{buildroot}%{_bindir}/niri-session

install -Dpm0644 %{niri_srcdir}/resources/niri.service \
    %{buildroot}%{_userunitdir}/niri.service
install -Dpm0644 %{niri_srcdir}/resources/niri-shutdown.target \
    %{buildroot}%{_userunitdir}/niri-shutdown.target
install -Dpm0644 %{niri_srcdir}/resources/niri.desktop \
    %{buildroot}%{_datadir}/wayland-sessions/niri.desktop
install -Dpm0644 %{niri_srcdir}/resources/niri-portals.conf \
    %{buildroot}%{_datadir}/xdg-desktop-portal/niri-portals.conf

install -Dpm0644 %{niri_compdir}/niri \
    %{buildroot}%{_datadir}/bash-completion/completions/niri
install -Dpm0644 %{niri_compdir}/_niri \
    %{buildroot}%{_datadir}/zsh/site-functions/_niri
install -Dpm0644 %{niri_compdir}/niri.fish \
    %{buildroot}%{_datadir}/fish/vendor_completions.d/niri.fish

install -Dpm0644 %{niri_srcdir}/LICENSE \
    %{buildroot}%{_licensedir}/niri/LICENSE

%files
%license %{_licensedir}/niri/LICENSE
%{_bindir}/niri
%{_bindir}/niri-session
%{_userunitdir}/niri.service
%{_userunitdir}/niri-shutdown.target
%{_datadir}/wayland-sessions/niri.desktop
%{_datadir}/xdg-desktop-portal/niri-portals.conf
%{_datadir}/bash-completion/completions/niri
%{_datadir}/zsh/site-functions/_niri
%{_datadir}/fish/vendor_completions.d/niri.fish

# No %%changelog: Release is regenerated every build, so entries would be noise.
