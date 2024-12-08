FROM debian:bookworm-slim AS base-build
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    wget

FROM base-build AS pjsip
RUN apt-get install -y --no-install-recommends \
    libbcg729-dev \
    libgsm1-dev \
    libopencore-amrnb-dev \
    libopencore-amrwb-dev \
    libopus-dev \
    libpcap-dev \
    libsamplerate0-dev \
    libsrtp2-dev \
    libssl-dev \
    libvo-amrwbenc-dev

WORKDIR /pjsip
ARG VERSION_PJSIP=2.15
RUN wget "https://github.com/pjsip/pjproject/archive/refs/tags/${VERSION_PJSIP}.tar.gz" -O - | tar xzf - --strip-components=1
RUN ./configure --disable-shared \
  --enable-libsamplerate \
  --with-external-gsm \
  --with-external-srtp \
  --disable-libwebrtc \
  && make -j$(nproc) \
  && strip pjsip-apps/bin/samples/*/pcaputil

FROM base-build AS silk
WORKDIR /silk
ARG TARGETPLATFORM
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      SILK_PLATFORM="ARM"; \
    else \
      SILK_PLATFORM="FLP"; \
    fi; \
  wget 'https://github.com/audiocodes/silk/archive/refs/heads/decoder.tar.gz' -O - | tar xzf - --strip-components=2 silk-decoder/SILK_SDK_SRC_${SILK_PLATFORM}_v1.0.9
RUN make -j$(nproc) decoder

FROM debian:bookworm-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  libbcg729-0 \
  libgsm1 \
  libopencore-amrnb0 \
  libopencore-amrwb0 \
  libopus0 \
  libpcap0.8 \
  libsamplerate0 \
  libsrtp2-1 \
  libssl3 \
  libvo-amrwbenc0 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=pjsip /pjsip/pjsip-apps/bin/samples/*/pcaputil /usr/bin
COPY --from=silk /silk/decoder /usr/bin/silk-decoder
