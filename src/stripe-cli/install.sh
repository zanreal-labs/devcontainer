#!/bin/bash
set -e

echo "Installing Stripe CLI..."

curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | gpg --dearmor -o /usr/share/keyrings/stripe.gpg
echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" > /etc/apt/sources.list.d/stripe.list
apt-get update
apt-get install -y stripe
rm -rf /var/lib/apt/lists/*

echo "Stripe CLI installed: $(stripe version)"
