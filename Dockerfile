# Use Debian slim for build to generate wheels compatible with glibc runtime
FROM python:3.11-slim AS base

# Tools needed for building wheels
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    python3-pip \
    python3-venv \
    libffi-dev \
    libyaml-dev \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

FROM base AS build
WORKDIR /src/prometheus-pve-exporter
ADD . /src/prometheus-pve-exporter
# build wheels (same behaviour as original)
RUN python3 -m pip wheel -w dist --no-binary "cffi" --no-binary "pyyaml" -r requirements.txt && \
    python3 -m build .

# Runtime: use the same slim image (glibc) and install wheel
FROM python:3.11-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    python3-venv \
    python3-pip \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/prometheus-pve-exporter/dist /src/prometheus-pve-exporter/dist

RUN python3 -m venv /opt/prometheus-pve-exporter && \
    /opt/prometheus-pve-exporter/bin/pip install /src/prometheus-pve-exporter/dist/*.whl && \
    ln -s /opt/prometheus-pve-exporter/bin/pve_exporter /usr/bin/pve_exporter && \
    rm -rf /src/prometheus-pve-exporter /root/.cache

RUN groupadd -g 101 prometheus && \
    useradd -u 101 -g 101 -M -s /sbin/nologin prometheus

USER prometheus
EXPOSE 9221
ENTRYPOINT [ "/opt/prometheus-pve-exporter/bin/pve_exporter" ]
