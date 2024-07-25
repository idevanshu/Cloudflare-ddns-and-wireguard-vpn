<h2>Overview</h2>
<strong>
    This project aims to provide a reliable solution for accessing your home network securely, even if your Internet Service Provider (ISP) assigns a dynamic IP address. 
    By combining Cloudflare's Dynamic DNS (DDNS) service with WireGuard VPN, you can ensure constant and secure remote access to your network.
</strong>

<h2>Key Features</h2>
<ul>
    <li><strong>Dynamic DNS with Cloudflare:</strong> Automatically update your Cloudflare DNS records whenever your public IP address changes, ensuring that your domain always points to your home network.</li>
    <li><strong>Secure Remote Access with WireGuard:</strong> Set up a WireGuard VPN server on your home network, allowing you to connect securely from anywhere in the world.</li>
</ul>

<h2>How It Works</h2>

<h3>Cloudflare DDNS Setup</h3>
<ol>
    <li><strong>Script Execution:</strong> A script periodically checks your public IP address.</li>
    <li><strong>IP Change Detection:</strong> If the IP address has changed, the script updates your Cloudflare DNS records to point to the new IP.</li>
    <li><strong>Consistent Domain Resolution:</strong> This ensures that your domain (e.g., <code>myhome.example.com</code>) always resolves to your current public IP address.</li>
</ol>

<h3>WireGuard VPN Setup</h3>
<ol>
    <li><strong>Install WireGuard:</strong> Install WireGuard on your home server.</li>
    <li><strong>Configuration:</strong> Configure WireGuard to allow remote access to your home network by setting up port forwarding on your router or firewall. 
      Forward traffic from the external port 51820 to the WireGuard port on your home server. 
      If you’ve changed the default port from 51820, make sure to forward the correct port. Otherwise, use the default port.</li>
    <li><strong>Domain Connection:</strong> Use the domain name managed by Cloudflare DDNS to connect to your WireGuard server, ensuring you can always access your network even if the IP changes.</li>
</ol>

<h2>Benefits</h2>
<ul>
    <li><strong>Consistent Access:</strong> Your domain always points to your current public IP, eliminating the hassle of manually updating DNS records.</li>
    <li><strong>Enhanced Security:</strong> WireGuard VPN provides a secure tunnel for your data, protecting your network from unauthorized access.</li>
    <li><strong>Easy Configuration:</strong> Simple scripts automate the process of IP address updates and VPN configuration, making it easy to set up and maintain.</li>
</ul>

<h2>Get Started</h2>

<h3>Prerequisites</h3>
<ul>
    <li>A Cloudflare account</li>
    <li>A registered domain with Cloudflare</li>
    <li>A device that can run linux</li>
    <li><code>curl</code>, <code>jq</code>, <code>bash</code> and <code> docker </code> installed on your device</li>
</ul>

<pre><code>sudo apt update sudo apt install curl jq bash docker.io -y
# Install docker-compose 
sudo curl -L "https://github.com/docker/compose/releases/download/v2.17.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
</pre></code> 

<h2>Setup Instructions</h2>

<h3>1. Schedule the DDNS Update Script</h3>
# Load configuration from environment variables <br>
# You can find the following information in your Cloudflare dashboard: <br>
# - ZONE_ID: Go to your domain -> Overview -> API section -> Zone ID <br>
# - ACCOUNT_ID: Go to your profile -> API Tokens -> Your Account ID <br>
# - AUTH_EMAIL: The email associated with your Cloudflare account <br>
# - AUTH_KEY: Go to your profile -> API Tokens -> Global API Key (or create a new API token)

<h4>Run this: <code>nano cloudflare_ddns_update.sh</code></h4>
<h4>Paste the following code into the file:</h4>
<pre><code>
ZONE_ID="ZONE_ID"
ACCOUNT_ID="ACCOUNT_ID"
AUTH_EMAIL="AUTH_EMAIL"
AUTH_KEY="Api_Key"
RECORD_NAME="myhome.example.com"// # your domain name

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
</code></pre>

<h3>2. To ensure your Cloudflare DNS records are updated periodically, add a cron job:</h3>
<pre><code>crontab -e</code></pre>
<p>Add the following line to run the script every 2 minutes:</p>
<pre><code>*/2 * * * * /path/to/cloudflare_ddns_update.sh</code></pre>
<p>Run the script:</p>
<pre><code>chmod +x update_cloudflare_dns.sh
./update_cloudflare_dns.sh
</code></pre>

<h3>3. Setup WireGuard with Docker</h3>
<p>Create a <code>docker-compose.yml</code> file with the following content:</p>
<pre><code>services:
  wireguard:
    image: lscr.io/linuxserver/wireguard:latest 
    container_name: wireguard 
    cap_add:
      - NET_ADMIN 
      - SYS_MODULE 
    environment:
      - PUID=1000 
      - PGID=1000 
      - TZ=Asia/Kolkata # Set timezone
      - SERVERURL=<DOMAIN_NAME> # Domain name pointing to Cloudflare
      - SERVERPORT=51820 # Optional: Set server port (default 51820)
      - PEERS=peer1,peer2 # Optional: Define peers
      - PEERDNS=1.1.1.2,1.0.0.2 # Use Cloudflare DNS servers
      - ALLOWEDIPS=0.0.0.0/0 # Allow all IPs
    volumes:
      - /path/to/config:/config # Mount config directory
      - /lib/modules:/lib/modules # Optional: Mount modules directory
    ports:
      - 51820:51820/udp # Map UDP port 51820
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1 # Required sysctl setting
    restart: unless-stopped # Restart the container unless it is stopped manually
</code></pre>

<h3>4. Run the Docker Container</h3>
<p>Navigate to the directory containing the <code>docker-compose.yml</code> file and run:</p>
<pre><code>docker-compose up -d</code></pre>

<h3> Navigate to the Configuration Directory </h3>
<h4><pre><code>cd ./config/peer_peer1</code></pre></h4>

<ul>
  <li><strong>For Smartphones:</strong> Scan the QR code provided in the PNG file.</li>
  <li><strong>For Windows, macOS, and Linux Systems:</strong> Use the <code>peer1.conf</code> configuration file to establish the connection.</li>
  <li><strong>For OpenWrt, DD-WRT Routers, or pfSense:</strong> Use the public and private keys to configure the connection.</li>
</ul>

<h4> If the VPN is not running, check that you have set up port forwarding on your router.
 Make sure traffic is forwarded to port 51820 (the default). 
 If you have changed the port, update the forwarding rule to match your new port. 
</h4>

