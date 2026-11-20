FROM ubuntu:24.04
ARG GODOT_VERSION=4.7.2
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends wget unzip ca-certificates libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo arm64 || echo x86_64) \
    && wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.${ARCH}.zip" -O /tmp/g.zip \
    && unzip -q /tmp/g.zip -d /tmp && mv /tmp/Godot_v${GODOT_VERSION}-stable_linux.${ARCH} /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot && rm /tmp/g.zip
WORKDIR /w
COPY . /w
RUN godot --headless --path /w --import >/dev/null 2>&1 || true
