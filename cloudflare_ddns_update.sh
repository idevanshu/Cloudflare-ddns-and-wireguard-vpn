#!/bin/bash

# Load configuration from environment variables
# You can find the following information in your Cloudflare dashboard:
# - ZONE_ID: Go to your domain -> Overview -> API section -> Zone ID
# - ACCOUNT_ID: Go to your profile -> API Tokens -> Your Account ID
# - AUTH_EMAIL: The email associated with your Cloudflare account
# - AUTH_KEY: Go to your profile -> API Tokens -> Global API Key (or create a new API token)

ZONE_ID="ZONE_ID"
ACCOUNT_ID="ACCOUNT_ID"
AUTH_EMAIL="AUTH_EMAIL"
AUTH_KEY="Api_Key"
RECORD_NAME="myhome.example.com"// # your domain name

# Get the current public IP address
CURRENT_IP=$(curl -s http://ipv4.icanhazip.com)

if [[ -z "$CURRENT_IP" ]]; then
    echo "Error: Unable to fetch public IP address."
    exit 1
fi

echo "Current public IP: $CURRENT_IP"

# Get the DNS record ID
RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME" \
    -H "X-Auth-Email: $AUTH_EMAIL" \
    -H "X-Auth-Key: $AUTH_KEY" \
    -H "Content-Type: application/json" | jq -r '.result[] | select(.name=="'"$RECORD_NAME"'") | .id')

if [[ -z "$RECORD_ID" ]]; then
    echo "Error: DNS record not found for $RECORD_NAME in zone $ZONE_ID."
    exit 1
fi

echo "Record ID: $RECORD_ID"

# Get the current DNS record's IP address
DNS_IP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "X-Auth-Email: $AUTH_EMAIL" \
    -H "X-Auth-Key: $AUTH_KEY" \
    -H "Content-Type: application/json" | jq -r '.result.content')

if [[ -z "$DNS_IP" ]]; then
    echo "Error: Unable to fetch the current IP address of the DNS record."
    exit 1
fi

echo "DNS record IP: $DNS_IP"

# Update the DNS record if the IP has changed
if [[ "$CURRENT_IP" != "$DNS_IP" ]]; then
    echo "IP has changed. Updating DNS record..."
    RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -H "X-Auth-Email: $AUTH_EMAIL" \
        -H "X-Auth-Key: $AUTH_KEY" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"ttl\":120,\"proxied\":false}")
    
    SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

    if [[ "$SUCCESS" == "true" ]]; then
        echo "DNS record updated successfully."
    else
        echo "Error: Failed to update DNS record."
        echo "Response: $RESPONSE"
        exit 1
    fi
else
    echo "IP has not changed. No update needed."
fi
