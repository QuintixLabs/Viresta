#!/usr/bin/env bash

# firefox.sh
# Installs the Firefox policies.

install_firefox_policy() {
    sudo_install_file "$CONFIG_SOURCE_DIR/firefox/policies.json" "$FIREFOX_POLICY_FILE"
}
