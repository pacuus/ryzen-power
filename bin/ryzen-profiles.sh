#!/bin/bash

# =====================================================================
# SCRIPT DE GESTION DES PROFILS RYZENADJ (Asus TUF / Ryzen 7 3750H)
# Usage : sudo ./ryzen-profiles.sh [silencieux | equilibre | turbo]
# =====================================================================

# 1. Vérification des droits administrateur (requis par RyzenAdj)
if [ "$EUID" -ne 0 ]; then
  echo "Erreur : Ce script doit être exécuté avec sudo."
  exit 1
fi

# 2. Vérification de la présence de RyzenAdj
if ! command -v ryzenadj &> /dev/null; then
    echo "Erreur : 'ryzenadj' est introuvable sur le système."
    exit 1
fi

# =====================================================================
# CONFIGURATION DES VALEURS PAR PROFIL
# =====================================================================

# --- PROFIL 1 : SILENCIEUX (Cible ~45°C - 50°C / Zéro bruit) ---
QUIET_STAPM=18000       # Puissance continue : 12W
QUIET_FAST=22000        # Pic de puissance : 15W
QUIET_SLOW=20000        # Puissance intermédiaire : 12W
QUIET_STAPM_TIME=200    # Temps STAPM : 300s
QUIET_SLOW_TIME=5       # Temps Slow : 5s
QUIET_TDC_VDD=20000     # Courant continu CPU : 18A
QUIET_TDC_SOC=10000     # Courant continu SoC : 10A
QUIET_EDC_VDD=25000     # Courant de pointe CPU : 25A (coupe les micro-boosts)
QUIET_EDC_SOC=10000     # Courant de pointe SoC : 14A
QUIET_TEMP=48           # Limite de température : 48°C

# --- PROFIL 2 : ÉQUILIBRÉ (Bureautique active & Multimédia) ---
BALANCED_STAPM=25000    # 25W
BALANCED_FAST=30000     # 30W
BALANCED_SLOW=27000     # 25W
BALANCED_STAPM_TIME=200 # 300s
BALANCED_SLOW_TIME=5    # 5s
BALANCED_TDC_VDD=30000  # 30A
BALANCED_TDC_SOC=10000  # 12A
BALANCED_EDC_VDD=45000  # 45A
BALANCED_EDC_SOC=10000  # 16A
BALANCED_TEMP=70        # 80°C

# --- PROFIL 3 : TURBO (Performances maximales d'usine pour le jeu) ---
TURBO_STAPM=35000       # 35W
TURBO_FAST=45000        # 45W
TURBO_SLOW=40000        # 35W
TURBO_STAPM_TIME=200    # 300s
TURBO_SLOW_TIME=5       # 5s
TURBO_TDC_VDD=35000     # 35A
TURBO_TDC_SOC=14000     # 14A
TURBO_EDC_VDD=48000     # 48A
TURBO_EDC_SOC=18000     # 18A
TURBO_TEMP=90           # 95°C

# =====================================================================
# FONCTION D'APPLICATION DES PARAMÈTRES
# =====================================================================

apply_ryzenadj() {
    ryzenadj \
      --stapm-limit=$1 \
      --fast-limit=$2 \
      --slow-limit=$3 \
      --stapm-time=$4 \
      --slow-time=$5 \
      --vrm-current=$6 \
      --vrmsoc-current=$7 \
      --vrmmax-current=$8 \
      --vrmsocmax-current=$9 \
      --tctl-temp=${10}
}

# =====================================================================
# SÉLECTION ET SCRIPT INTERACTIF
# =====================================================================

PROFILE=$1

# Si aucun paramètre n'a été transmis, affichage du menu
if [ -z "$PROFILE" ]; then
    echo "================================================="
    echo "        SÉLECTION DU PROFIL RYZENADJ            "
    echo "================================================="
    echo "1) Silencieux  (12W | EDC: 25A | Temp Max: 48°C)"
    echo "2) Équilibré   (25W | EDC: 45A | Temp Max: 80°C)"
    echo "3) Turbo       (35W | EDC: 48A | Temp Max: 95°C)"
    echo "================================================="
    read -p "Choisissez un profil (1-3) : " CHOICE
    case $CHOICE in
        1) PROFILE="silencieux" ;;
        2) PROFILE="equilibre" ;;
        3) PROFILE="turbo" ;;
        *) echo "Option invalide. Annulation."; exit 1 ;;
    esac
fi

# Application selon le profil sélectionné
case $(echo "$PROFILE" | tr '[:upper:]' '[:lower:]') in
    silencieux|quiet|1)
        echo "-> Application du profil SILENCIEUX..."
        apply_ryzenadj $QUIET_STAPM $QUIET_FAST $QUIET_SLOW $QUIET_STAPM_TIME $QUIET_SLOW_TIME $QUIET_TDC_VDD $QUIET_TDC_SOC $QUIET_EDC_VDD $QUIET_EDC_SOC $QUIET_TEMP
        echo "✓ Profil Silencieux activé."
        ;;
    equilibre|balanced|2)
        echo "-> Application du profil ÉQUILIBRÉ..."
        apply_ryzenadj $BALANCED_STAPM $BALANCED_FAST $BALANCED_SLOW $BALANCED_STAPM_TIME $BALANCED_SLOW_TIME $BALANCED_TDC_VDD $BALANCED_TDC_SOC $BALANCED_EDC_VDD $BALANCED_EDC_SOC $BALANCED_TEMP
        echo "✓ Profil Équilibré activé."
        ;;
    turbo|performance|3)
        echo "-> Application du profil TURBO..."
        apply_ryzenadj $TURBO_STAPM $TURBO_FAST $TURBO_SLOW $TURBO_STAPM_TIME $TURBO_SLOW_TIME $TURBO_TDC_VDD $TURBO_TDC_SOC $TURBO_EDC_VDD $TURBO_EDC_SOC $TURBO_TEMP
        echo "✓ Profil Turbo activé."
        ;;
    *)
        echo "Profil inconnu : '$PROFILE'"
        echo "Usage: sudo $0 [silencieux | equilibre | turbo]"
        exit 1
        ;;
esac
