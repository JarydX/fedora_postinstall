#!/usr/bin/env bash
#
# Fedora KDE Post-Installation Script
# ------------------------------------
# Automatisiert:
# 1. DNF Konfiguration (parallele Downloads)
# 2. RPM Fusion Repositories (Free & Nonfree) & Flathub
# 3. GPU-Erkennung (NVIDIA, AMD, Intel, Multi-GPU) inkl. Treibern und Kernel-Modulen
# 4. Vollständige Multimedia-Codecs & Hardware-Videobeschleunigung
# 5. Gaming-Setup (Steam, Lutris, Proton Plus, Gamemode, Mangohud)
#

set -euo pipefail

# --- Farben & UI-Hilfsfunktionen ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[ERFOLG]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARNUNG]${NC} $*"; }
log_error()   { echo -e "${RED}[FEHLER]${NC} $*" >&2; }
log_step()    { echo -e "\n${CYAN}${BOLD}==> $*${NC}"; }

# --- Root-Prüfung ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_warn "Dieses Skript benötigt Root-Rechte. Starte mit 'sudo' neu..."
        exec sudo bash "$0" "$@"
    fi
}

# --- 1. DNF optimieren ---
optimize_dnf() {
    log_step "1/6: DNF Konfiguration prüfen & optimieren"
    
    local dnf_conf="/etc/dnf/dnf.conf"
    if [[ -f "$dnf_conf" ]]; then
        if ! grep -q "^max_parallel_downloads=" "$dnf_conf"; then
            echo "max_parallel_downloads=10" >> "$dnf_conf"
            log_info "Parallele Downloads auf 10 gesetzt."
        fi
        if ! grep -q "^fastestmirror=" "$dnf_conf"; then
            echo "fastestmirror=True" >> "$dnf_conf"
            log_info "Fastestmirror aktiviert."
        fi
        log_success "DNF ist optimiert."
    fi

    # Sicherstellen, dass pciutils für lspci vorhanden ist
    if ! command -v lspci &>/dev/null; then
        log_info "Installiere pciutils für Hardware-Erkennung..."
        dnf install -y pciutils
    fi
}

# --- 2. RPM Fusion & Flathub aktivieren ---
enable_repositories() {
    log_step "2/6: RPM Fusion Repositories und Flathub einrichten"
    
    local fedora_version
    fedora_version="$(rpm -E %fedora)"
    
    log_info "Erkannte Fedora-Version: ${fedora_version}"

    # RPM Fusion Free & Nonfree
    log_info "Installiere RPM Fusion Free und Nonfree..."
    dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm" \
        || log_warn "RPM Fusion Paket-Installation meldete Fehler oder ist bereits installiert."

    # AppStream Metadaten für KDE Discover
    log_info "Aktualisiere AppStream-Metadaten für Software-Center..."
    dnf group upgrade core -y || true

    # OpenH264 Repo aktivieren
    log_info "Aktiviere fedora-cisco-openh264..."
    dnf config-manager setopt fedora-cisco-openh264.enabled=1 || true

    # Flathub hinzufügen
    if command -v flatpak &>/dev/null; then
        log_info "Aktiviere Flathub Flatpak Repository..."
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    else
        log_info "Installiere flatpak und aktiviere Flathub..."
        dnf install -y flatpak
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi

    log_success "Repositories erfolgreich konfiguriert."
}

# --- 3. GPU-Erkennung & Treiber-Installation ---
setup_gpu() {
    log_step "3/6: Grafikkarte erkennen und Treiber konfigurieren"
    
    local gpus
    gpus="$(lspci -nn | grep -E "VGA|3D|Display" || true)"
    
    echo -e "${BOLD}Erkannte Grafik-Hardware:${NC}"
    echo "$gpus"
    echo ""

    local has_nvidia=false
    local has_amd=false
    local has_intel=false

    if echo "$gpus" | grep -qiE "10de:|NVIDIA|GeForce"; then
        has_nvidia=true
    fi
    if echo "$gpus" | grep -qiE "1002:|AMD|ATI|Radeon"; then
        has_amd=true
    fi
    if echo "$gpus" | grep -qiE "8086:|Intel"; then
        has_intel=true
    fi

    # NVIDIA Setup
    if [[ "$has_nvidia" == true ]]; then
        log_info "NVIDIA GPU erkannt. Installiere Treiber und Kernel-Module (akmod-nvidia)..."
        
        # Kernel-Headers, akmod-nvidia und 32-bit Bibliotheken für Steam/Gaming
        dnf install -y \
            kernel-devel \
            kernel-headers \
            akmod-nvidia \
            xorg-x11-drv-nvidia-cuda \
            xorg-x11-drv-nvidia-cuda-libs \
            xorg-x11-drv-nvidia-cuda-libs.i686 \
            libva-nvidia-driver

        # Secure Boot Prüfung
        if command -v mokutil &>/dev/null && mokutil --sb-state 2>/dev/null | grep -qi "SecureBoot enabled"; then
            echo ""
            log_warn "ACHTUNG: Secure Boot ist aktiv!"
            log_warn "Der NVIDIA-Treiber benötigt signierte Kernel-Module."
            log_warn "Falls noch kein MOK-Schlüssel registriert wurde, bitte folgenden Befehl ausführen:"
            log_warn "  sudo kmodgenca"
            log_warn "  sudo mokutil --import /etc/pki/akmods/certs/public_key.der"
            log_warn "Danach neu starten und das MOK-Passwort beim Booten eingeben."
            echo ""
        fi

        # Akmods Kompilierung erzwingen / überwachen
        log_info "Kompiliere NVIDIA Kernel-Module via akmods (bitte kurz warten)..."
        akmods --force || log_warn "akmods meldete einen Hinweis/Code. Überprüfe kmodtool / akmods."
        log_success "NVIDIA Setup abgeschlossen."
    fi

    # AMD Setup
    if [[ "$has_amd" == true ]]; then
        log_info "AMD GPU erkannt. Konfiguriere Mesa & Hardware-Videobeschleunigung..."
        
        # Mesa Vulkan, VA-API/VDPAU Freeworld (mit H.264/HEVC Entlastung) und 32-Bit für Gaming
        dnf install -y \
            mesa-vulkan-drivers \
            mesa-vulkan-drivers.i686 \
            mesa-va-drivers-freeworld \
            mesa-va-drivers-freeworld.i686 \
            mesa-vdpau-drivers-freeworld \
            mesa-vdpau-drivers-freeworld.i686 \
            libva-utils \
            vdpauinfo || log_warn "Einige AMD-Pakete sind eventuell bereits installiert oder werden gleich im Multimedia-Schritt ergänzt."
            
        log_success "AMD Treiber & Mesa-Erweiterungen eingerichtet."
    fi

    # Intel Setup
    if [[ "$has_intel" == true ]]; then
        log_info "Intel GPU erkannt. Konfiguriere Intel Media Driver & Vulkan..."
        
        dnf install -y \
            mesa-vulkan-drivers \
            mesa-vulkan-drivers.i686 \
            intel-media-driver \
            libva-intel-driver \
            libva-utils || true
            
        log_success "Intel Treiber & Beschleunigung eingerichtet."
    fi

    if [[ "$has_nvidia" == false && "$has_amd" == false && "$has_intel" == false ]]; then
        log_warn "Keine spezifische NVIDIA/AMD/Intel GPU eindeutig identifiziert. Standard-Mesa-Treiber bleiben aktiv."
    fi
}

# --- 4. Multimedia Pakete & Codecs ---
setup_multimedia() {
    log_step "4/6: Multimedia-Codecs installieren (RPM Fusion)"

    # ffmpeg-free gegen vollwertiges ffmpeg tauschen
    log_info "Tausche ffmpeg-free gegen vollwertiges ffmpeg (inkl. aller Codecs)..."
    dnf swap -y ffmpeg-free ffmpeg --allowerasing || log_warn "ffmpeg ist möglicherweise bereits das vollständige Paket."

    # Multimedia-Gruppen installieren (nach RPM Fusion HowTo)
    log_info "Installiere Multimedia- und Sound-Paketgruppen..."
    dnf install -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin || true
    dnf install -y @sound-and-video || true

    # GStreamer Plugins & Codecs
    log_info "Installiere erweiterte GStreamer-Plugins..."
    dnf install -y \
        gstreamer1-plugins-bad-freeworld \
        gstreamer1-plugins-ugly \
        gstreamer1-plugin-openh264 \
        gstreamer1-vaapi || true

    log_success "Multimedia-Pakete und Codecs erfolgreich installiert."
}

# --- 5. Gaming (Steam, Lutris, Proton Plus) ---
setup_gaming() {
    log_step "5/6: Gaming-Stack installieren (Steam, Lutris, Proton Plus)"

    # Steam via RPM Fusion Nonfree
    log_info "Installiere Steam (RPM Fusion)..."
    dnf install -y steam

    # Lutris via Fedora Repositories
    log_info "Installiere Lutris..."
    dnf install -y lutris

    # Gamemode & Mangohud (Sehr empfohlen für Gaming unter Linux)
    log_info "Installiere Feral Gamemode und MangoHud Performance Overlay..."
    dnf install -y gamemode mangohud

    # Proton Plus via Flatpak (offizielle und empfohlene Vertriebsform)
    log_info "Installiere Proton Plus via Flathub..."
    flatpak install -y flathub com.vysp3r.ProtonPlus || {
        log_warn "Flatpak-Installation von Proton Plus fehlgeschlagen. Prüfe Netzwerkverbindung."
    }

    log_success "Steam, Lutris und Proton Plus sind einsatzbereit."
}

# --- 6. Abschluss & Zusammenfassung ---
finish() {
    log_step "6/6: Abschluss & Überprüfung"
    
    echo -e "${GREEN}${BOLD}====================================================${NC}"
    echo -e "${GREEN}${BOLD}     Fedora KDE Post-Install erfolgreich!          ${NC}"
    echo -e "${GREEN}${BOLD}====================================================${NC}"
    echo ""
    echo -e "Folgende Komponenten wurden eingerichtet:"
    echo -e " ✔ DNF Konfiguration & RPM Fusion (Free & Nonfree)"
    echo -e " ✔ Flathub Repository"
    echo -e " ✔ Hardware-Erkennung & Treiber/Kernel-Module"
    echo -e " ✔ Vollständiges FFmpeg & Multimedia Codecs (VA-API/VDPAU)"
    echo -e " ✔ Steam, Lutris, Proton Plus, Gamemode & MangoHud"
    echo ""
    echo -e "${YELLOW}${BOLD}HINWEIS ZUM NEUSTART:${NC}"
    echo -e "Es wird dringend empfohlen, das System jetzt einmal neu zu starten,"
    echo -e "damit alle neuen Kernel-Module und Umgebungsvariablen aktiv werden:"
    echo -e "   ${BOLD}sudo systemctl reboot${NC}"
    echo ""
}

# --- Skriptausführung ---
main() {
    check_root
    optimize_dnf
    enable_repositories
    setup_gpu
    setup_multimedia
    setup_gaming
    finish
}

main "$@"
