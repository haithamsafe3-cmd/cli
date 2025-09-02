#!/bin/bash
# Script to install GitHub CLI (gh) on Debian/Ubuntu systems
set -e

# Ensure wget is installed
if ! type -p wget >/dev/null; then
    sudo apt update
    sudo apt install wget -y
fi

# Create keyrings directory
sudo mkdir -p -m 755 /etc/apt/keyrings

# Download the GitHub CLI GPG key
out=$(mktemp)
wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg
cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

# Add the GitHub CLI repository
sudo mkdir -p -m 755 /etc/apt/sources.list.d
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# Update and install gh
sudo apt update
sudo apt install gh -y
