#!/bin/bash
set -e

echo "=== Installation universelle Ryzen Power Management ==="

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

echo "-> Système détecté : $PKG_MANAGER"

# 2. Installation des dépendances et en-têtes du noyau
echo "-> Installation des dépendances requises..."
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
        sudo pacman -Sy --needed --noconfirm base-devel cmake pciutils git dkms "$HEADERS" power-profiles-daemon
        ;;
    fedora)
        sudo dnf install -y gcc gcc-c++ make cmake pciutils-devel git dkms kernel-devel kernel-headers power-profiles-daemon
        ;;
    debian)
        sudo apt-get update
        sudo apt-get install -y build-essential cmake libpci-dev git dkms linux-headers-"$(uname -r)" power-profiles-daemon
        ;;
    suse)
        sudo zypper --non-interactive install cmake gcc-c++ make pciutils-devel git dkms kernel-devel power-profiles-daemon
        ;;
esac

# 3. Compilation et installation du module noyau ryzen_smu via DKMS
if ! dkms status 2>/dev/null | grep -q "ryzen_smu"; then
    echo "-> Compilation de ryzen_smu..."
    TMP_SMU=$(mktemp -d)
    git clone https://github.com/amkillam/ryzen_smu.git "$TMP_SMU"
    (cd "$TMP_SMU" && sudo make dkms-install)
    rm -rf "$TMP_SMU"
else
    echo "-> Module ryzen_smu déjà installé dans DKMS."
fi

# 4. Chargement du module ryzen_smu
echo "-> Configuration du chargement automatique de ryzen_smu..."
sudo mkdir -p /etc/modules-load.d
echo "ryzen_smu" | sudo tee /etc/modules-load.d/ryzen_smu.conf > /dev/null
sudo modprobe ryzen_smu 2>/dev/null || true

# 5. Compilation et installation de RyzenAdj
if ! command -v ryzenadj &> /dev/null; then
    echo "-> Compilation de RyzenAdj..."
    TMP_ADJ=$(mktemp -d)
    git clone https://github.com/FlyGoat/RyzenAdj.git "$TMP_ADJ"
    cmake -B "$TMP_ADJ/build" -S "$TMP_ADJ" -DCMAKE_BUILD_TYPE=Release
    make -C "$TMP_ADJ/build" -j"$(nproc)"
    sudo cp -v "$TMP_ADJ/build/ryzenadj" /usr/local/bin/
    rm -rf "$TMP_ADJ"
else
    echo "-> Binaire ryzenadj déjà présent dans le PATH."
fi

# 6. Déploiement des scripts d'action
echo "-> Déploiement des scripts dans /usr/local/bin/..."
sudo cp -v bin/ryzen-profiles.sh /usr/local/bin/
sudo cp -v bin/ryzenadj-auto.sh /usr/local/bin/

sudo chmod +x /usr/local/bin/ryzen-profiles.sh
sudo chmod +x /usr/local/bin/ryzenadj-auto.sh

# 7. Déploiement et activation des services Systemd
echo "-> Configuration des services Systemd..."
sudo cp -v services/ryzenadj-auto.service /etc/systemd/system/
sudo cp -v services/ryzenadj-resume.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || true
sudo systemctl enable --now ryzenadj-auto.service
sudo systemctl enable ryzenadj-resume.service

echo "=== Déploiement terminé avec succès ! ==="
