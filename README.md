# Dokcer Derper with Custom Cert Supported
Derper (DERP Server) is a server that acts as a relay for Tailscale traffic. It is used to relay traffic between two nodes that cannot communicate directly. This is useful when you have a node behind a NAT or firewall that cannot accept incoming connections.

This is a docker image for a patched version of derper that allows you to use a custom cert that does not match the hostname. This is useful when you want to use a cert for a different domain than the hostname, or when you want to avoid SNI field for privacy reasons.

## Features
- Alpine based image, lightweight and secure.
- Patched derper to allow you use a cert that does not match the hostname.
- Patched derper to disable SNI verification, allowing pure-IP-based connections.
- Healthcheck support.

## Setup
Use the following `docker-compose.yml` to run the container. 

```yaml
services:
  derper:
    container_name: tailscale-derper
    restart: always
    build:
      context: https://github.com/ArcticLampyrid/docker-derper-custom-cert.git#main
      args:
        # Set the version of the source tree to use.
        # It is recommended to use the default value to make sure the patch is compatible.
        # - VERSION_BRANCH=v1.70.0
    network_mode: "host"
    environment:
      - DERP_DOMAIN=your-hostname.com # Server hostname
      - DERP_CERT_DIR=/app/certs # Directory to store certs
      - DERP_CERT_MODE=letsencrypt # How to get a cert, possible options: manual, letsencrypt (for port = 443)
      - DERP_PORT=443 # Server port
      - DERP_STUN=true # also run a STUN server
      - DERP_STUN_PORT=3478 # The UDP port on which to serve STUN
      - DERP_HTTP_PORT=80 # The port on which to serve HTTP. Set to -1 to disable
      - DERP_VERIFY_CLIENTS=false # Verify clients to this DERP server through a local tailscaled instance
      - DERP_VERIFY_CLIENT_URL="" # If non-empty, an admission controller URL for permitting client connections
    volumes:
      - /home/foo/derp/certs:/app/certs
      - /home/foo/derp/data:/var/lib/derper
      # Uncomment if you want to use DERP_VERIFY_CLIENTS
      # - /var/run/tailscale/tailscaled.sock:/var/run/tailscale/tailscaled.sock 
```

## Set Custom Certs
> [!WARNING]  
> This is not officially supported by Tailscale, and has little possibility of being merged into the mainline \(see [here](https://github.com/tailscale/tailscale/issues/11776#issuecomment-2116523542)\).  
> Use at your own risk, it may break in the future.
 

If you want to use custom certs, you can mount the certs to the container, name the file as `<hostname>.crt` and `<hostname>.key`, and then set cert mode to `manual`.

The derper is patched to disable SNI verification and cert name verification. This is useful if you want to use a cert that does not match the hostname.

For example, if you want to use a cert for `cert.com` on `hostname.com`, you can just copy the cert under `hostname.com.crt` and `hostname.com.key` to the `DERP_CERT_DIR` directory, and then config DERPMap as follows:

```yaml
# This is in the format which Headscale uses, if you are using other controller, please refer to the controller's documentation.
regions:
 900:
   regionid: 900
   regioncode: "homelab"
   regionname: "HomeLab"
   nodes:
     - name: 'homelab'
       regionid: 900
       hostname: 'hostname.com'
       # CertName optionally specifies the expected TLS cert common name.
       # If CertName is non-empty, HostName is only used for the TCP
       # dial (if IPv4/IPv6 are not present) + TLS ClientHello.
       certname: 'cert.com'
       ipv4: '1.2.3.4'
       ipv6: '::a:b:c:d'
       stunport: 3478
       stunonly: false
       derpport: 443
       canport80: true
```

And for a pure-IPv4-based connection: 

```yaml
regions:
 900:
   regionid: 900
   regioncode: "homelab"
   regionname: "HomeLab"
   nodes:
     - name: 'homelab'
       regionid: 900
       hostname: '1.2.3.4'
       certname: 'cert.com'
       ipv4: '1.2.3.4'
       # Use 'none' to disable IPv6
       ipv6: 'none'
       stunport: 3478
       stunonly: false
       derpport: 443
       canport80: true
```

## Check if it works
If you has set up the DERPMap correctly, you can check if it works by running the following command on any Tailscale node:

```bash
tailscale debug derp $regionid
```

## Acknowledgement
- https://github.com/fredliang44/derper-docker
