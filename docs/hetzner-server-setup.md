# Hetzner Dedicated Server Setup

Guide for provisioning a new Hetzner dedicated server with NixOS, ZFS, and Incus virtualization.

## 1. Order the Server

1. Go to [robot.hetzner.com](https://robot.hetzner.com) and order a dedicated server.
2. Order additional IP addresses for each VM you plan to run. In the order form's reason field, "virtual machine" is sufficient justification.

## 2. Install NixOS

1. Boot the server into **rescue mode** from the Hetzner Robot panel (Reset tab > Activate rescue system).
2. SSH into the rescue system.
3. Install NixOS using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) or manually partition and install. Use atlas's disko config (`atlas/disko.nix`) as a reference for ZFS mirror setup across two NVMe drives.

### Copy Atlas Configuration

Copy atlas's config directory as a starting point for the new server:

```sh
cp -r atlas/ newserver/
```

Edit the following in the new server's config:

- **`network-configuration.nix`** -- Update all IP addresses:
  - Set the server's IPv4 address and gateway (from Hetzner Robot > Server > IPs)
  - Set the IPv6 address -- **use a /128 subnet**, otherwise the address won't be available for Incus to use. Example:
    ```nix
    networkConfig = {
      Address = [ "2a01:4f9:xxxx:xxxx::2/128" ];
    };
    ```
  - Update the MAC address in the udev rule to match the new server's NIC
- **`disko.nix`** -- Update disk device paths (`/dev/disk/by-id/...`) to match the new server's drives
- **`default.nix`** -- Update `networking.hostName` and `networking.hostId` (generate with `head -c 8 /dev/urandom | od -A none -t x4 | tr -d ' '`)

Add the new server to `flake.nix` as a new `nixosConfigurations` entry.

## 3. Initialize Incus

After the server is running NixOS, initialize Incus. You should already have a ZFS dataset `$POOL/incus` (created by disko -- see `atlas/disko.nix`).

```sh
incus admin init
```

Answer the prompts as follows:

```
Would you like to use clustering? (yes/no) [default=no]: no
Do you want to configure a new storage pool? (yes/no) [default=yes]: yes
Name of the new storage pool [default=default]: default
Name of the storage backend to use (lvm, zfs, btrfs, dir) [default=zfs]: zfs
Create a new ZFS pool? (yes/no) [default=yes]: no
Name of the existing ZFS pool or dataset: $POOL/incus
Would you like to connect to a MAAS server? (yes/no) [default=no]: no
Would you like to create a new local network bridge? (yes/no) [default=yes]: yes
What should the new bridge be called? [default=incusbr0]: incusbr0
What IPv4 address should be used? (CIDR subnet notation, "auto" or "none") [default=auto]: auto
What IPv6 address should be used? (CIDR subnet notation, "auto" or "none") [default=auto]: auto
Would you like the server to be available over the network? (yes/no) [default=no]: no
```

Replace `$POOL` with your ZFS pool name (e.g. `rtorrent` on atlas).

### Configure Incus Networking

After init, reconfigure the bridge with proper IPv6 settings:

```sh
incus network edit incusbr0
```

Set the config to:

```yaml
config:
  ipv4.address: 10.0.0.1/24
  ipv4.nat: "true"
  ipv6.address: IPV6PREFIX::3/64
  ipv6.dhcp: "true"
  ipv6.dhcp.stateful: "true"
  ipv6.nat: "false"
  ipv6.routing: "true"
```

Replace `IPV6PREFIX` with your server's IPv6 prefix (e.g. for `2a01:4f9:1a:90eb::2/128`, the prefix is `2a01:4f9:1a:90eb`). This gives your VMs routable IPv6 addresses from the server's /64 block.

Setting `ipv6.nat: "false"` with `ipv6.routing: "true"` means VMs get globally routable IPv6 addresses without NAT, while IPv4 is NATed through the host.

## 4. VM Networking

### Configuring Fixed IPv6 for a VM

To assign a static IPv6 address to a VM from the bridge subnet:

```sh
incus config edit $VM
```

Add or update the `eth0` device:

```yaml
devices:
  eth0:
    ipv6.address: PREFIX::SUFFIX
    name: eth0
    nictype: bridged
    parent: incusbr0
    type: nic
```

Replace `PREFIX` with the IPv6 prefix and `SUFFIX` with a unique identifier for this VM. For example, `2a01:4f9:1a:90eb::10` for the first VM, `::11` for the second, etc.

### Configuring Public IPv4 for a VM

VMs that need their own public IPv4 address (ordered in step 1) use macvlan to share the host's physical NIC.

#### Step 1: Assign MAC Address in Hetzner Panel

1. Go to Hetzner Robot > Server > IPs
2. Find the additional IP you want to assign to the VM
3. Click the small screen icon next to the IP
4. Enter a custom MAC address -- Hetzner will generate one for you, or you can request one. Note this MAC address.

#### Step 2: Add macvlan Device to VM

```sh
incus config edit $VM
```

Add the `public0` device:

```yaml
devices:
  public0:
    name: public0
    nictype: macvlan
    parent: eth0
    type: nic
```

#### Step 3: Set the Hetzner MAC Address

The VM must use the MAC address assigned by Hetzner for the IP to route correctly. If a `volatile.public0.hwaddr` field already exists, remove it first, then set:

```yaml
config:
  volatile.public0.hwaddr: HETZNERMAC
```

Replace `HETZNERMAC` with the MAC address from the Hetzner panel.

#### Step 4: Configure NixOS Networking in the VM

In the VM's NixOS configuration, add the `public0` network interface. The gateway is the same as the host server's gateway:

```nix
systemd.network = {
  networks."40-public0" = {
    matchConfig = {
      Name = "public0";
    };
    gateway = [ "GW" ];
    addresses = [
      { addressConfig = { Address = "ADDRESS/26"; Peer = "GW"; }; }
    ];
  };
};
```

Replace:
- `GW` -- The server's gateway IP (e.g. `65.108.140.193` for atlas)
- `ADDRESS` -- The additional IP you ordered for this VM

The `Peer` field is set to the gateway because Hetzner uses point-to-point routing for additional IPs -- the VM needs to know that the gateway is reachable directly, not via the subnet.

## 5. Reference: Atlas Network Configuration

For a complete working example, see `atlas/network-configuration.nix`:

```nix
systemd.network = {
  enable = true;
  networks."40-eth0" = {
    matchConfig = { Name = "eth0"; };
    gateway = [ "fe80::1" "65.108.140.193" ];
    networkConfig = {
      Address = [ "2a01:4f9:1a:90eb::2/128" ];
    };
    addresses = [
      { Address = "65.108.140.241/26"; Peer = "65.108.140.193"; }
    ];
  };
};
```

Key points:
- IPv6 gateway is always `fe80::1` on Hetzner
- IPv4 uses `Peer` routing (point-to-point to the gateway)
- The udev rule renames the NIC to `eth0` based on MAC address for consistency
