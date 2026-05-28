# Project Fortress: Enterprise Systems & Security Operations Lab

![Status](https://img.shields.io/badge/Status-Phase_2.2_Complete-success)
![Hypervisor](https://img.shields.io/badge/Hypervisor-ESXi_7.0_Ent+-blue)
![Management](https://img.shields.io/badge/Management-vCenter_7.0_Std-purple)
![Firewall](https://img.shields.io/badge/Firewall-pfSense_2.7.2-red)

## Overview
Project Fortress is a segmented, on-premises enterprise infrastructure and security operations lab. Originally conceptualized as a fully virtualized environment, the architecture is evolving into a hybrid physical-and-virtual enterprise footprint. The target architecture utilizes a dedicated physical firewall boundary, centralized hypervisor management, logical network segmentation, and tier-separated identity services to simulate a hardened corporate datacenter environment.

The primary objective is to build a structurally sound foundation for systems administration, network engineering, and security operations workflows—moving from core infrastructure automation to advanced local telemetry collection and centralized monitoring.

---

## Architecture Evolution: Transition to Physical Routing
* **Legacy Design:** The initial deployment validated a virtualized pfSense appliance using PCIe NIC passthrough with a documented ESXi ACS compatibility setting.
* **Architectural Pivot:** To better align with enterprise-style reliability and control-plane separation, the routing boundary is being migrated to a dedicated physical Netgate appliance in Phase 3.1. This separates the compute plane from the routing/security plane and reduces dependency on the ESXi host for firewall and network availability.

---

## Physical Hardware & Datacenter Topology
The lab is anchored by physical switching and compute components connected via high-throughput fiber and direct-attach copper (DAC) backbones. 

[View full-size Target-State Network Diagram](images/project-fortress-target-state-network.png)

> **Network Diagram Note:** The diagram linked above represents the Phase 3 target-state architecture. The current Phase 2.2 environment remains in pre-migration staging while the physical Netgate firewall and VLAN trunk are implemented.

* **Compute / Hypervisor:** AMD Ryzen 7 5800X (8-Core) | 64GB DDR4 | VMware ESXi 7.0 (Licensed)
* **Power Stability:** UPS with Automatic Voltage Regulation (AVR) to mitigate unstable facility power delivery and voltage fluctuations.
* **Central Management:** VMware vCenter Server Appliance (vCSA) 7.0
* **Physical Firewall/Perimeter:** Netgate Enterprise Security Appliance *(Phase 3 target / migration in progress)*
* **Upstream Edge Router:** Ubiquiti UDM-Pro
* **Secondary Storage Target:** Unraid NAS (192.168.0.10) for long-term retention

---

## Operational Controls Added in Phase 2.2
* Repeatable Windows Server provisioning through VMware PowerCLI.
* Sysprepped Windows Server 2019 golden image supporting core Windows infrastructure and identity roles.
* Veeam Backup & Replication deployed outside the future AD domain boundary within a standalone workgroup.
* Unraid NAS configured as an off-host backup repository for management-plane protection.
* UPS with AVR added to stabilize ESXi host operations under load.
* **Backup Staging Note:** Veeam is currently staged on the pre-migration management network (`192.168.0.14`) and will move into its designated Backup & Recovery segment during Phase 3 VLAN implementation.

---

## Build Logs
* [Phase 1: Perimeter Foundation](BUILD_LOG_PHASE_1.md)
* [Phase 2.1: vCenter Deployment & Troubleshooting](BUILD_LOG_PHASE_2.1.md)
* [Phase 2.2: Infrastructure Automation & Pre-Migration Backup](BUILD_LOG_PHASE_2.2.md)

---

## Logical Network & Subnet Blueprint
The inner datacenter utilizes a strict `10.0.x.0/24` addressing scheme, where the third octet corresponds directly to the VLAN ID for simplified routing identification.

> **Reserved Segment Note:** Some VLANs are pre-provisioned for future standalone projects. Reserved VLANs are included for address planning, firewall object design, and future routing consistency, but their associated workloads are not considered active until implemented and validated in a dedicated project phase.

### 1. Subnet Matrix
| VLAN ID | Zone Name | Subnet | Gateway | Status | Core Services / Target Virtual Machines |
|---|---|---|---|---|---|
| **10** | Tier 0 - Management | `10.0.10.0/24` | `10.0.10.1` | Phase 3 Core / Target | vCenter, Ansible, Jump Box |
| **20** | Tier 1 - Prod & Identity | `10.0.20.0/24` | `10.0.20.1` | Phase 3 Core / Target | AD DS, File Server |
| **30** | Tier 2 - DMZ | `10.0.30.0/24` | `10.0.30.1` | Phase 3 Core / Target | Reverse Proxy, Edge App Server |
| **40** | Voice/UC Reserved | `10.0.40.0/24` | `10.0.40.1` | Reserved / Future Project | VoIP PBX, SIP Services |
| **50** | Security Monitoring | `10.0.50.0/24` | `10.0.50.1` | Phase 4 Target | SIEM, Wazuh, Zabbix |
| **99** | Backup & Recovery | `10.0.99.0/24` | `10.0.99.1` | Phase 3 Core / Target | Veeam Backup Server |

### 2. Default Firewall Policy Matrix
*Default Posture: Implicit Deny. Inter-VLAN traffic is dropped unless explicitly permitted.*

| Source Zone | Destination Zone | Allowed Traffic | Purpose |
|---|---|---|---|
| Admin Workstation | VLAN 10 Mgmt | HTTPS, SSH, RDP | Controlled core administration |
| VLAN 10 Mgmt | VLAN 20 Prod | WinRM, SSH, management ports | Automation and server configuration |
| VLAN 20 Prod | VLAN 10 Mgmt | **Deny by default** | Protect the core management plane |
| VLAN 20 Prod | VLAN 50 SIEM | Syslog, agent telemetry | Log forwarding and endpoint monitoring |
| VLAN 50 SIEM | Selected Infrastructure | SNMP, WMI, API polling ports | Health monitoring and structural visibility |
| VLAN 30 DMZ | VLAN 20 Prod | App-specific ports only | Controlled backend resource mapping |
| VLAN 99 Backup | VLAN 10 / 20 / 30 | Backup-required VMware API, RPC, SMB ports | Backup job execution and snapshot pulls |
| VLAN 10 / 20 / 30 | VLAN 99 Backup | **Deny by default** | Ransomware mitigation / Backup vault protection |
| VPN Clients | Selected VLANs | Role-based access only | Remote lab engineering and administration |

---

## Project Phasing & Status

### Phase 1: Perimeter Foundation (Completed)
* Validated the initial virtual pfSense routing design using PCIe NIC passthrough, base ESXi networking, and upstream UDM-Pro DNS aliases required for vCenter initialization.

### Phase 2: Centralized Management & Automation (Completed)
* **Phase 2.1 - Control Plane:** Deployed vCenter Server Appliance (vCSA) 7.0 to handle centralized virtual datacenter orchestration.
* **Phase 2.2 - Automation & DR:** Utilized VMware PowerCLI to automate VM provisioning. Constructed a Sysprepped Windows Server 2019 "Golden Image" template. Deployed and configured Veeam Backup & Replication within a standalone workgroup to secure the vCenter control plane to an Unraid NAS prior to network migration. Stabilized host hardware using an AVR UPS.

### Phase 3: Physical Core Routing & Identity Services (Target State)
* **Phase 3.1 - Physical Routing:** Deployment of the physical Netgate firewall and configuration of the `802.1Q VLAN Trunk` to the ESXi hypervisor to enforce default inter-VLAN deny postures.
* **Phase 3.2 - Identity Services:** Deploy Windows Server 2019 Active Directory Domain Services (AD DS) using the existing Sysprepped golden image baseline.
    * **Internal AD Domain:** `fort.internal`
    * **DNS Transition Note:** `vcenter.home` is a pre-AD management alias hosted upstream on the UDM-Pro. After AD DS deployment, management records will be transitioned or duplicated under the `fort.internal` namespace.
    * **Lab Rationale:** `.internal` is used as a private internal namespace for the lab. The shorter `fort.internal` format improves administrative usability while avoiding `.local`, which can conflict with mDNS behavior.
    * **Production Note:** In a production enterprise environment, the preferred design would typically use a delegated subdomain of an owned public domain, such as `ad.ufprime.org`.
* **Phase 3.3 - Remote Operations:** Configuration of a DMZ reverse proxy (`DC1-PROXY-01`) to handle inbound TLS termination and deployment of a WireGuard VPN tunnel endpoint for role-based remote access.

### Phase 4: Telemetry, Logging, & Centralized Monitoring (Future State)
* Deployment of a centralized SIEM (`DC1-SIEM-01`) and Wazuh host-based monitoring agents to collect firewall and Windows security event logs.
* Installation of infrastructure monitoring using limited SNMP/WMI polling rules across the firewall matrix to track compute and network capacity.

---

## Decoupled Future Projects (Out of Scope)
Although these services are decoupled from the current Project Fortress implementation, their VLANs and routing objects are pre-provisioned during Phase 3 to preserve a clean subnet plan and avoid future address redesign.

1. **Enterprise Unified Communications (VoIP) Infrastructure:** Implementation of a dedicated Voice/UC zone (`VLAN 40`), SIP trunk configurations, and deployment of an independent private branch exchange appliance.
2. **Secure Mail Gateway & Internal Messaging Enclave:** Deployment of internal mailbox servers and edge mail security gateways for secure email hygiene testing.
3. **Hybrid Cloud Directory Extension Architecture:** Implementation of Entra ID Connect sync, cross-premises VPN networking, and cloud-native infrastructure mapping utilizing the owned `ufprime.org` domain footprint.
