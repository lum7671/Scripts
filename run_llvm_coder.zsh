#!/usr/bin/env zsh

llama-server \
    -hf ggml-org/Qwen2.5-Coder-3B-Q8_0-GGUF \
    --port 8012 -ngl 99 -fa -ub 1024 -b 1024 -dt 0.1 \
    --ctx-size 0 --cache-reuse 256 &
