#!/bin/bash
set -e

echo "=== Déploiement universel Ryzen & ROG Power Management ==="

# 1. Détection du gestionnaire de paquets
if command -v pacman &> /dev/null; then
    PKG_MANAGER="arch"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="fedora"
elif command -v apt-get &> /dev/null; then
    PKG_MANAGER="debian"
elif command -v zypper &> /dev/null; then
    PKG_MANAGER="suse"
else
    echo "Erreur : Gestionnaire de paquets non supporté."
    exit 1
fi

echo "-> Distribution détectée : $PKG_MANAGER"

# 2. Résolution des conflits d'énergie (TLP bloque power-profiles-daemon)
if systemctl is-active --quiet tlp 2>/dev/null; then
    echo "-> Désactivation de TLP pour éviter les conflits..."
    sudo systemctl disable --now tlp
fi

# 3. Installation des dépendances et de l'écosystème ROG
echo "-> Installation des outils système, ROG Control Center et dépendances..."
case "$PKG_MANAGER" in
    arch)
        KERNEL_VER=$(uname -r)
        if [[ "$KERNEL_VER" =~ "cachyos" ]]; then
            HEADERS="linux-cachyos-headers"
        elif [[ "$KERNEL_VER" =~ "lts" ]]; then
            HEADERS="linux-lts-headers"
        elif [[ "$KERNEL_VER" =~ "zen" ]]; then
            HEADERS="linux-zen-headers"
        else
            HEADERS="linux-headers"
        fi
        sudo pacman -Sy --needed --noconfirm \
            base-devel cmake pciutils git dkms "$HEADERS" \
            power-profiles-daemon dbus \
            asusctl rog-control-center supergfxctl
        ;;

    fedora)
        sudo dnf copr enable -y lukenukem/asus-linux
        sudo dnf install -y \
            gcc gcc-c++ make cmake pciutils-devel git dkms \
            kernel-devel kernel-headers power-profiles-daemon dbus-tools \
            asusctl rog-control-center supergfxctl
        ;;

    debian)
        sudo apt-get update
        sudo apt-get install -y \
            build-essential cmake libpci-dev git dkms \
            linux-headers-"$(uname -r)" power-profiles-daemon dbus-x11
        ;;

    suse)
        sudo zypper --non-interactive install \
            cmake gcc-c++ make pciutils-devel git dkms kernel-devel \
            power-profiles-daemon dbus-1-tools
        ;;
esac

# 4. Compilation et installation du module ryzen_smu via DKMS
if ! dkms status 2>/dev/null | grep -q "ryzen_smu"; then
    echo "-> Compilation et installation de ryzen_smu..."
    TMP_SMU=$(mktemp -d)
    git clone https://github.com/amkillam/ryzen_smu.git "$TMP_SMU"
    (cd "$TMP_SMU" && sudo make dkms-install)
    rm -rf "$TMP_SMU"
else
    echo "-> Module ryzen_smu déjà configuré."
fi

# 5. Chargement automatique de ryzen_smu au démarrage
sudo mkdir -p /etc/modules-load.d
echo "ryzen_smu" | sudo tee /etc/modules-load.d/ryzen_smu.conf > /dev/null
sudo modprobe ryzen_smu 2>/dev/null || true

# 6. Compilation et installation de RyzenAdj
if ! command -v ryzenadj &> /dev/null; then
    echo "-> Compilation de RyzenAdj..."
    TMP_ADJ=$(mktemp -d)
    git clone https://github.com/FlyGoat/RyzenAdj.git "$TMP_ADJ"
    cmake -B "$TMP_ADJ/build" -S "$TMP_ADJ" -DCMAKE_BUILD_TYPE=Release
    make -C "$TMP_ADJ/build" -j"$(nproc)"
    sudo cp -v "$TMP_ADJ/build/ryzenadj" /usr/local/bin/
    rm -rf "$TMP_ADJ"
else
    echo "-> RyzenAdj déjà présent."
fi

# 7. Déploiement des scripts
echo "-> Déploiement des exécutables dans /usr/local/bin..."
sudo cp -v bin/ryzen-profiles.sh /usr/local/bin/
sudo cp -v bin/ryzenadj-auto.sh /usr/local/bin/

sudo chmod +x /usr/local/bin/ryzen-profiles.sh
sudo chmod +x /usr/local/bin/ryzenadj-auto.sh

# 8. Règle Sudoers
echo "-> Configuration de la règle sudoers..."
sudo mkdir -p /etc/sudoers.d
echo "%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/ryzen-profiles.sh" | sudo tee /etc/sudoers.d/ryzen-profiles > /dev/null
echo "%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/ryzen-profiles.sh" | sudo tee -a /etc/sudoers.d/ryzen-profiles > /dev/null
sudo chmod 0440 /etc/sudoers.d/ryzen-profiles

# 9. Déploiement et démarrage des services Systemd
echo "-> Activation des services système..."
sudo cp -v services/ryzenadj-auto.service /etc/systemd/system/
sudo cp -v services/ryzenadj-resume.service /etc/systemd/system/

sudo systemctl daemon-reload

# Démarrage de la stack Asus & Power
sudo systemctl enable --now asusd.service 2>/dev/null || true
sudo systemctl enable --now supergfxd.service 2>/dev/null || true
sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || true

# Démarrage des services personnalisés
sudo systemctl enable --now ryzenadj-auto.service
sudo systemctl enable ryzenadj-resume.service

echo "=== Déploiement finalisé avec succès ! ==="
