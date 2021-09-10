#!/bin/sh

WHITE="\\033[1;37m"
GREEN="\\033[0;32m"
YELLOW="\\033[0;33m"
RED="\\033[0;31m"
PURPLE="\\033[0;35m"
SET="\\033[0m\\n"

normal() {
    printf "%s\n" "$1"
}

white() {
    printf "$WHITE%s$SET" "$1"
}

green() {
    printf "$GREEN%s$SET" "$1"
}

yellow() {
    printf "$YELLOW%s$SET" "$1"
}

red() {
    printf "$RED%s$SET" "$1"
}

purple() {
    printf "$PURPLE%s$SET" "$1"
}

die() {
    red "$1" && exit 1
}

succeed() {
    green "$1" && exit 0
}
