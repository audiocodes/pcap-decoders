FROM alpine:3.20 AS pjsip
ARG VERSION_PJSIP=2.14.1

WORKDIR /pjsip
RUN wget --no-check-certificate "https://github.com/pjsip/pjproject/archive/refs/tags/${VERSION_PJSIP}.tar.gz" -O - | tar xzf - --strip-components=1
RUN sed -i 's:https:http:' /etc/apk/repositories
RUN --mount=type=cache,target=/var/cache/apk \
    apk add gcc \
      musl-dev \
      linux-headers \
      pjproject-dev
RUN gcc -c -O2 -DPJ_AUTOCONF pjsip-apps/src/samples/pcaputil.c
RUN gcc -o pcaputil pcaputil.o -lpjmedia-codec -lpjmedia-audiodev -lpjmedia -lpjlib-util -lpj

FROM alpine:3.20 AS silk

WORKDIR /silk
ARG TARGETPLATFORM
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      SILK_PLATFORM="ARM"; \
    else \
      SILK_PLATFORM="FLP"; \
    fi; \
  wget --no-check-certificate 'https://github.com/audiocodes/silk/archive/refs/heads/decoder.tar.gz' -O - | tar xzf - --strip-components=2 silk-decoder/SILK_SDK_SRC_${SILK_PLATFORM}_v1.0.9
RUN --mount=type=cache,target=/var/cache/apk \
  apk add gcc \
    g++ \
    musl-dev \
    make
RUN make -j$(nproc) decoder

FROM alpine:3.20
RUN --mount=type=cache,target=/var/cache/apk \
  apk add pjproject
COPY --from=pjsip /pjsip/pcaputil /usr/bin
COPY --from=silk /silk/decoder /usr/bin/silk-decoder
