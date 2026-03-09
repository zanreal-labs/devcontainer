#!/bin/bash
set -e

echo "Installing Supabase CLI..."

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; elif [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi

curl -fsSL "https://github.com/supabase/cli/releases/latest/download/supabase_linux_${ARCH}.tar.gz" -o /tmp/supabase.tar.gz
tar -xzf /tmp/supabase.tar.gz -C /usr/local/bin supabase
rm /tmp/supabase.tar.gz

echo "Supabase CLI installed: $(supabase --version)"
