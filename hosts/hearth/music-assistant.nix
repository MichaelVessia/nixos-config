{
  config,
  lib,
  pkgs,
  ...
}: let
  hostIp = config.homelab.hostIp;
  haIp = config.homelab.homeassistant.guestIp;
  apiPort = toString config.homelab.topology.services.musicAssistant.port;
  lan = "192.168.1.0/24";
  iot = "192.168.4.0/24";
  onkyoIp = "192.168.4.95";
  container = "homelab-music-assistant";
  docker = lib.getExe config.virtualisation.docker.package;
  nft = lib.getExe pkgs.nftables;
  mark = "0x10000000";
in {
  networking.firewall.extraCommands = ''
    # Filter before Tailscale's INPUT chain, which accepts tailnet traffic.
    ${nft} -f - <<EOF
    destroy table inet music_assistant_api
    table inet music_assistant_api {
      chain input {
        type filter hook input priority mangle; policy accept;
        iifname "lo" accept
        iifname "ha-host0" ip saddr ${haIp} ip daddr ${hostIp} tcp dport ${apiPort} accept
        tcp dport ${apiPort} counter drop
      }
    }
    EOF
    iptables -w -A nixos-fw -i ha-host0 -s ${haIp} -d ${hostIp} -p tcp --dport ${apiPort} -j nixos-fw-accept
    iptables -w -A nixos-fw -i eno1 -s ${lan} -p udp --dport 5353 -j nixos-fw-accept
    iptables -w -A nixos-fw -i eno1 -s ${lan},${iot} -d ${hostIp} -p tcp --dport 8097 -j nixos-fw-accept
    iptables -w -A nixos-fw -i eno1 -s ${lan} -d ${hostIp} -m mark --mark ${mark}/${mark} -j nixos-fw-accept
    iptables -w -A nixos-fw -i eno1 -s ${onkyoIp} -d ${hostIp} -p udp -m mark --mark ${mark}/${mark} -j nixos-fw-accept
  '';

  systemd.services.music-assistant-firewall = {
    description = "Allow discovery and AirPlay timing traffic to Music Assistant sockets";
    wantedBy = ["multi-user.target"];
    after = ["docker.service"];
    requires = ["docker.service"];
    partOf = ["docker.service"];
    serviceConfig = {
      Restart = "always";
      RestartSec = "2s";
      ExecStopPost = "${nft} destroy table inet music_assistant";
    };
    script = ''
      refresh_rules() {
        local id scope
        id=$(${docker} inspect --type container -f '{{if and .State.Running (eq .HostConfig.NetworkMode "host")}}{{.Id}}{{end}}' ${container} 2>/dev/null) || id=
        if [[ -z "$id" ]]; then
          ${nft} destroy table inet music_assistant
          return
        fi

        scope="system.slice/docker-$id.scope"
        # Soloist and SSDP use OS-assigned ports. Match the container's sockets.
        ${nft} -f - <<EOF
      destroy table inet music_assistant
      table inet music_assistant {
        chain input {
          type filter hook input priority mangle; policy accept;
          iifname "tailscale0" tcp dport { 8097, 8927, $first_port-$last_port } socket cgroupv2 level 2 "$scope" counter drop
          iifname "tailscale0" udp dport 5353 socket cgroupv2 level 2 "$scope" counter drop
          iifname "eno1" ip saddr ${lan} ip daddr ${hostIp} tcp dport $first_port-$last_port socket cgroupv2 level 2 "$scope" counter meta mark set meta mark | ${mark}
          iifname "eno1" ip saddr ${lan} ip daddr ${hostIp} udp sport 1900 udp dport $first_port-$last_port socket cgroupv2 level 2 "$scope" counter meta mark set meta mark | ${mark}
          iifname "eno1" ip saddr ${onkyoIp} ip daddr ${hostIp} udp dport $first_port-$last_port socket cgroupv2 level 2 "$scope" counter meta mark set meta mark | ${mark}
        }
      }
      EOF
      }

      read -r first_port last_port < /proc/sys/net/ipv4/ip_local_port_range
      since=$(date +%s)
      refresh_rules
      ${docker} events --since "$since" --filter type=container --filter container=${container} \
        --filter event=start --filter event=die --format '{{.Action}}' |
        while read -r action; do
          refresh_rules
        done
    '';
  };
}
