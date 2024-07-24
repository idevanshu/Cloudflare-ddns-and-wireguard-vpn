#!/bin/bash

# Load configuration from environment variables
# You can find the following information in your Cloudflare dashboard:
# - ZONE_ID: Go to your domain -> Overview -> API section -> Zone ID
# - ACCOUNT_ID: Go to your profile -> API Tokens -> Your Account ID
# - AUTH_EMAIL: The email associated with your Cloudflare account
# - AUTH_KEY: Go to your profile -> API Tokens -> Global API Key (or create a new API token)

ZONE_ID=${ZONE_ID}
ACCOUNT_ID=${ACCOUNT_ID}
AUTH_EMAIL=${AUTH_EMAIL}
AUTH_KEY=${AUTH_KEY}
RECORD_NAME="example.com"// # your domain name

# Get the current public IP address
CURRENT_IP=$(curl -s http://ipv4.icanhazip.com)

# Get the DNS record ID
RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME" \
    -H "X-Auth-Email: $AUTH_EMAIL" \
    -H "X-Auth-Key: $AUTH_KEY" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

# Get the current DNS record's IP address
DNS_IP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "X-Auth-Email: $AUTH_EMAIL" \
    -H "X-Auth-Key: $AUTH_KEY" \
    -H "Content-Type: application/json" | jq -r '.result.content')

# Update the DNS record if the IP has changed
if [ "$CURRENT_IP" != "$DNS_IP" ]; then
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -H "X-Auth-Email: $AUTH_EMAIL" \
        -H "X-Auth-Key: $AUTH_KEY" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"ttl\":120,\"proxied\":false}" \
        | jq
fi

