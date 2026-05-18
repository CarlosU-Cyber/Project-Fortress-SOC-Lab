# Project Fortress: Enterprise Systems & Security Operations Lab

![Status](https://img.shields.io/badge/Status-Phase_1_Complete-success)
![Hypervisor](https://img.shields.io/badge/Hypervisor-ESXi_8.0-blue)
![Firewall](https://img.shields.io/badge/Firewall-pfSense_2.7.2-red)

## Overview
Project Fortress is an enterprise systems and security operations lab built on VMware ESXi and consumer-grade AMD Ryzen hardware. The project demonstrates virtual firewall deployment, segmented lab networking, PCIe NIC passthrough, and controlled routing between the lab LAN and the upstream home network.

The primary objective of Phase 1 is to establish a pfSense-controlled lab segment at `10.10.10.0/24` for future security tooling, SIEM deployment, Windows/AD testing, and endpoint telemetry validation. The lab network is isolated at Layer 2 and governed at Layer 3 through pfSense firewall, NAT, and DHCP services to reduce risk to the upstream network.

## Architecture

![Network Architecture](images/00_Project_Fortress_Architecture.png)

### Dedicated WAN Interface via PCIe Passthrough
Due to consumer motherboard ACS limitations, the lab uses a documented ESXi passthrough compatibility setting (`VMkernel.Boot.disableACSCheck=true`) to assign a physical Intel I225-V NIC directly to the pfSense VM. This creates a dedicated WAN path for the virtual firewall while keeping ESXi management and lab workload traffic separated into distinct network domains. 

**Risk Note:** This ACS-related passthrough setting is documented as a lab-only compatibility configuration. Because it may reduce hardware-enforced PCIe device isolation, it is treated as an accepted lab risk and should not be considered a production-grade isolation control.

* **Domain 1: ESXi Management Plane:** Intel X710 10G DAC
* **Domain 2: pfSense WAN Path:** PCIe-passthrough Intel I225-V
* **Domain 3: Lab LAN Segment:** Layer 2 Virtual `vSwitch-Lab-LAN` connected to pfSense LAN

## Hardware Specifications
* **Compute:** ASUS ROG Strix / AMD Ryzen 7 5800X (8-Core)
* **Memory:** 64GB DDR4
* **Networking (Physical):** Intel X710 10G DAC, Dual Intel I225-V 2.5G
* **Upstream Router:** Ubiquiti UDM-Pro

## Current Security Posture
* Lab workloads are separated from ESXi management traffic.
* The lab LAN has no direct physical uplink and routes through pfSense policy.
* pfSense provides DHCP, NAT, and firewall control for the `10.10.10.0/24` segment.
* Phase 1 management access is documented and scheduled for hardening to a dedicated admin workstation or management VLAN.

## Project Roadmap
- [x] **Phase 1: Perimeter Foundation** (Hardware Passthrough, pfSense Deployment, Segmented Lab Boundary, Routing Verification).
- [ ] **Phase 2: Management & Resiliency** (vCenter Deployment, Veeam Backup Strategy).
- [ ] **Phase 3: Controlled Remote Access** (WireGuard VPN, collaborator access controls, firewall policy, and logging).
- [ ] **Phase 4: Tool Provisioning** (Security tooling, Splunk/ELK, Windows AD Environment).
