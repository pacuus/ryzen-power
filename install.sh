#!/bin/bash
set -e

echo "=== Déploiement universel Ryzen & ROG Power Management (Direct /dev/mem) ==="

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

# 2. Résolution des conflits d'énergie
if systemctl is-active --quiet tlp 2>/dev/null; then
    echo "-> Désactivation de TLP pour éviter les conflits..."
    sudo systemctl disable --now tlp
fi

# 3. Installation des dépendances (sans DKMS ni en-têtes de noyau)
echo "-> Installation des outils système et dépendances..."
case "$PKG_MANAGER" in
    arch)
        sudo pacman -Sy --needed --noconfirm \
            base-devel cmake pciutils git \
            power-profiles-daemon dbus \
            asusctl rog-control-center supergfxctl
        ;;
    fedora)
        sudo dnf copr enable -y lukenukem/asus-linux 2>/dev/null || true
        sudo dnf install -y \
            gcc gcc-c++ make cmake pciutils-devel git \
            power-profiles-daemon dbus-tools \
            asusctl rog-control-center supergfxctl
        ;;
    debian)
        sudo apt-get update
        sudo apt-get install -y \
            build-essential cmake libpci-dev git \
            power-profiles-daemon dbus-x11
        ;;
    suse)
        sudo zypper --non-interactive install \
            cmake gcc-c++ make pciutils-devel git \
            power-profiles-daemon dbus-1-tools
        ;;
esac

# 4. Compilation et installation de RyzenAdj
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

# 5. Déploiement des scripts
echo "-> Déploiement des exécutables dans /usr/local/bin..."
sudo cp -v bin/ryzen-profiles.sh /usr/local/bin/
sudo cp -v bin/ryzenadj-auto.sh /usr/local/bin/

sudo chmod +x /usr/local/bin/ryzen-profiles.sh
sudo chmod +x /usr/local/bin/ryzenadj-auto.sh

# 6. Règle Sudoers
echo "-> Configuration de la règle sudoers..."
sudo mkdir -p /etc/sudoers.d
echo "%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/ryzen-profiles.sh" | sudo tee /etc/sudoers.d/ryzen-profiles > /dev/null
echo "%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/ryzen-profiles.sh" | sudo tee -a /etc/sudoers.d/ryzen-profiles > /dev/null
sudo chmod 0440 /etc/sudoers.d/ryzen-profiles

# 7. Déploiement et démarrage des services Systemd
echo "-> Activation des services système..."
sudo cp -v services/ryzenadj-auto.service /etc/systemd/system/
sudo cp -v services/ryzenadj-resume.service /etc/systemd/system/

sudo systemctl daemon-reload

# Démarrage des daemons Asus et de profils
sudo systemctl enable --now asusd.service 2>/dev/null || true
sudo systemctl enable --now supergfxd.service 2>/dev/null || true
sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || true

# Démarrage des automatisations
sudo systemctl enable --now ryzenadj-auto.service
sudo systemctl enable ryzenadj-resume.service

echo "=== Déploiement terminé ! ==="
echo "NOTE : Assurez-vous d'avoir ajouté 'iomem=relaxed' aux paramètres de boot de votre noyau."
