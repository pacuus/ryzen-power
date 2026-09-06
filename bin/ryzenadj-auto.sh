#!/bin/bash

# 1. Attendre que le service powerprofilesctl et D-Bus soient opérationnels
until powerprofilesctl get &>/dev/null; do
    sleep 1
done

apply_current_profile() {
    CURRENT=$(powerprofilesctl get 2>/dev/null | tr -d '[:space:]')
    case "$CURRENT" in
        "power-saver")
            /usr/local/bin/ryzen-profiles.sh silencieux
            ;;
        "performance")
            /usr/local/bin/ryzen-profiles.sh turbo
            ;;
        "balanced"|*)
            /usr/local/bin/ryzen-profiles.sh equilibre
            ;;
    esac
}

# 2. Petite pause de 2 secondes pour laisser le contrôleur SMU se stabiliser
sleep 2

# 3. Appliquer le profil actuel au démarrage
apply_current_profile

# 4. Écouter le D-Bus pour les futurs changements (ROG Control Center / Fn+F5)
stdbuf -oL dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',path='/net/hadess/PowerProfiles'" | \
while read -r line; do
    if echo "$line" | grep -q "member=PropertiesChanged"; then
        sleep 0.2
        apply_current_profile
    fi
done
