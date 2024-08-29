FROM alpine:3.20 AS pjsip-build

RUN apk add --update-cache \
      alpine-conf \
      alpine-sdk \
      sudo \
      ccache \
    && apk upgrade -a \
    && setup-apkcache /var/cache/apk

RUN adduser -D builder \
    && addgroup builder abuild \
    && echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER builder
WORKDIR /home/builder
RUN mkdir -p .abuild packages
RUN echo $'export JOBS=$(nproc)\n\
export MAKEFLAGS=-j$JOBS\n\
' > .abuild/abuild.conf
RUN abuild-keygen -n -a
USER root
RUN install -d -m 775 -g abuild /var/cache/distfiles
RUN cp -v .abuild/*.rsa.pub /etc/apk/keys/
RUN apk -U upgrade -a
USER builder

WORKDIR /home/builder/pjproject
COPY APKBUILD.pjproject APKBUILD
RUN abuild -rK

FROM pjsip-build AS pjsip
ARG VERSION_PJSIP=2.14.1
WORKDIR /home/builder/pjproject/src/pjproject-${VERSION_PJSIP}
COPY *.patch .
RUN for patch in *.patch; do patch -p1 < $patch; done
RUN make -j$(nproc) -C pjsip-apps/build

FROM alpine:3.20 AS silk

WORKDIR /silk
ARG TARGETPLATFORM
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      SILK_PLATFORM="ARM"; \
    else \
      SILK_PLATFORM="FLP"; \
    fi; \
  wget 'https://github.com/audiocodes/silk/archive/refs/heads/decoder.tar.gz' -O - | tar xzf - --strip-components=2 silk-decoder/SILK_SDK_SRC_${SILK_PLATFORM}_v1.0.9
RUN --mount=type=cache,target=/var/cache/apk \
  apk add gcc \
    g++ \
    musl-dev \
    make
RUN make -j$(nproc) decoder

FROM alpine:3.20
ARG VERSION_PJSIP=2.14.1
RUN --mount=type=cache,target=/var/cache/apk --mount=type=bind,from=pjsip,source=/home/builder/packages/builder,target=/pkg \
  apk add --allow-untrusted /pkg/$(uname -m)/pjproject-${VERSION_PJSIP}*.apk
COPY --from=pjsip /home/builder/pjproject/src/pjproject-${VERSION_PJSIP}/pjsip-apps/bin/samples/*/pcaputil /usr/bin
COPY --from=silk /silk/decoder /usr/bin/silk-decoder
