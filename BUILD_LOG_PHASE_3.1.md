# Project Fortress: Phase 3.1 - Core Infrastructure & Tier 0 Migration

## Phase Outcome
Phase 3.1 successfully migrated Project Fortress from a pre-migration management network into a physical pfSense-backed Tier 0 routing architecture. The Netgate appliance now provides the dedicated firewall boundary, the ESXi host receives VLAN-tagged traffic over a 10G DAC trunk, and ESXi/vCenter management has been moved into the `10.0.10.0/24` Tier 0 management network.

---

## 1. Hardware Initialization & pfSense Installation
**Hardware Prep:**
* **Target Drive:** Samsung 850 EVO 500GB 2.5" SATA SSD.
* **Health Verification:** Cleaned via Windows `diskpart`. Verified SMART data via CrystalDiskInfo (0 reallocated sectors, 0 uncorrectable errors, 99% Wear Level Count, ~28TB/150TB TBW). Drive health verified at optimal. Replaced SATA cable to remediate historical CRC error flag.

![Netgate Internal Hardware Modification](./images/phase3.1/01-hardware-netgate-ssd-wiring.jpeg)

* **OS Installation:** Installed pfSense Plus through local serial console access. 
  * Installed CP210x VCP drivers (COM3, 115200 baud) for local serial access.

![VCP Driver Installation](./images/phase3.1/02-windows-vcp-driver-install.png)
![pfSense First Boot Console](./images/phase3.1/03-pfsense-console-boot-menu.png)

* **Disk Configuration:** Targeted internal disk wiping via Advanced Options to clear onboard eMMC storage, then selected the Samsung SSD for installation.
  * **File System:** ZFS single-disk stripe with GPT partitioning.

![Netgate eMMC Wipe](./images/phase3.1/04-pfsense-installer-emmc-wipe.png)
![Netgate ZFS SSD Selection](./images/phase3.1/05-pfsense-installer-ssd-select.png)

## 2. Milestone 0: Pre-Change Safety & Physical Topology
**Objective:** Establish a resilient recovery path and define the 10Gbps backbone.

**Configuration Backup:** Exported a pfSense configuration backup before and after VLAN/interface changes to preserve rollback capability during the routing migration.

**Physical Interface Assignments:**
* **WAN (`ix1`):** 10G DAC uplink to 2.5G/10G external switch.
* **LAN/Trunk (`ix0`):** 10G DAC directly connected to the ESXi host (carrying all tagged VLAN traffic). Mapped to `vmnic1` on the hypervisor.
* **Local Break-Glass Management (`eth4`):** Hardware-switched port reserved for direct local admin access (`192.168.1.1/24`) during firewall and VLAN changes. Avoids Marvell switch chip VLAN tagging complexities.

![Physical Network Diagram](./images/phase3.1/22-topography-physical-network-diagram.png)
![Netgate Physical Wiring Labels](./images/phase3.1/20-hardware-netgate-physical-wiring.jpg)
![ESXi Physical Wiring Labels](./images/phase3.1/21-hardware-esxi-physical-wiring.jpg)

**Initial pfSense Configuration:**
* **Hostname:** `fw01` | **Domain:** `fort.internal`
* **DNS:** `1.1.1.1`, `8.8.8.8` (Configured explicit upstream DNS resolvers to avoid unintended dependency on upstream UDM-Pro DNS behavior).

![pfSense Setup Wizard DNS Configuration](./images/phase3.1/06-pfsense-webgui-wizard-dns.png)
![pfSense Dashboard Pre-Relocation](./images/phase3.1/07-pfsense-dashboard-initial.png)

## 3. Milestone 1: VLAN Interface Provisioning
**Objective:** Define the isolated datacenter zones within the pfSense routing table.

**VLAN Creation (Mapped to `ix0`):**
* **Tagging Standard:** 802.1Q (C-Tag). *Architectural Decision: S-Tags (QinQ) were intentionally not used because the ESXi host is not operating as a service-provider switching environment.*
* **QoS Priority:** Set to `0`. *Architectural Decision: IEEE 802.1p priority tagging was left at the default value because the 10G lab backbone is not currently constrained, and no QoS enforcement policy has been configured on the ESXi switching layer.*

![pfSense VLAN 10 Configuration Parameters](./images/phase3.1/08-pfsense-vlan10-creation.png)
![pfSense VLAN Configuration List](./images/phase3.1/09-pfsense-vlan-list-raw.png)
![Interface Assignment Mapping](./images/phase3.1/10-pfsense-interface-assignments-raw.png)

**Interface Provisioning & IP Schemas:**
* Assigned static `10.0.x.1/24` gateways to all logical interfaces.

![MGMT_VLAN10 Gateway Configuration](./images/phase3.1/11-pfsense-interface-mgmt-static-ip.png)
![Final Interface Topography](./images/phase3.1/12-pfsense-interface-assignments-final.png)

## 4. Milestone 2: ESXi Trunk Validation & Proof of Life
**Objective:** Ensure VMware ESXi correctly maps tagged 802.1Q trunk traffic to VLAN-backed port groups and passes workload traffic to the pfSense gateway.

**pfSense Bootstrap Preparation:**
* Activated temporary DHCP scopes (`.100 - .200`) across all VLANs.
* Deployed temporary "Allow All" firewall rules on `PROD_VLAN20` to validate routing.

![Temporary DHCP Configuration](./images/phase3.1/13-pfsense-temp-dhcp-setup.png)
![PROD_VLAN20 Bootstrap Firewall Rule](./images/phase3.1/14-pfsense-firewall-rule-allow-all.png)

**ESXi Virtual Switch Topography:**
* Identified `vmnic1` as the dedicated 10G DAC physical uplink to the Netgate router.
* Created `vSwitch-Fortress` (Uplink: `vmnic1`, MTU: `1500`).
* Built matching Port Groups using standard naming conventions (e.g., `PG-PROD_VLAN20`, VLAN ID: `20`).

![ESXi Virtual Switches](./images/phase3.1/23-esxi-virtual-switches-list.png)
![ESXi Port Groups](./images/phase3.1/24-esxi-port-groups-list.png)

**Validation:**
* Booted an Ubuntu Server VM on `PG-PROD_VLAN20`. VM successfully obtained a `10.0.20.x` IP and returned successful ICMP pings to `8.8.8.8`. 

![Ubuntu Proof of Life](./images/phase3.1/25-ubuntu-vm-proof-of-life.png)

## 5. Milestone 3: Tier 0 Management Plane Migration
**Objective:** Migrate the hypervisor management plane to the Tier 0 network (`10.0.10.x`) without rebuilding workloads or losing VM inventory state.

**ESXi Dual-Homing & Gateway Pivot:**
* Created a new VMkernel NIC (`vmk1`) on `PG-MGMT_VLAN10` assigned to `10.0.10.11`.

![ESXi Add VMkernel NIC](./images/phase3.1/26-esxi-vmkernel-nic-creation.png)
![ESXi vSwitch MGMT Topology](./images/phase3.1/27-esxi-vswitch-topology-mgmt.png)

* Pivoted the Default TCP/IP Stack Gateway to the pfSense router (`10.0.10.1`).

![ESXi Routing Table Pivot](./images/phase3.1/28-esxi-routing-table-gateway-pivot.png)

* Renamed the legacy UDM-Pro management connection on `vSwitch0` to `OOBM-UDM-BREAKGLASS` to preserve a documented break-glass recovery path during the Tier 0 migration.

![ESXi OOBM Break-Glass Topology](./images/phase3.1/29-esxi-oobm-breakglass-vswitch.png)

**vCenter Server Appliance (vCSA) Migration:**
* *Architectural Decision:* Created a dedicated `PG-VMs-MGMT_VLAN10` Port Group for the vCenter VM landing zone to separate appliance management traffic from workload port groups.
* **vCenter PNID Note:** The vCenter appliance retained `vcenter.home` during migration to avoid unnecessary PNID/certificate changes. pfSense DNS Resolver now provides a host override for `vcenter.home` to `10.0.10.10`.

![pfSense DNS Resolver PNID Override](./images/phase3.1/15-pfsense-dns-host-override-vcenter.png)

* **vCSA Network Recovery via Appliance Shell:**
    * Initial VAMI web configuration blocked due to `vcenter.home` resolution validation failure.
    * DCUI configuration attempt blocked by appliance security parameters (`IP configuration not allowed`).
    * Used the vCSA appliance shell to apply the network configuration after VAMI and DCUI methods failed validation (`/opt/vmware/share/vami/vami_config_net`). Set IPv4 to `10.0.10.10/24`, Gateway to `10.0.10.1`, and updated the appliance DNS configuration from the internal loopback resolver to the pfSense resolver.

![vCenter VAMI DNS Error](./images/phase3.1/30-vcenter-vami-dns-resolution-error.png)
![vCenter DCUI Security Block](./images/phase3.1/31-vcenter-dcui-ip-config-error.png)
![vCenter Shell DNS Override](./images/phase3.1/32-vcenter-shell-dns-override.png)
![vCenter DCUI Static IP Success](./images/phase3.1/33-vcenter-dcui-static-ip-success.png)

* **Temporary Local DNS Override:** Added a temporary Windows `hosts` file entry on the OOBM laptop to resolve `vcenter.home` to `10.0.10.10` during the DNS transition and SSO redirect validation.

![Windows Hosts File DNS Override](./images/phase3.1/16-windows-hosts-file-dns-override.png)

**Final Cleanup & Verification:**
* Logged into vCenter via the new IP.
* Removed the legacy/disconnected ESXi host ghost record (`192.168.0.11`).
* Re-added the ESXi host via its new Tier 0 IP (`10.0.10.11`). All virtual machines successfully repopulated under the new datacenter architecture.

![vCenter Pre-Modification Error State](./images/phase3.1/17-vcenter-host-disconnected-alarm.png)
![vCenter Finalized Health State](./images/phase3.1/18-vcenter-host-reconnected-green.png)
![pfSense Final Dashboard Configuration](./images/phase3.1/19-pfsense-dashboard-final-10g-links.png)

---

## Open Hardening Items
* Replace temporary DHCP scopes with final service-specific DHCP/static addressing plans.
* Replace bootstrap "Allow All" rules with least-privilege inter-VLAN firewall rules.
* Validate remaining VLANs during service deployment (VLAN 20 was used as the initial proof-of-life test case).
* Document rollback procedure using pfSense configuration backups and the break-glass management path.
* Plan future `vcenter.home` to `fort.internal` DNS transition carefully to avoid PNID, SSO, or certificate impact.
