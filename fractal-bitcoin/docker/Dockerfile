# fractal-bitcoin/docker/Dockerfile
FROM debian:stable-slim AS build

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y git build-essential cmake pkgconf python3 \
    libboost-all-dev libssl-dev libzmq3-dev libsqlite3-dev

# Clone Fractal Bitcoin (using their specific branch/tag)
RUN git clone https://github.com/fractal-bitcoin/fractal.git /fractal-git

WORKDIR /fractal-git
RUN cmake -B build -DWITH_ZMQ=ON
RUN cmake --build build
RUN strip /fractal-git/build/bin/bitcoind
RUN strip /fractal-git/build/bin/bitcoin-cli

FROM debian:stable-slim
COPY --from=build /fractal-git/build/bin/bitcoind /usr/bin/
COPY --from=build /fractal-git/build/bin/bitcoin-cli /usr/bin/

RUN apt-get update && apt-get install -y libzmq3-dev libsqlite3-dev libevent-dev

EXPOSE 8434 8435
VOLUME /data
WORKDIR /data

CMD ["bitcoind", "-datadir=/data"]