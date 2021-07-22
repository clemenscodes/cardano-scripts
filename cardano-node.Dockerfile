FROM ubuntu:20.04
COPY . .
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y man-db
RUN yes | unminimize
RUN yes | src/install_latest_node.sh
