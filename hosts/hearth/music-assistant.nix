{
  config,
  lib,
  pkgs,
  ...
}: let
  hostIp = config.homelab.hostIp;
  lan = "192.168.1.0/24";
  iot = "192.168.4.0/24";
  container = "homelab-music-assistant";
  docker = lib.getExe config.virtualisation.docker.package;
  nft = lib.getExe pkgs.nftables;
  mark = "0x10000000";
in {
  networking.firewall.extraCommands = ''
    iptables -w -A nixos-fw -i eno1 -s ${lan} -p udp --dport 5353 -j nixos-fw-accept
    iptables -w -A nixos-fw -i eno1 -s ${lan},${iot} -d ${hostIp} -p tcp --dport 8097 -j nixos-fw-accept
    iptables -w -A nixos-fw -i eno1 -s ${lan} -d ${hostIp} -m mark --mark ${mark}/${mark} -j nixos-fw-accept
  '';

  systemd.services.music-assistant-firewall = {
    description = "Allow LAN traffic to Music Assistant discovery sockets";
    wantedBy = ["multi-user.target"];
    after = ["docker.service"];
    requires = ["docker.service"];
    partOf = ["docker.service"];
    serviceConfig = {
      Restart = "always";
      RestartSec = "2s";
      ExecStopPost = "${nft} destroy table ip music_assistant";
    };
    script = ''
      refresh_rules() {
        local id
        id=$(${docker} inspect --type container -f '{{if and .State.Running (eq .HostConfig.NetworkMode "host")}}{{.Id}}{{end}}' ${container} 2>/dev/null) || id=
        if [[ -z "$id" ]]; then
          ${nft} destroy table ip music_assistant
          return
        fi

        # Soloist and SSDP use OS-assigned ports. Match the container's sockets.
        ${nft} -f - <<EOF
      destroy table ip music_assistant
      table ip music_assistant {
        chain input {
          type filter hook input priority mangle; policy accept;
          iifname "eno1" ip saddr ${lan} ip daddr ${hostIp} tcp dport $first_port-$last_port socket cgroupv2 level 2 "system.slice/docker-$id.scope" counter meta mark set meta mark | ${mark}
          iifname "eno1" ip saddr ${lan} ip daddr ${hostIp} udp sport 1900 udp dport $first_port-$last_port socket cgroupv2 level 2 "system.slice/docker-$id.scope" counter meta mark set meta mark | ${mark}
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
