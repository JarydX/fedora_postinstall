# Fedora KDE Post-Installation Script

Ein automatisiertes Post-Installationsskript für **Fedora KDE Plasma**, basierend auf den offiziellen Anleitungen von RPM Fusion und Flathub.

## 🚀 Funktionen

1. **Paketmanager-Optimierung (`dnf.conf`):**
   - Aktiviert schnellere parallele Downloads (`max_parallel_downloads=10`).
   - Schaltet `fastestmirror=True` für beste Download-Geschwindigkeiten ein.

2. **Repository-Einrichtung:**
   - Aktiviert **RPM Fusion Free** und **Nonfree** Repositories passend zur Fedora-Version.
   - Aktiviert **AppStream-Metadaten** (damit Discover / KDE Plasma Software Center Pakete aus RPM Fusion anzeigt).
   - Aktiviert **fedora-cisco-openh264** für H.264-Unterstützung.
   - Richtet das **Flathub** Repository für Flatpaks ein.

3. **GPU-Erkennung & Treiber/Kernel-Module:**
   - Erkennt automatisch die verbaute(n) Grafikkarte(n) via `lspci` (unterstützt auch Hybrid-/Dual-GPU-Systeme):
     - **NVIDIA:** Installiert `akmod-nvidia`, Kernel-Headers/Devel, CUDA-Unterstützung (`xorg-x11-drv-nvidia-cuda`), 32-Bit-Kompatibilitätsbibliotheken für Gaming sowie `libva-nvidia-driver`. Führt `akmods --force` aus und warnt vor aktivem Secure Boot mit MOK-Registrierungsschritten.
     - **AMD:** Installiert `mesa-vulkan-drivers` (inkl. 32-Bit) sowie die RPM-Fusion `mesa-va-drivers-freeworld` und `mesa-vdpau-drivers-freeworld` für vollständige Hardware-Videodekodierung (H.264, HEVC/H.265).
     - **Intel:** Installiert `intel-media-driver` (Broadwell+) bzw. `libva-intel-driver` und Vulkan-Treiber.

4. **Multimedia-Pakete & Codecs:**
   - Tauscht das beschnittene `ffmpeg-free` nahtlos gegen das vollwertige `ffmpeg` (`--allowerasing`).
   - Installiert die Paketgruppen `@multimedia` und `@sound-and-video`.
   - Installiert GStreamer-Codecs (`gstreamer1-plugins-bad-freeworld`, `gstreamer1-plugins-ugly`, etc.).

5. **Gaming-Stack:**
   - **Steam:** Nativ über RPM Fusion Nonfree.
   - **Lutris:** Nativ über die offiziellen Repositories.
   - **Proton Plus:** Offiziell und aktuell via Flathub (`com.vysp3r.ProtonPlus`).
   - **Performance-Tools:** Installiert zusätzlich `gamemode` (Feral GameMode) und `mangohud` (FPS- & Hardware-Overlay).

---

## 🛠️ Verwendung

1. Terminal im Projektordner öffnen.
2. Das Skript ausführen:

```bash
chmod +x postinstall.sh
./postinstall.sh
```

*(Das Skript fordert automatisch `sudo`-Rechte an, falls es nicht bereits als Root ausgeführt wird).*

3. Nach Abschluss des Skripts das System neu starten:

```bash
sudo systemctl reboot
```

---

## ⚠️ Wichtiger Hinweis zu Secure Boot (NVIDIA)

Falls du eine NVIDIA-Grafikkarte nutzt und **Secure Boot** im UEFI/BIOS aktiviert ist, verlangt der Linux-Kernel signierte Kernel-Module.
Vor dem Neustart müssen die Module mit einem MOK (Machine Owner Key) signiert oder Secure Boot im BIOS deaktiviert werden:

```bash
# Eigenen Schlüssel generieren (falls noch nicht vorhanden):
sudo kmodgenca

# Schlüssel in MOK importieren:
sudo mokutil --import /etc/pki/akmods/certs/public_key.der
```

Beim anschließenden Neustart erscheint das blaue MOK-Menü (*"Enroll MOK"*), wo das gewählte Passwort eingegeben werden muss.
