FROM alpine/curl AS pre-build-env
RUN echo "" > /build-info; \
    if curl -s https://www.cloudflare-cn.com/cdn-cgi/trace | grep -q 'loc=CN'; then \
        echo "build_loc=CN" >> /build-info; \
    fi

FROM golang:1.22-alpine AS build-env
COPY --from=pre-build-env /build-info /build-info
RUN if cat /build-info | grep -q 'build_loc=CN'; then \
        sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories; \
        go env -w GO111MODULE=on; \
        go env -w GOPROXY=https://goproxy.cn,direct; \
    fi;
WORKDIR /go/src
RUN apk add --no-cache git patch
ARG VERSION_BRANCH=v1.70.0
RUN if cat /build-info | grep -q 'build_loc=CN'; then \
        git clone https://ghfast.top/https://github.com/tailscale/tailscale.git --branch=$VERSION_BRANCH --depth=1; \
    else \
        git clone https://github.com/tailscale/tailscale.git --branch=$VERSION_BRANCH --depth=1; \
    fi;
WORKDIR /go/src/tailscale
ADD no_hostname_verify.patch /go/src/tailscale/no_hostname_verify.patch
RUN patch -p1 < no_hostname_verify.patch
RUN go install -v ./cmd/derper

FROM alpine:3.18
COPY --from=pre-build-env /build-info /build-info
RUN if cat /build-info | grep -q 'build_loc=CN'; then \
        sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories; \
    fi;
RUN apk add --no-cache ca-certificates iptables iproute2 ip6tables curl && mkdir -p /app/certs
COPY --from=build-env /go/bin/* /usr/local/bin/
ADD derper-health-check.sh /usr/local/bin/derper-health-check.sh
ENV DERP_DOMAIN your-hostname.com
ENV DERP_CERT_MODE letsencrypt
ENV DERP_CERT_DIR /app/certs
ENV DERP_PORT 443
ENV DERP_STUN true
ENV DERP_STUN_PORT 3478
ENV DERP_HTTP_PORT 80
ENV DERP_VERIFY_CLIENTS false
ENV DERP_VERIFY_CLIENT_URL ""
ENTRYPOINT /usr/local/bin/derper \
    --hostname=$DERP_DOMAIN \
    --certmode=$DERP_CERT_MODE \
    --certdir=$DERP_CERT_DIR \
    --a=:$DERP_PORT \
    --stun=$DERP_STUN  \
    --stun-port=$DERP_STUN_PORT \
    --http-port=$DERP_HTTP_PORT \
    --verify-clients=$DERP_VERIFY_CLIENTS \
    --verify-client-url=$DERP_VERIFY_CLIENT_URL
HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 CMD [ "/usr/local/bin/derper-health-check.sh" ]
