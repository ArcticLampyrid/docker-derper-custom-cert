#!/usr/bin/env sh
curl –insecure -f -s https://$DERP_DOMAIN:$DERP_PORT/derp/probe --resolve $DERP_DOMAIN:$DERP_PORT:127.0.0.1
