# Custom Eclipse Che workspace image with the Claude Code CLI pre-installed.
#
# Built/pushed per ../../../../.github/workflows/build-claude-code-workspace-image.yml
# (proposed - see that file's header comment). Referenced by
# ../../devworkspace.yaml's spec.template.components[].container.image.
#
# node:22-slim, not node:20-slim: the @anthropic-ai/claude-code npm package's
# package.json declares "engines": {"node": ">=22.0.0"}, and Anthropic's own
# docs (code.claude.com/docs, checked 2026-07-29) confirm that as of Claude
# Code v2.1.198 the npm install requires Node.js 22+. Below that, npm prints
# an EBADENGINE warning but still installs a native binary that runs fine -
# we pin to 22+ anyway to stay on the supported path.
FROM node:22-slim

# git/curl/ripgrep/procps: tools Claude Code's own Bash/Read/Grep-equivalent
# tools expect to find on PATH; ca-certificates for TLS to the Anthropic API
# and to git remotes. node:22-slim ships without any of these.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        procps \
        ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Official install method per code.claude.com/docs/en/setup and the package's
# own README - a straight global npm install of @anthropic-ai/claude-code.
RUN npm install -g @anthropic-ai/claude-code

# Eclipse Che (che-operator 7.120.0 / devworkspace-operator v0.41.0, per
# ../../../../argocd/dev/manifests/che-cluster/checluster.yaml's header)
# auto-persists a workspace container's entire home directory across
# restarts via devEnvironments.persistUserHome - CRD-defaulted to
# `enabled: true` (confirmed in che-operator 7.120.0's structural schema,
# config/crd/bases/org.eclipse.che_checlusters.yaml, even though checluster.yaml
# doesn't set the field explicitly) - together with
# devEnvironments.storage.pvcStrategy's own `per-user` default. That
# mechanism mounts a per-user PVC at a HARDCODED path, not a configurable
# one: devworkspace-operator v0.41.0's pkg/constants/constants.go defines
# HomeUserDirectory = "/home/user/", and
# controllers/workspace/devworkspace_controller.go unconditionally calls
# pkg/library/home/persistentHome.go's AddPersistentHomeVolume for every
# DevWorkspace that has at least one container component and doesn't already
# mount something at that exact path - no opt-in label/attribute needed on
# the DevWorkspace side.
#
# node:22-slim's built-in "node" user (HOME=/home/node) does NOT qualify, so
# this replaces it with a "user" account at /home/user to ride on that
# mechanism instead of a hand-rolled PVC + controller.devfile.io/mount-to-
# devworkspace automount label (development/eclipse-che/pvc.yaml's previous
# approach, since removed - see ../../devworkspace.yaml's header for that
# history).
#
# UID/GID: devworkspace-operator v0.41.0's own default PodSecurityContext on
# plain Kubernetes (not OpenShift) - applied here because checluster.yaml
# sets no devEnvironments.security override - is RunAsUser: 1234,
# RunAsGroup: 0, RunAsNonRoot: true, FSGroup: 1234 (pkg/config/defaults.go).
# Kubernetes' pod-level securityContext always overrides whatever USER a
# container image declares, so this UID/GID applies to the running process
# regardless of what's built into the image. Creating the account at that
# same uid/gid here is purely so /etc/passwd resolves it by name (whoami,
# bash's prompt, `id`) instead of leaving getpwuid(1234) unresolved - nothing
# in this image actually *requires* it: Claude Code/npm/git/bash all consult
# $HOME (set explicitly below), not the passwd database, for locating the
# home directory, so this stays correct even if a future checluster.yaml
# override changes the runtime UID away from 1234. `chmod g=u` on the home
# directory is the standard "arbitrary UID, GID 0" compatibility pattern
# (belt-and-suspenders alongside FSGroup: 1234, which the kubelet applies to
# the mounted PVC itself at runtime) in case that override ever happens.
RUN useradd --create-home --uid 1234 --gid 0 --home-dir /home/user --shell /bin/bash user \
    && chmod g=u /home/user

USER user
WORKDIR /home/user
ENV HOME=/home/user

# Eclipse Che/devworkspace-operator expects a container that stays running
# for interactive terminal access, not a server process it waits on - see
# devworkspace-operator samples/plain.yaml, which uses this same command.
# ../devworkspace.yaml sets this explicitly too (component.container.command),
# so this CMD is really just a sane default for `docker run` on its own.
CMD ["tail", "-f", "/dev/null"]
