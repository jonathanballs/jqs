# NB: I had weird issues getting this to run on my machine due to an issue with
# arm64. I have used a custom elixir image here but usually I would just use 
# the normal elixir images.
# See: https://elixirforum.com/t/crash-dump-when-installing-phoenix-on-mac-m2-eheap-alloc-cannot-allocate-x-bytes-of-memory-of-type-heap-frag/62154/11
FROM hexpm/elixir:1.16.2-erlang-25.0.4-ubuntu-noble-20240225

RUN apt update \
  && apt upgrade -y \
  && apt install -y bash curl git build-essential

WORKDIR /app

COPY . .

# Get dependencies
RUN mix archive.install github hexpm/hex branch latest
RUN mix deps.get
RUN mix compile

# Start phoenix server by default
CMD mix phx.server

