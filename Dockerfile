FROM alpine:3.18.4 AS base

RUN apk add --no-cache \
    build-base \
    busybox-static

FROM base AS su-exec

ARG SU_EXEC_VERSION=0.2

WORKDIR /build
RUN wget -O "/build/su-exec-${SU_EXEC_VERSION}.tar.gz" "https://github.com/ncopa/su-exec/archive/refs/tags/v${SU_EXEC_VERSION}.tar.gz" && \
    tar -xf "/build/su-exec-${SU_EXEC_VERSION}.tar.gz"

WORKDIR "/build/su-exec-${SU_EXEC_VERSION}"
RUN make -j "$(nproc --all)" su-exec-static && \
    install -D su-exec-static /install/bin/su-exec && \
    strip /install/bin/su-exec

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
COPY --from=su-exec --chmod=700 /install/bin/su-exec /sbin/su-exec
COPY --from=tini --chmod=700 /install/bin/tini-static /sbin/tini

COPY --from=base /bin/busybox.static /busybox
RUN [ "/busybox", "touch", "/etc/group", "/etc/passwd" ]
RUN [ "/busybox", "addgroup", "-g", "65534", "nogroup" ]
RUN [ "/busybox", "adduser", "-D", "-G", "nogroup", "-g", "", "-h", "/app", "-s", "/bin/false", "-u", "65534", "nobody" ]
RUN [ "/busybox", "rm", "/busybox", "/etc/group-", "/etc/passwd-" ]

EXPOSE 8080
WORKDIR /app

ENTRYPOINT [ "tini", "-g", "-s", "-v", "--", "su-exec", "nobody:nogroup" ]
