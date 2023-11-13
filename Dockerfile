FROM alpine:3.18.4 AS base

RUN apk add --no-cache \
    build-base \
    busybox-static

FROM base AS tini

RUN apk add --no-cache \
    cmake

ARG TINI_VERSION=0.19.0

WORKDIR /
RUN wget -O "/tini-${TINI_VERSION}.tar.gz" "https://github.com/krallin/tini/archive/refs/tags/v${TINI_VERSION}.tar.gz" && \
    tar -xf "/tini-${TINI_VERSION}.tar.gz"

WORKDIR /build
RUN cmake -DCMAKE_INSTALL_PREFIX=/ "/tini-${TINI_VERSION}" && \
    make -j "$(nproc --all)" DESTDIR=/install install && \
    strip /install/bin/tini-static

FROM scratch

COPY --from=base /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=tini /install/bin/tini-static /sbin/tini

COPY --from=base /bin/busybox.static /busybox
RUN [ "/busybox", "touch", "/etc/group", "/etc/passwd" ]
RUN [ "/busybox", "addgroup", "-g", "65534", "nobody" ]
RUN [ "/busybox", "rm", "/etc/group-" ]
RUN [ "/busybox", "adduser", "-D", "-G", "nobody", "-H", "-g", "", "-h", "/", "-s", "/bin/false", "-u", "65534", "nobody" ]
RUN [ "/busybox", "rm", "/etc/passwd-" ]
RUN [ "/busybox", "mkdir", "-p", "/app" ]
RUN [ "/busybox", "chown", "-R", "nobody:nobody", "/app" ]
RUN [ "/busybox", "rm", "/busybox" ]

EXPOSE 8080
USER nobody
WORKDIR /app

ENTRYPOINT [ "tini", "-g", "-s", "-v", "--" ]
