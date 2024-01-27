#!/bin/sh

set -ue

zig build-exe -OReleaseFast -flto -fstrip -fsingle-threaded main.zig