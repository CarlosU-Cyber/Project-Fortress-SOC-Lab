# Build Log - Phase 1: Perimeter Foundation

**Date:** May 17, 2026  
**Objective:** Establish the virtual firewall, PCIe hardware passthrough, and segmented 10-net routing boundary.

## Step 1: Virtual Cabling & Hardware Passthrough Configuration
Before provisioning the firewall, the underlying ESXi host and virtual networking required configuration to support the boundary architecture.
* **Virtual Cabling:** Created a new virtual switch (`vSwitch-Lab-LAN`) and explicitly removed any physical uplinks to establish the Layer 2 isolated segment. Created an associated port group.
* **Hardware Troubleshooting:** Initial attempts to pass the motherboard's Intel I225-V 2.5G NICs to the VM failed. The devices did not appear in the physical NIC menu and presented "Needs Reboot" errors.
* **BIOS & Hypervisor Remediation:** Verified SVM Mode and SR-IOV were enabled in the BIOS. Changed AMD CBS IOMMU from `AUTO` to `Enabled`. Due to consumer hardware lacking sufficient dedicated PCIe lanes for strict hardware isolation, the ESXi `disableACSCheck` flag was used as a documented lab compatibility setting to enable PCIe passthrough on consumer hardware.

## Step 2: Base pfSense Installation
Deployed `pfSense-CE-2.7.2-RELEASE-amd64.iso` to the ESXi host, mapping the passed-through Intel I225-V as the WAN and a VMXNET3 adapter on the `vSwitch-Lab-LAN` as the LAN.
* Configured using **Auto (ZFS)** for filesystem resiliency, data integrity, and future snapshot/rollback support.
* **Ref:** `![ZFS Setup](images/01_pfSense_ZFS_Partitioning.png)`
* **Ref:** `![Install Complete](images/02_pfSense_Install_Complete.png)`

## Step 3: Initial Management Access Recovery
Because pfSense applies a default-deny posture on the WAN interface, and the LAN interface was attached to a segmented virtual switch, initial WebGUI access was not available from the upstream management network.
* Accessed the pfSense VM console through ESXi and used `pfctl -d` to temporarily disable packet filtering for initial configuration access.
* This temporary administrative action was used only during setup and was subsequently replaced with a documented firewall management rule.
* **Ref:** `![pfctl disabled](images/03_pfSense_Disable_PacketFilter_CLI.png)`

## Step 4: WebGUI Setup Wizard
Navigated the setup wizard via `https://192.168.0.12` (Static UDM-Pro reservation).
* **Timezone:** Set to America/Los_Angeles. (`![Timezone](images/04_pfSense_Wizard_Timezone.png)`)
* **Upstream Routing Config:** Unchecked "Block RFC1918 Private Networks" because the upstream UDM-Pro providing WAN connectivity operates in the `192.168.0.0/24` private address space. The bogon network setting was reviewed and adjusted as needed for the lab routing path. (`![RFC1918](images/05_pfSense_Wizard_Unblock_RFC1918.png)`)
* **LAN Configuration:** Configured the lab LAN as `10.10.10.0/24` within RFC1918 private address space to reduce routing conflicts with future VPNs or segmented lab networks. (`![LAN Config](images/06_pfSense_Wizard_LAN_Config.png)`)

## Step 5: VMXNET3 Offload Patching
To reduce the risk of checksum/offload-related packet issues across the ESXi virtual switch, hardware offloading was disabled in pfSense.
* Navigated to **System > Advanced > Networking**.
* Checked **Disable hardware checksum offload**.
* **Ref:** `![Offloading Disabled](images/08_pfSense_Disable_Hardware_Checksum.png)`

## Step 6: Controlled WAN Management Rule
Created a documented firewall rule allowing HTTPS management access from the trusted upstream management network, eliminating the need for temporary console-level packet filter changes.
* **Action:** Pass
* **Interface:** WAN
* **Source:** Network (`192.168.0.0/24`)
* **Destination Port:** HTTPS (443)
* **Phase 1 Hardening Note:** This rule currently allows HTTPS management from the broader `192.168.0.0/24` home network. Future iterations will restrict access to a dedicated admin workstation `/32` or management VLAN.
* **Ref:** `![Firewall Rule](images/10_pfSense_Firewall_Rule_WAN_Admin.png)`

## Step 7: Workload Provisioning & Routing Verification
To validate the VMXNET3 offload fix and the routing boundary, a test probe was deployed into Domain 3.
* **VM Provisioning:** Spun up `SOC-Test-Node01` (Ubuntu 26.04), ensuring attachment to the Layer 2 `vSwitch-Lab-LAN` using a `VMXNET3` adapter.
* **Ref:** `![VM Settings](images/11_Ubuntu_VM_Creation_Settings.png)`
* **DHCP Validation:** During OS installation, the VM successfully requested and received a DHCP lease (`10.10.10.10/24`) directly from the pfSense LAN interface.
* **Ref:** `![DHCP Lease](images/12_Ubuntu_Installer_Network_DHCP.png)`
* **Routing Validation:** Post-installation, the probe successfully completed an outbound ICMP test to `google.com`, proving full NAT and DNS resolution through the pfSense firewall and upstream UDM-Pro policies.
* **Ref:** `![Console Ping Test](images/13_Ubuntu_Console_Ping_Test.png)`

**PHASE 1 STATUS: COMPLETE & VERIFIED.**
