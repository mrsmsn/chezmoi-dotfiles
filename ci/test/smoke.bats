#!/usr/bin/env bats

@test "bats infrastructure works" {
    run true
    [ "$status" -eq 0 ]
}

@test "PROJECT_ROOT is mounted at /repo" {
    [ -f /repo/justfile ]
    [ -d /repo/ci/test ]
}

@test "bats can call jq / git / chezmoi installed in the image" {
    command -v jq
    command -v git
    command -v chezmoi
}
