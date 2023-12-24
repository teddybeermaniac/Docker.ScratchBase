FROM alpine:3.19.0 AS base

RUN apk add --no-cache \
    build-base \
    busybox-static

FROM base AS nologin

WORKDIR /build
COPY nologin.c /build/nologin.c
RUN mkdir -p /install/sbin && \
    gcc -o /install/sbin/nologin -static nologin.c && \
    strip /install/sbin/nologin

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
COPY --from=nologin /install/sbin/nologin /sbin/nologin
COPY --from=su-exec --chmod=700 /install/bin/su-exec /sbin/su-exec
COPY --from=tini --chmod=700 /install/bin/tini-static /sbin/tini

RUN --mount=from=base,source=/bin/busybox.static,target=/bin/busybox \
    --mount=from=base,source=/bin/busybox.static,target=/bin/sh \
    busybox mkdir -p /app /etc && \
    busybox touch /etc/group /etc/passwd && \
    busybox addgroup -g 65534 nobody && \
    busybox adduser -D -G nobody -H -g '' -h / -s /sbin/nologin -u 65534 nobody && \
    busybox rm /etc/group- /etc/passwd-

EXPOSE 8080
WORKDIR /app

ENTRYPOINT [ "tini", "-g", "-s", "-v", "--", "su-exec", "nobody:nobody" ]
