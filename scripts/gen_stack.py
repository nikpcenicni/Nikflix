#!/usr/bin/env python3
"""Generate docs/explore/stack.json from the repository.

The "Explore the stack" page on the docs site draws this file. Everything
except the short descriptions and categories below is read from the repo:
the Ansible inventory, the dev Terraform VM map, the Talos patches, and
every ArgoCD Application plus its values file or manifest directory.

Run from the repo root:  python3 scripts/gen_stack.py
The Pages workflow runs it before every docs build.
"""
from __future__ import annotations

import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "explore" / "stack.json"
REPO = "https://github.com/nikpcenicni/Nikflix"
DOMAIN = "lab.pcenicni.dev"

# Curated: one-line purpose and a category for each Application. A new
# Application that is not listed still appears, under "other", with the
# first line of its header comment as its description.
APPS = {
    # delivery
    "argocd": ("delivery", "GitOps controller. Manages every Application, including itself"),
    "argocd-config": ("delivery", "ArgoCD OIDC, RBAC, and metrics config"),
    "ballast": ("delivery", "Rightsizes CPU and memory requests for opted-in apps"),
    "harbor": ("delivery", "Container registry"),
    "headlamp": ("delivery", "Web UI for Kubernetes"),
    # networking
    "traefik": ("networking", "Ingress controller and TLS termination"),
    "ingress-apps": ("networking", "Ingresses for ArgoCD, authentik, Grafana, Headlamp"),
    "metallb": ("networking", "LoadBalancer IPs on bare metal"),
    "metallb-pool": ("networking", "Address pool 192.168.10.240-245"),
    "coredns": ("networking", "Resolves lab hostnames to Traefik inside the cluster"),
    "cilium": ("networking", "Staged CNI replacement for Flannel (manual sync)"),
    "wireguard": ("networking", "Remote-access VPN (wg-easy)"),
    "metrics-server": ("networking", "Kubernetes Metrics API"),
    # identity and security
    "authentik": ("security", "SSO identity provider"),
    "authentik-outpost": ("security", "Forward-auth proxy outpost"),
    "media-forward-auth": ("security", "Traefik middleware that sends requests to authentik"),
    "oidc-rbac": ("security", "RBAC for OIDC users of the Kubernetes API"),
    "cert-manager": ("security", "Issues and renews TLS certificates"),
    "cluster-issuers": ("security", "Let's Encrypt issuers (Cloudflare DNS-01)"),
    "sops-secrets-operator": ("security", "Decrypts SopsSecrets into Secrets"),
    "secrets": ("security", "SOPS-encrypted secrets"),
    "kyverno": ("security", "Admission policy engine"),
    "kyverno-policies": ("security", "Cluster policies: privileged, registries, limits"),
    "network-policies": ("security", "Default-deny NetworkPolicies per namespace"),
    # observability
    "kube-prometheus-stack": ("observability", "Prometheus and Grafana"),
    "loki": ("observability", "Log storage"),
    "alloy": ("observability", "Ships pod logs to Loki"),
    "prometheus-pve-exporter": ("observability", "Proxmox metrics"),
    # media
    "seerr": ("media", "Request portal"),
    "sonarr": ("media", "TV automation"),
    "radarr": ("media", "Movie automation"),
    "prowlarr": ("media", "Indexer manager"),
    "qbittorrent": ("media", "Torrent client behind a PIA VPN sidecar"),
    "sabnzbd": ("media", "Usenet client"),
    "bazarr": ("media", "Subtitles"),
    "profilarr": ("media", "Quality profiles for Sonarr and Radarr"),
    # household apps
    "homepage": ("apps", "Admin dashboard for every app"),
    "vikunja": ("apps", "Task manager"),
    "opengym": ("apps", "Workout tracker"),
    "spoolman": ("apps", "3D-printer filament inventory"),
    "bambuddy": ("apps", "Bambu printer manager"),
}

CATEGORIES = {
    "delivery": "Delivery",
    "networking": "Networking",
    "security": "Identity & security",
    "observability": "Observability",
    "media": "Media",
    "apps": "Apps",
    "other": "Other",
}

HOST_RE = re.compile(r"\b([a-z0-9-]+\." + re.escape(DOMAIN) + r")\b")
LB_RE = re.compile(r"metallb\.io/loadBalancerIPs:\s*([0-9.]+)")
NFS_RE = re.compile(r"server:\s*\"?([0-9.]+)\"?")
IMAGE_RE = re.compile(r"repository:\s*([\w./-]+)\s*\n\s*tag:\s*\"?([\w.\-]+)\"?")


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8") if p.exists() else ""


def strip_comments(text: str) -> str:
    """Drop YAML comments so prose in comments is not mistaken for config."""
    out = []
    for line in text.splitlines():
        if line.lstrip().startswith("#"):
            continue
        out.append(re.sub(r"\s+#\s.*$", "", line))
    return "\n".join(out) + "\n"


def first_comment(text: str) -> str:
    for line in text.splitlines():
        if line.startswith("#"):
            return line.lstrip("# ").strip()
        if line.strip():
            break
    return ""


def git_sha() -> str:
    try:
        return subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip()
    except Exception:
        return "unknown"


# ---------------------------------------------------------------- network / proxmox

def load_proxmox():
    inv = yaml.safe_load(read(ROOT / "ansible/inventory/hosts.yml"))
    gv = yaml.safe_load(read(ROOT / "ansible/inventory/group_vars/all.yml"))
    hosts = inv["all"]["children"]["noble"]["hosts"]
    nodes = []
    for i, (name, hv) in enumerate(hosts.items()):
        host_vars = yaml.safe_load(read(ROOT / f"ansible/inventory/host_vars/{name}.yml")) or {}
        nodes.append({
            "id": name,
            "mgmt_ip": hv["ansible_host"],
            "corosync_ip": host_vars.get("pve_corosync_ip"),
            "storage_ip": host_vars.get("pve_storage_ip"),
            "nic2_override": "pve_nic2_mac_override" in host_vars,
            "founder": i == 0,
            "status": "running",
            "source": "ansible/inventory/host_vars/%s.yml" % name,
        })
    # Planned nodes from the architecture doc's table.
    for line in read(ROOT / "docs/reference/architecture/proxmox.md").splitlines():
        m = re.match(r"\|\s*(\w+)\s*\|\s*\w+\s*\|\s*planned\s*\|\s*([\d.]+)\s*\|\s*([\d.]+)\s*\|\s*([\d.]+)", line)
        if m:
            nodes.append({"id": m[1], "mgmt_ip": m[2], "corosync_ip": m[3], "storage_ip": m[4],
                          "status": "planned", "source": "docs/reference/architecture/proxmox.md"})
    return {
        "cluster": gv.get("pve_cluster_name", "noble"),
        "vlans": [
            {"id": 10, "name": "Management", "subnet": "192.168.10.0/24", "nic": "nic1 / vmbr0",
             "switch": "Flex 2.5GbE #1", "carries": "Proxmox GUI/API, Talos VMs, K8s API, MetalLB"},
            {"id": gv.get("pve_storage_vlan", 80), "name": "Storage", "subnet": "192.168.80.0/24", "nic": "nic2",
             "switch": "Flex 2.5GbE #2", "carries": "Storage traffic; Longhorn later"},
            {"id": gv.get("pve_corosync_vlan", 100), "name": "Corosync", "subnet": "10.10.100.0/24", "nic": "nic0",
             "switch": "Cloud Gateway Fiber", "carries": "Proxmox cluster heartbeat (link0)"},
        ],
        "nodes": nodes,
    }


# ---------------------------------------------------------------- talos VMs

def load_vms():
    text = read(ROOT / "development/terraform/locals.tf")
    vms = []
    for m in re.finditer(r"^\s{4}([\w-]+)\s*=\s*\{(.*?)^\s{4}\}", text, re.S | re.M):
        body = m.group(2)

        def val(key):
            mm = re.search(rf"^\s*{key}\s*=\s*(.+?)\s*$", body, re.M)
            if not mm:
                return None
            raw = mm.group(1).strip().strip('"')
            if re.fullmatch(r"[\d\s*]+", raw):
                return eval(raw, {"__builtins__": {}})  # simple "6 * 1024" products only
            return {"true": True, "false": False}.get(raw, raw)

        vms.append({
            "id": m.group(1), "vmid": val("vmid"), "node": val("node"), "role": val("role"),
            "vcpu": val("vcpu"), "memory_gib": (val("memory_mib") or 0) / 1024,
            "boot_disk_gb": val("boot_disk_gb"), "data_disk_gb": val("longhorn_disk_gb"),
            "mgmt_ip": val("mgmt_ip"), "enabled": val("enabled"),
            "source": "development/terraform/locals.tf",
        })
    talos = None
    for p in sorted((ROOT / "development/talos/patches").glob("*.yaml")):
        mm = re.search(r"installer:(v[\d.]+)", read(p))
        if mm:
            talos = mm.group(1)
            break
    return vms, talos


# ---------------------------------------------------------------- applications

def load_apps():
    apps = []
    docs = []
    for f in sorted((ROOT / "argocd/dev/apps").glob("*.yaml")):
        text = read(f)
        for doc in yaml.safe_load_all(text):
            if doc and doc.get("kind") == "Application":
                docs.append((f, text, doc))
    for f, text, doc in docs:
        spec = doc.get("spec", {})
        sources = spec.get("sources") or [spec.get("source", {})]
        chart = next((s for s in sources if s.get("chart")), None)
        path_src = next((s for s in sources if s.get("path")), None)
        values_files = []
        for s in sources:
            for vf in (s.get("helm") or {}).get("valueFiles", []):
                values_files.append(vf.replace("$values/", ""))

        blob = "".join(strip_comments(read(ROOT / v)) for v in values_files)
        manifests_dir = path_src["path"] if path_src else None
        if manifests_dir:
            for mf in sorted((ROOT / manifests_dir).rglob("*.yaml")):
                if mf.stat().st_size < 400_000:
                    blob += strip_comments(read(mf))

        name = doc["metadata"]["name"]
        cat, desc = APPS.get(name, ("other", first_comment(text)))
        sync = spec.get("syncPolicy", {}) or {}
        hosts = sorted(set(HOST_RE.findall(blob))) if (chart or name == "ingress-apps") else []
        if name in ("authentik",):  # its blueprint names every app's host; keep its own
            hosts = [h for h in hosts if h.startswith("auth.")]
        if name == "harbor":
            hosts = [h for h in hosts if h.startswith("registry.")]
        if name == "homepage":
            hosts = [h for h in hosts if h.startswith("dash.")]
        if name == "kube-prometheus-stack":
            hosts = [h for h in hosts if h.startswith("grafana.")]

        storage = []
        if "local-path" in blob:
            storage.append("local-path")
        if re.search(r"type:\s*nfs", blob):
            storage.append("nfs " + ",".join(sorted(set(NFS_RE.findall(blob)))))
        images = [f"{r}:{t}" for r, t in IMAGE_RE.findall(blob)] if chart and chart.get("chart") == "app-template" else []
        apps.append({
            "id": name,
            "namespace": spec.get("destination", {}).get("namespace", ""),
            "category": cat,
            "description": desc,
            "kind": "helm" if chart else "manifests",
            "chart": chart.get("chart") if chart else None,
            "chart_repo": chart.get("repoURL") if chart else None,
            "version": str(chart.get("targetRevision")) if chart else None,
            "images": images,
            "hosts": hosts,
            "sso": ("forward-auth" if "media-authentik-forward-auth" in blob and chart else
                    "oidc" if re.search(r"oidc|generic_oauth|openid", blob, re.I) and hosts else None),
            "ballast": "ballast.tightlinesoftware.com/mode" in blob,
            "lb_ips": ["192.168.10.240"] if name == "traefik" else sorted(set(LB_RE.findall(blob))),
            "storage": storage,
            "auto_sync": bool(sync.get("automated")),
            "source": f"argocd/dev/apps/{f.name}",
            "values": values_files,
            "manifests": manifests_dir,
        })
    return apps


def main():
    proxmox = load_proxmox()
    vms, talos = load_vms()
    apps = load_apps()
    data = {
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "commit": git_sha(),
        "repo": REPO,
        "domain": DOMAIN,
        "proxmox": proxmox,
        "kubernetes": {
            "name": "dev-noble",
            "endpoint": "192.168.10.160:6443",
            "talos": talos,
            "vms": vms,
            "ingress_ip": "192.168.10.240",
        },
        "external": [
            {"id": "pihole", "name": "Pi-hole", "ip": "192.168.1.127", "role": "LAN DNS, *.%s wildcard" % DOMAIN},
            {"id": "nas", "name": "NAS (OMV)", "ip": "192.168.50.105", "role": "NFS media, torrents, usenet"},
            {"id": "macmini", "name": "Mac Mini", "ip": None, "role": "Jellyfin"},
            {"id": "cloudflare", "name": "Cloudflare", "ip": None, "role": "DNS-01 for Let's Encrypt"},
        ],
        "categories": CATEGORIES,
        "apps": apps,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(proxmox['nodes'])} nodes, {len(vms)} VMs, {len(apps)} apps")


if __name__ == "__main__":
    main()
