#!/bin/bash

# Enable strict mode
set -e

# Check if DEBUG is set to true or 1, enable debug print statements if so
if [[ "$DEBUG" == "true" || "$DEBUG" == "1" ]]; then
  set -x
fi

# Default artifacts directory
DEFAULT_ARTIFACTS_DIR="$(pwd)/deb-repo-test"

# Function to prompt user to continue to the next step with explanations
prompt_continue() {
  echo
  read -p "$1 Press Enter to continue..."
}

# Function to prompt for the artifacts directory and ensure it exists
prompt_for_artifacts_dir() {
  read -p "Please provide a directory location for storing all artifacts (leave empty for default: $DEFAULT_ARTIFACTS_DIR): "
  # Use default if the user provides no input
  if [ -z "$ARTIFACTS_DIR" ]; then
    ARTIFACTS_DIR="$DEFAULT_ARTIFACTS_DIR"
    echo "No directory provided. Using default: $ARTIFACTS_DIR"
  fi
}

# Function to handle the setup process
setup() {
  # Step 1: Install prerequisites (including Go)
  echo "Step 1: Installing prerequisites (Go, dpkg-dev, gpg, tree)"
  sudo apt-get install -y golang-go dpkg-dev gpg tree
  prompt_continue "Next, we will ask you to provide a directory location to store all artifacts."

  # Prompt for the artifacts directory
  prompt_for_artifacts_dir

  # Check if directory exists, if not, create it
  if [ ! -d "$ARTIFACTS_DIR" ]; then
    echo "Directory does not exist. Creating $ARTIFACTS_DIR..."
    mkdir -p "$ARTIFACTS_DIR"
    echo "Directory $ARTIFACTS_DIR created."
  else
    echo "Directory $ARTIFACTS_DIR already exists."
  fi
  tree "$ARTIFACTS_DIR"
  prompt_continue "Next, we will create a simple Go program within the specified directory."

  # Step 2: Create Go Program
  echo "Step 2: Creating a simple Go program"
  mkdir -p "$ARTIFACTS_DIR/hello-world-program"
  cat <<EOF > "$ARTIFACTS_DIR/hello-world-program/main.go"
package main

import "fmt"

func main() {
    fmt.Println("hello statically compiled world")
}
EOF

  # Step 3: Compile the Go program statically
  echo "Step 3: Compiling the Go program statically"
  cd "$ARTIFACTS_DIR/hello-world-program"
  CGO_ENABLED=0 go build -o hello-world -ldflags="-extldflags=-static" main.go
  echo "Go program compiled as a static binary."
  tree "$ARTIFACTS_DIR"
  prompt_continue "Next, we will create the directory structure for the deb package."

  # Step 4: Create directory structure for deb package
  echo "Step 4: Creating directory structure for the deb package"
  mkdir -p "$ARTIFACTS_DIR/hello-world_0.0.1-1_arm64"
  cd "$ARTIFACTS_DIR/hello-world_0.0.1-1_arm64"
  mkdir -p usr/bin
  cp "$ARTIFACTS_DIR/hello-world-program/hello-world" usr/bin/
  echo "Binary copied to usr/bin/hello-world."
  tree "$ARTIFACTS_DIR"
  prompt_continue "Next, we will create the necessary control file for the deb package."

  # Step 5: Create DEBIAN control file
  echo "Step 5: Creating DEBIAN control file"
  mkdir -p DEBIAN
  echo "Package: hello-world
Version: 0.0.1
Maintainer: example <example@example.com>
Architecture: arm64
Homepage: http://example.com
Description: A statically compiled Go program that prints hello" > DEBIAN/control
  echo "Control file created at $ARTIFACTS_DIR/hello-world_0.0.1-1_arm64/DEBIAN/control."
  tree "$ARTIFACTS_DIR"
  prompt_continue "Next, we will build the .deb package from the files we have set up."

  # Step 6: Build the deb package
  echo "Step 6: Building the .deb package"
  cd "$ARTIFACTS_DIR"
  dpkg --build hello-world_0.0.1-1_arm64
  echo "Deb package created: hello-world_0.0.1-1_arm64.deb"
  tree "$ARTIFACTS_DIR"
  prompt_continue "Next, we will inspect the .deb package to verify its contents."

  # Step 7: Inspect the deb package
  echo "Step 7: Inspecting the .deb package"
  dpkg-deb --info hello-world_0.0.1-1_arm64.deb
  dpkg-deb --contents hello-world_0.0.1-1_arm64.deb
  prompt_continue "Next, we will set up a directory structure for hosting this package in an apt repository."

  # Step 8: Create apt repository directory structure
  echo "Step 8: Creating apt repository directory structure"
  mkdir -p "$ARTIFACTS_DIR/apt-repo/pool/main/"
  cp "$ARTIFACTS_DIR/hello-world_0.0.1-1_arm64.deb" "$ARTIFACTS_DIR/apt-repo/pool/main/"
  mkdir -p "$ARTIFACTS_DIR/apt-repo/dists/stable/main/binary-arm64"
  tree "$ARTIFACTS_DIR"
  prompt_continue "Next, we will generate the 'Packages' file, which lists the available deb packages in the repository."

  # Step 9: Generate Packages file
  echo "Step 9: Generating Packages file"
  cd "$ARTIFACTS_DIR/apt-repo"
  dpkg-scanpackages --arch arm64 pool/ > dists/stable/main/binary-arm64/Packages
  cat dists/stable/main/binary-arm64/Packages | gzip -9 > dists/stable/main/binary-arm64/Packages.gz
  tree "$ARTIFACTS_DIR"
  prompt_continue "Next, we will create a Release file, which is required by apt repositories."
  
  # Step 10: Create Release file with a bash script (with debugging logs to stderr)
  echo "Step 10: Generating Release file using bash script with detailed debugging"
  cat <<EOF > "$ARTIFACTS_DIR/generate-release.sh"
#!/bin/bash
set -e

# Enable debug output if DEBUG is set to true or 1
DEBUG="\${DEBUG:-false}"

# Debug function to print messages to stderr if DEBUG is enabled
debug_log() {
    if [[ "\$DEBUG" == "true" || "\$DEBUG" == "1" ]]; then
        echo "[DEBUG] \$1" >&2
    fi
}

# Function to handle hashing with more detailed debugging
do_hash() {
    HASH_NAME=\$1
    HASH_CMD=\$2
    echo "\${HASH_NAME}:"

    # Find all files and remove the './' prefix
    for f in \$(find . -type f); do
        f=\$(echo "\$f" | cut -c3-)

        # Skip the Release file itself
        if [ "\$f" = "Release" ]; then
            debug_log "Skipping the Release file: \$f"
            continue
        fi

        # Check file permissions and existence before hashing
        if [ -r "\$f" ]; then
            debug_log "Processing file: \$f"
            debug_log "File permissions: \$(ls -l "\$f")"
            echo " \$(\${HASH_CMD} "\$f" | cut -d' ' -f1) \$(wc -c < "\$f") \$f"
        else
            debug_log "[ERROR] Permission denied or file not readable: \$f"
            echo "[ERROR] Permission denied or file not readable: \$f" >&2
            exit 1
        fi
    done
}

# Start logging
debug_log "Generating Release file with detailed debugging..."

# Output Release file metadata
cat <<EOF2
Origin: Example Repository
Label: Example
Suite: stable
Codename: stable
Version: 1.0
Architectures: arm64
Components: main
Description: An example software repository
Date: \$(date -Ru)
EOF2

# Perform MD5, SHA1, and SHA256 hashes with debugging
do_hash "MD5Sum" "md5sum"
do_hash "SHA1" "sha1sum"
do_hash "SHA256" "sha256sum"

debug_log "Release file generation complete."
EOF

  chmod +x "$ARTIFACTS_DIR/generate-release.sh"

  cd "$ARTIFACTS_DIR/apt-repo/dists/stable"
  "$ARTIFACTS_DIR/generate-release.sh" > Release
  echo "Release file generated."
  tree "$ARTIFACTS_DIR"
  prompt_continue "Next, we will host the repository using Python's HTTP server for testing."

  # Step 11: Serve the repository using a local HTTP server
  echo "Step 11: Hosting repository with Python HTTP server"
  cd "$ARTIFACTS_DIR"
  python3 -m http.server 8000 > /dev/null 2>&1 &
  echo "HTTP server started at http://127.0.0.1:8000"
  prompt_continue "Next, we will add the local repository to the system's sources list and update apt."

  # Step 12: Add the repository to the system's sources
  echo "Step 12: Adding repository to /etc/apt/sources.list.d"
  echo "deb [arch=arm64] http://127.0.0.1:8000/apt-repo stable main" | sudo tee /etc/apt/sources.list.d/example.list
  prompt_continue "Next, we will update apt and install the 'hello-world' package from the repository."

  # Step 13: Update and install the package
  echo "Step 13: Updating apt and installing the package"
  sudo apt-get update --allow-insecure-repositories
  sudo apt-get install hello-world
  echo "Hello World package installed successfully."
}

# Function to handle the teardown process
teardown() {
  # Prompt for the artifacts directory during teardown
  prompt_for_artifacts_dir

  echo "Teardown: Cleaning up everything."

  # Kill the Python HTTP server if it's running
  if pgrep -f "python3 -m http.server" > /dev/null; then
    echo "Stopping the Python HTTP server..."
    pkill -f "python3 -m http.server"
    echo "Server stopped."
  fi

  # Check if the hello-world package is installed, and remove it safely
  if dpkg -l | grep -q "^ii  hello-world"; then
    echo "Removing the hello-world package..."
    sudo apt-get remove --purge -y hello-world
    echo "Package hello-world removed."
  else
    echo "Package hello-world is not installed, skipping removal."
  fi

  # Remove the repository from sources.list.d
  if [ -f /etc/apt/sources.list.d/example.list ]; then
    echo "Removing the repository from /etc/apt/sources.list.d..."
    sudo rm /etc/apt/sources.list.d/example.list
    echo "Repository removed."
  fi

  # Remove the artifacts directory
  if [ -d "$ARTIFACTS_DIR" ]; then
    echo "No directory provided. Using default: $ARTIFACTS_DIR"
    echo "Removing the artifacts directory: $ARTIFACTS_DIR"
    rm -rf "$ARTIFACTS_DIR"
    echo "Artifacts directory removed."
  fi

  # Clean apt cache
  echo "Cleaning apt cache..."
  sudo apt-get clean
  echo "Cleanup complete."
}

# Check for the setup or teardown argument
if [ "$1" == "setup" ]; then
  setup
elif [ "$1" == "teardown" ]; then
  teardown
else
  echo "Usage: $0 {setup|teardown}"
  exit 1
fi
