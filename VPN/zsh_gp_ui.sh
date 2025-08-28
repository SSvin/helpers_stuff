#!/bin/zsh

#This script was written by Serhii Shulhin.

# Only for Ubuntu UI installation
if [ "$(id -u)" = "0" ]; then
    echo -e "\nGlobalProtect cannot be installed as a root user."
    echo -e "Please install the agent as a user with admin privileges.\n"
    exit 1
fi

# Remove existing GlobalProtect if installed
if dpkg -l | grep -qw globalprotect; then
    echo "Existing GlobalProtect installation detected. Removing..."
    sudo apt -y purge globalprotect
fi

# Determine Linux Distro and Version
. /etc/os-release

if [ "$ID" = "ubuntu" ]; then
    linux_ver=${VERSION_ID:0:2}
else
    echo "Error: Unsupported Linux Distro: $ID"
    exit 1
fi

# Warn if running under Wayland
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    echo "Warning: The GlobalProtect UI agent experience will be degraded with Wayland enabled."
    echo "Please switch to X11 for seamless operation."
    echo "Wayland is not currently supported for GP UI installation."
    read -p "Proceed? (y/n): " response
    case $response in
        [yY]*)
            echo "Continuing..."
            ;;
        [nN]*)
            echo "Exiting..."
            exit 1
            ;;
        *)
            echo "Invalid input. Please enter y or n."
            exit 1
            ;;
    esac
fi

case $linux_ver in
    14|16|18)
        echo "Error: Unsupported Ubuntu version: $linux_ver"
        exit 1
        ;;
    20)
        sudo apt-get install -y gnome-tweak-tool gnome-shell-extension-top-icons-plus
        sudo -E dpkg -i ./GlobalProtect_UI_deb*.deb
        sudo apt-get -f install -y
        gnome-extensions enable TopIcons@phocean.net
        gsettings set org.gnome.shell.extensions.topicons tray-pos 'right'
        ;;
    22)
        sudo apt-get install -y gnome-shell-extension-manager gnome-shell-extension-appindicator
        sudo -E dpkg -i ./GlobalProtect_UI_deb*.deb
        sudo apt-get -f install -y
        ;;
    *)
        sudo -E dpkg -i ./GlobalProtect_UI_deb*.deb
        sudo apt-get -f install -y
        ;;
esac

gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed s/.$//), 'globalprotect.desktop']"
echo "GlobalProtect Installation Completed"
sleep 5

# Stop the GlobalProtect service
sudo systemctl stop gpd.service

# Define the path to the GlobalProtect configuration file
GP_CONFIG_FILE="/opt/paloaltonetworks/globalprotect/pangps.xml"

# Check if the <default-browser> tag already exists
if grep -q "<default-browser>" "$GP_CONFIG_FILE"; then
    echo "Default browser setting already exists in $GP_CONFIG_FILE. Updating..."
    sudo sed -i 's|<default-browser>.*</default-browser>|<default-browser>yes</default-browser>|' "$GP_CONFIG_FILE"
else
    echo "Adding default browser setting to $GP_CONFIG_FILE..."
    sudo sed -i '/<Settings>/a\    <default-browser>yes</default-browser>' "$GP_CONFIG_FILE"
fi

# Start the GlobalProtect service
sudo systemctl start gpd.service

echo "GlobalProtect configured to use the default system browser for SAML authentication."