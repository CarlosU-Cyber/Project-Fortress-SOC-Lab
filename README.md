# Project Fortress: Enterprise Systems & Security Operations Lab

![Status](https://img.shields.io/badge/Status-Phase_3.2_Complete-success)
![Hypervisor](https://img.shields.io/badge/Hypervisor-ESXi_7.0_Ent+-blue)
![Management](https://img.shields.io/badge/Management-vCenter_7.0_Std-purple)
![Firewall](https://img.shields.io/badge/Firewall-Netgate_pfSense-red)

## Overview
Project Fortress is a segmented, on-premises enterprise infrastructure and security operations lab. Originally conceptualized as a fully virtualized environment, the architecture is evolved into a hybrid physical-and-virtual enterprise footprint. The current core utilizes a dedicated physical firewall boundary, centralized hypervisor management, logical network segmentation, Tier 0 management controls, Active Directory identity services, and a segmented backup pipeline to simulate a hardened corporate datacenter environment.

The primary objective is to build a structurally sound foundation for systems administration, network engineering, and security operations workflows—moving from core infrastructure, identity, and backup operations toward advanced local telemetry collection, centralized monitoring, and detection engineering.

---

## Architecture Evolution: Transition to Physical Routing
* **Legacy Design:** The initial deployment validated a virtualized pfSense appliance using PCIe NIC passthrough with a documented ESXi ACS compatibility setting.
* **Architectural Pivot:** To better align with enterprise-style reliability and control-plane separation, the routing boundary was migrated to a dedicated physical Netgate appliance in Phase 3.1. This separates the compute plane from the routing/security plane and reduces dependency on the ESXi host for firewall and network availability.

---

## Physical Hardware & Datacenter Topology
The lab is anchored by physical switching and compute components connected via high-throughput fiber and direct-attach copper (DAC) backbones.

[View full-size Target-State Network Diagram](images/project-fortress-target-state-network.png)

> **Network Diagram Note:** The diagram linked above represents the Phase 3 target-state architecture, including active core routing segments and reserved future service zones. The physical Netgate firewall, 10G DAC trunk, pfSense VLAN interfaces, and ESXi VLAN-backed port groups were implemented in Phase 3.1. Workloads in reserved or future zones are not considered active until deployed and validated in their dedicated phases.

* **Compute / Hypervisor:** AMD Ryzen 7 5800X (8-Core) | 64GB DDR4 | VMware ESXi 7.0 (Licensed)
* **Power Stability:** UPS with Automatic Voltage Regulation (AVR) to mitigate unstable facility power delivery and voltage fluctuations.
* **Central Management:** VMware vCenter Server Appliance (vCSA) 7.0
* **Physical Firewall/Perimeter:** Netgate Enterprise Security Appliance running pfSense Plus
* **Upstream Edge Router:** Ubiquiti UDM-Pro
* **Secondary Storage Target:** Unraid NAS (192.168.0.10) for long-term retention

---

## Operational Controls Added in Phase 2.2
* Repeatable Windows Server provisioning through VMware PowerCLI.
* Sysprepped Windows Server 2019 golden image supporting core Windows infrastructure and identity roles.
* Veeam Backup & Replication deployed outside the future AD domain boundary within a standalone workgroup.
* Unraid NAS configured as an off-host backup repository for management-plane protection.
* UPS with AVR added to stabilize ESXi host operations under load.
* **Backup Staging Note:** Veeam was initially staged on the pre-migration management network (`192.168.0.14`) during Phase 2.2, then migrated into the dedicated Backup & Recovery VLAN during Phase 3.2.

---

## Operational Controls Added in Phase 3.1
* Physical Netgate/pfSense firewall deployed as the dedicated routing and security boundary.
* 10G DAC trunk established between the Netgate firewall and ESXi host.
* pfSense VLAN interfaces created for the core datacenter subnet plan.
* ESXi `vSwitch-Fortress` and VLAN-backed port groups created for segmented workload placement.
* ESXi and vCenter management migrated into the Tier 0 management network.
* Local break-glass management path retained for rollback and recovery during routing changes.
* pfSense configuration backups exported before and after VLAN/interface changes to support rollback capability.

---

## Operational Controls Added in Phase 3.2
* Active Directory Domain Services deployed under the internal forest root `fort.internal`.
* Primary and secondary Windows Server 2019 domain controllers deployed for identity and DNS redundancy.
* Domain controllers treated administratively as Tier 0 identity assets due to their control over authentication, DNS, Kerberos, and domain-wide policy.
* Baseline OU structure created with PowerShell automation to support GPO targeting, administrative separation, service account organization, and future security group delegation.
* Dedicated Domain Admin account created to separate standard user activity from directory-level administrative actions.
* Windows Server 2019 file server deployed with a dedicated data volume for SMB share hosting.
* File Server Resource Manager installed for future file-screening and data-governance policies.
* Veeam Backup & Replication migrated into the dedicated Backup & Recovery VLAN (`10.0.99.0/24`) while remaining outside the Active Directory domain.
* pfSense firewall rules limited Veeam communication to required backup, repository, and management-plane paths.
* Phase 3.2 infrastructure baseline backup completed for the domain controllers and file server operating system baselines.

---

## Build Logs
* [Phase 1: Perimeter Foundation](BUILD_LOG_PHASE_1.md)
* [Phase 2.1: vCenter Deployment & Troubleshooting](BUILD_LOG_PHASE_2.1.md)
* [Phase 2.2: Infrastructure Automation & Pre-Migration Backup](BUILD_LOG_PHASE_2.2.md)
* [Phase 3.1: Core Infrastructure & Tier 0 Migration](BUILD_LOG_PHASE_3.1.md)
* [Phase 3.2: Identity Services, Resource Sharing, & Segmented Backup Operations](BUILD_LOG_PHASE_3.2.md)

---

## Logical Network & Subnet Blueprint
The inner datacenter utilizes a strict `10.0.x.0/24` addressing scheme, where the third octet corresponds directly to the VLAN ID for simplified routing identification.

> **Reserved Segment Note:** Some VLANs are pre-provisioned for future standalone projects. Reserved VLANs are included for address planning, firewall object design, and future routing consistency, but their associated workloads are not considered active until implemented and validated in a dedicated project phase.

### 1. Subnet Matrix

| VLAN ID | Zone Name | Subnet | Gateway | Status | Core Services / Target Virtual Machines |
|---|---|---|---|---|---|
| **10** | Tier 0 - Management | `10.0.10.0/24` | `10.0.10.1` | Active / Phase 3.1 Complete | vCenter, ESXi Mgmt, Ansible, Jump Box |
| **20** | Tier 1 - Prod & Identity | `10.0.20.0/24` | `10.0.20.1` | Routed / Phase 3.2 Identity Complete | AD DS, File Server |
| **30** | Tier 2 - DMZ | `10.0.30.0/24` | `10.0.30.1` | Routed / Phase 3.3 Target | Reverse Proxy, Edge App Server |
| **40** | Voice/UC Reserved | `10.0.40.0/24` | `10.0.40.1` | Reserved / Future Project | VoIP PBX, SIP Services |
| **50** | Security Monitoring | `10.0.50.0/24` | `10.0.50.1` | Phase 4 & 5 Target | SIEM, Wazuh, Zabbix |
| **99** | Backup & Recovery | `10.0.99.0/24` | `10.0.99.1` | Active / Phase 3.2 Complete | DC1-VEEAM-01 |

### 2. Default Firewall Policy Matrix
*Default Posture: Implicit Deny. Inter-VLAN traffic is dropped unless explicitly permitted.*

| Source Zone | Destination Zone | Allowed Traffic | Purpose |
|---|---|---|---|
| Admin Workstation | VLAN 10 Mgmt | HTTPS, SSH, RDP | Controlled core administration |
| VLAN 10 Mgmt | VLAN 20 Prod & Identity | WinRM, SSH, management ports | Automation and server configuration |
| VLAN 20 Prod & Identity | VLAN 10 Mgmt | **Deny by default** | Protect the core management plane |
| VLAN 99 Backup | VLAN 10 Mgmt | HTTPS, VMware API, NFC / TCP 902 | vCenter and ESXi backup operations |
| VLAN 99 Backup | Unraid NAS | SMB / TCP 445 | Backup repository access |
| VLAN 10 / 20 / 30 | VLAN 99 Backup | **Deny by default** | Backup vault protection and ransomware risk reduction |
| VLAN 20 Prod & Identity | VLAN 50 SIEM | Syslog, Windows Event Forwarding, agent telemetry | Future log forwarding and endpoint monitoring |
| VLAN 50 SIEM | Selected Infrastructure | SNMP, WMI, API polling ports | Future health monitoring and structural visibility |
| VLAN 30 DMZ | VLAN 20 Prod & Identity | App-specific ports only | Controlled backend resource mapping |
| VPN Clients | Selected VLANs | Role-based access only | Remote lab engineering and administration |

---

## Project Phasing & Status

### Phase 1: Perimeter Foundation (Completed)
* Validated the initial virtual pfSense routing design using PCIe NIC passthrough, base ESXi networking, and upstream UDM-Pro DNS aliases required for vCenter initialization.

### Phase 2: Centralized Management & Automation (Completed)
* **Phase 2.1 - Control Plane:** Deployed vCenter Server Appliance (vCSA) 7.0 to handle centralized virtual datacenter orchestration.
* **Phase 2.2 - Automation & DR:** Utilized VMware PowerCLI to automate VM provisioning. Constructed a Sysprepped Windows Server 2019 "Golden Image" template. Deployed and configured Veeam Backup & Replication within a standalone workgroup to secure the vCenter control plane to an Unraid NAS prior to network migration. Stabilized host hardware using an AVR UPS.

### Phase 3: Physical Core Routing & Identity Services (In Progress)
* **Phase 3.1 - Physical Routing:** Completed deployment of the physical Netgate firewall, 10G DAC trunk to ESXi, pfSense VLAN interfaces, ESXi VLAN-backed port groups, and Tier 0 management migration for ESXi/vCenter.
* **Phase 3.2 - Identity Services, File Services, & Backup Segmentation:** Completed deployment of the `fort.internal` Active Directory forest, primary and secondary Windows Server 2019 domain controllers, internal DNS, reverse lookup zone, baseline OU structure, dedicated Domain Admin account, Windows file server, SMB share foundation, and Veeam migration into the dedicated Backup & Recovery VLAN.
    * **Internal AD Domain:** `fort.internal`
    * **Identity Tier Note:** Domain controllers reside in the Production VLAN for this lab phase but are treated administratively as Tier 0 identity assets due to their control over authentication, DNS, Kerberos, and domain-wide policy.
    * **DNS Transition Note:** `vcenter.home` was retained as the vCenter management alias during the migration to avoid unnecessary PNID, SSO, or certificate disruption. Future management records may be transitioned or duplicated under the `fort.internal` namespace as the domain matures.
    * **Lab Rationale:** `.internal` is used as a private internal namespace for the lab. The shorter `fort.internal` format improves administrative usability while avoiding `.local`, which can conflict with mDNS behavior.
    * **Production Note:** In a production enterprise environment, the preferred design would typically use a delegated subdomain of an owned public domain, such as `ad.ufprime.org`.
* **Phase 3.3 - Remote Operations:** Configuration of a DMZ reverse proxy (`DC1-PROXY-01`) to handle inbound TLS termination and deployment of a WireGuard VPN tunnel endpoint for role-based remote access.

### Phase 4: Telemetry Pipeline & Centralized Ingestion (Planned Future State)
* **SIEM Core Deployment:** Stand up a centralized SIEM console (`DC1-SIEM-01`) in the dedicated Security Monitoring zone.
* **Log Aggregation:** Configure structured data collection pipelines to parse, ingest, and index core infrastructure logs:
    * pfSense/Netgate firewall packet filter logs via Syslog.
    * Windows Security, System, and Application logs via Windows Event Forwarding (WEF/WEC).
    * VMware vCenter event trails and ESXi audit logs.
    * Veeam backup job results and console access audit trails.
* **Performance Baseline Monitoring:** Implement Zabbix infrastructure polling using restricted SNMP/WMI rules across the firewall matrix to monitor system resource metrics.

### Phase 5: Detection Engineering & Security Operations (Planned Future State)
* **Endpoint Protection:** Deploy Wazuh host-based monitoring agents across all active servers in Tier 0 and Tier 1.
* **Detection Mechanics:** Write and test custom detection rules targeting common adversary tradecraft, including:
    * Failed authentication spikes and brute-force patterns across SSH, RDP, and WinRM.
    * Unauthorized local administrator group additions or service creation events.
    * Suspicious PowerShell execution flags, including encoded command strings.
    * Lateral movement indicators and inter-VLAN firewall drops.
* **SecOps Artifact Generation:** Document live operational playbooks, structured alert triage case notes, and mock incident reports showing timeline construction, root-cause verification, and remediation workflows.

---

## Decoupled Future Projects (Out of Scope)
Although these services are decoupled from the current Project Fortress implementation, their VLANs and routing objects are pre-provisioned during Phase 3 to preserve a clean subnet plan and avoid future address redesign.

1. **Enterprise Unified Communications (VoIP) Infrastructure:** Implementation of a dedicated Voice/UC zone (`VLAN 40`), SIP trunk configurations, and deployment of an independent private branch exchange appliance.
2. **Secure Mail Gateway & Internal Messaging Enclave:** Deployment of internal mailbox servers and edge mail security gateways for secure email hygiene testing.
3. **Hybrid Cloud Directory Extension Architecture:** Implementation of Entra ID Connect sync, cross-premises VPN networking, and cloud-native infrastructure mapping utilizing the owned `ufprime.org` domain footprint.
