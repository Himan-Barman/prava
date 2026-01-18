FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    git \
    pkg-config \
    libssl-dev \
    libjsoncpp-dev \
    uuid-dev \
    zlib1g-dev \
    libpq-dev \
    libhiredis-dev \
  && update-ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
  && cmake --build build --config Release -j$(nproc)

EXPOSE 3000 3001
CMD ["./build/prava_backend_cpp"]
