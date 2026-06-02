# Phase 3.2: Identity Services, Resource Sharing, & Segmented Backup Operations

## 1. Groundwork: Jump Box Configuration
To streamline administration without flattening the network or weakening segmentation controls, I configured my laptop as a dedicated jump box. 
* Connected the laptop to the Management network via the UDM-Pro.
* **Troubleshooting:** Initial RDP attempts from the main workstation failed due to Windows 11 Home limitations.
* **Resolution:** Upgraded the laptop to Windows 11 Pro using a valid license to enable native Remote Desktop support.
* **QoL Adjustments:** Modified power settings (`Do nothing` when lid closed, `Never` sleep) to allow headless RDP access from my main workstation into the vCenter management plane.

> **Security Control:** Network bridging and Internet Connection Sharing were left disabled. The laptop was used only as a controlled administrative jump host and not as a routed bridge between the home/perimeter network and the management network.

![Win 11 Key Error](/images/phase3.2/01-groundwork-win11-key-error.png)
![RDP Failed Attempt](/images/phase3.2/02-groundwork-rdp-failed.png) 

*Initial RDP connection failure and licensing hurdles prior to OS upgrade.*

![RDP Success](/images/phase3.2/03-groundwork-rdp-success.png)
*Successful headless RDP session established into the vCenter management plane.*

---

## 2. Deploying the Primary Domain Controller (DC1-DC-01)

**OS:** Windows Server 2019
**Role:** Primary Domain Controller. Hosts Active Directory Domain Services (AD DS) and the primary internal DNS zone.

### Template Recovery & Virtual Machine Provisioning
During the vCenter IP migration in Phase 3.1, the base templates lost their inventory registration. I successfully recovered them by navigating directly into the raw NVMe datastore (`ds-local-nvme-01`), locating the `.vmtx` file, and re-registering the VM to the ESXi host.

![vCenter No Template](/images/phase3.2/04-vcenter-missing-template.png)
![vCenter Datastore Recovery](/images/phase3.2/05-vcenter-datastore-recovery.png)
*Locating and re-registering the orphaned `.vmtx` template file from the raw datastore.*

![Deploy from Template](/images/phase3.2/06-dc1-template-deploy.png)
*Deploying DC1-DC-01 from the recovered Windows Server 2019 baseline template.*

* **Compute:** 10.0.10.11 (ESXi-01) | **Storage:** ds-local-nvme-01
* **Network:** Assigned to `PG-PROD_VLAN20` (Production VLAN).

> **Identity Tier Note:** Although the domain controllers reside in the Production VLAN for this lab phase, they are treated administratively as Tier 0 identity assets due to their control over authentication, DNS, Kerberos, and domain-wide policy.

![IPv4 Properties](/images/phase3.2/07-dc1-ipv4-config.png)
*Static IP configuration: 10.0.20.10, with loopback DNS for initial setup.*

![Rename PC](/images/phase3.2/08-dc1-rename-pc.png)
*Baseline OS renaming and Workgroup configuration prior to domain promotion.*

### Active Directory Domain Services (AD DS) Installation
Configured the server via Server Manager, strictly installing AD DS and DNS. 

> **Enterprise Security Note:** In production environments, the Remote Desktop Services Session Host role should not be installed on Domain Controllers. Domain Controllers should remain limited to identity, DNS, and supporting domain services whenever possible. Administrative access should be restricted to authorized Tier 0 administrators.

![Add Roles Confirmation](/images/phase3.2/09-dc1-adds-role-confirm.png)
![Add Roles Results](/images/phase3.2/10-dc1-adds-role-results.png)

### Domain Promotion & DNS Configuration
Promoted the server to a Domain Controller for a new forest root: **`fort.internal`**. 
* Ensured Forest and Domain functional levels were set to the highest available.
* Verified Global Catalog (GC) and DNS Server options were enabled.
* Created the necessary IPv4 Reverse Lookup Zone (`10.0.20.in-addr.arpa`) to ensure the domain registers service records correctly.

![ADDS Review Options](/images/phase3.2/11-dc1-adds-promo-review.png)
![Reverse Lookup Zone](/images/phase3.2/12-dc1-dns-reverse-zone.png)

### Verification
![Verify Domain Controllers](/images/phase3.2/13-dc1-verify-aduc.png)
![DNS Forward Lookup](/images/phase3.2/14-dc1-verify-dns.png)
*Active Directory initialization and DNS SRV record registration verified successfully.*

---

## 3. Infrastructure-as-Code: RBAC & OU Architecture

To avoid opening additional firewall paths during early domain buildout, I used VMware PowerCLI and VMware Guest Operations to execute the OU scaffolding script inside the domain controller using authenticated guest credentials.

*(Note: The `Build-FortressOUs.ps1` automation script used for this deployment can be found in the repository files).*

![PowerShell Execution](/images/phase3.2/15-rbac-powercli-execution.png)
*Remote execution of the OU scaffolding script via VMware PowerCLI.*

![Fortress-Corp OU Created](/images/phase3.2/16-rbac-ou-structure-created.png)
*Automated tiered OU structure successfully created in Active Directory.*

> **Domain Controller OU Note:** Domain Controllers remain in the default `Domain Controllers` OU to preserve standard domain controller policy inheritance. Tier 0 administrative systems and management servers are organized under the custom `Fortress-Corp` OU structure.

### Establishing Tier 0 Access
Created a dedicated Domain Admin account (`da_jadmin`) to separate standard user activities from directory-level administrative actions. 

![Jadmin Config](/images/phase3.2/17-rbac-jadmin-creation.png)
![Jadmin Created](/images/phase3.2/18-rbac-jadmin-aduc.png)
![Jadmin Domain Admins](/images/phase3.2/19-rbac-jadmin-domain-admins.png)
![DC1 Login Screen](/images/phase3.2/20-rbac-jadmin-login-success.png)
*Account successfully elevated to the Domain Admins RBAC group and verified via domain login.*

---

## 4. Identity Redundancy: Secondary Domain Controller (DC1-DC-02)

**OS:** Windows Server 2019
**Role:** Secondary Domain Controller. Provides redundancy for AD and DNS. *(Reduces dependency on a single domain controller for authentication and DNS availability.)*

### Network Baseline & Domain Join
* **Network:** `PG-PROD_VLAN20`
* **IP Configuration:** `10.0.20.11`
* **DNS:** Primary set to `10.0.20.10` (DC1) to allow the VM to locate the `fort.internal` domain for joining.

![DC2 IPv4](/images/phase3.2/21-dc2-ipv4-config.png)
![DC2 Domain Join](/images/phase3.2/22-dc2-domain-join.png)

### AD DS Promotion
Installed the Active Directory Domain Services role and promoted the server as an additional domain controller in the existing domain. 

![DC2 Roles Features](/images/phase3.2/23-dc2-adds-role-select.png)
![DC2 Roles Finished](/images/phase3.2/24-dc2-adds-role-results.png)
![DC2 Review Options](/images/phase3.2/25-dc2-adds-promo-review.png)

### Redundancy Verification
Verified forward and reverse replication across the newly formed identity cluster using ADUC and DNS Manager.

![DC2 Verification](/images/phase3.2/26-dc2-verify-replication.png)

---

## 5. The File Server (DC1-FS-01)

**OS:** Windows Server 2019
**Role:** File Server. Hosts SMB network shares, controlled by Active Directory Group Policy.

### Template & Network Provisioning
![Deploy FS from Template](/images/phase3.2/27-fs1-template-deploy.png)
* **Network:** `10.0.20.20` | **DNS:** `10.0.20.10` (Primary) & `10.0.20.11` (Secondary - redundancy  validated).

![FS IPv4 Config](/images/phase3.2/28-fs1-ipv4-config.png)
![FS Domain Join](/images/phase3.2/29-fs1-domain-join.png)

### Storage Architecture & Role Installation
Added a dedicated 100GB secondary virtual disk (`E:` drive) and formatted it via Disk Management. *Enterprise Note: User shares are never placed on the OS `C:\` drive to prevent capacity-induced OS crashes.*

![Add Volume Config](/images/phase3.2/30-fs1-volume-config.png)

Installed **File Server** and **File Server Resource Manager (FSRM)** for future ransomware file-screening policies.

![FS Add Role Results](/images/phase3.2/31-fs1-role-results.png)

### Active Directory Tiering & SMB Share Execution
Moved the new File Server into the Tier 1 server Organizational Unit to prepare for targeted Group Policy application.

![FS OU Move](/images/phase3.2/32-fs1-ou-tiering.png)

Created `E:\Corporate_Data`. Share permissions were set to *Everyone - Full Control*, intentionally shifting strict access control delegation to the underlying NTFS security layers. 

> **Access Control Note:** Share-level permissions were left broad while enforcement is delegated to NTFS ACLs. Final access control will be implemented using AD security groups such as `SG-CorporateData-Read` and `SG-CorporateData-Modify`.

![Data Share Properties](/images/phase3.2/33-fs1-smb-share-permissions.png)

---

## 6. Segmented Backup Pipeline: Veeam VLAN 99 Migration

To reduce ransomware lateral-movement risk, the Veeam Backup server was kept outside the Active Directory domain and migrated into the dedicated Backup & Recovery VLAN. Firewall rules were limited to required backup, repository, and management paths.

### Network Migration
* **Port Group:** Moved `DC1-VEEAM-01` to `PG-BACKUP_VLAN99`.
* **IP Configuration:** `10.0.99.10/24` | **Gateway:** `10.0.99.1`
* **DNS:** `1.1.1.1` initially configured to avoid dependency on AD DNS during backup-isolation testing.

![Veeam IPv4](/images/phase3.2/34-veeam-ipv4-vlan99.png)
![Veeam Rename](/images/phase3.2/35-veeam-rename-pc.png)

### pfSense Backup VLAN Firewall Rules 
Implemented targeted firewall allow rules permitting Veeam to pull hypervisor data and write to the physical Unraid NAS, while blocking all inbound traffic from Production networks.

![pfSense Backup Rules](/images/phase3.2/36-veeam-pfsense-rules.png)
*Granular L4 firewall rules restricting Veeam traffic strictly to necessary API, NFC, and SMB ports.*

**OSI Layer 4 Validation:**
Before modifying the Veeam application configuration, network paths were validated at OSI Layer 4 using PowerShell:

```powershell
Test-NetConnection 192.168.0.10 -Port 445
Test-NetConnection 10.0.10.10 -Port 443
Test-NetConnection 10.0.10.11 -Port 902
```

All tests returned `TcpTestSucceeded: True`.

![Veeam PowerShell Verify](/images/phase3.2/37-veeam-l4-validation.png)

**Application Troubleshooting:**
During vCenter reconnection, Veeam reported a certificate-resolution error for the ESXi host. A targeted HTTPS rule was added from the Veeam server to the ESXi host to allow certificate validation and management-plane communication.

![Veeam Error](/images/phase3.2/38-veeam-cert-error.png)

### Infrastructure Baseline Backup
Established a new Active Full backup job for Phase 3.2.

* **Scope:** `DC1-DC-01`, `DC1-DC-02`, and `DC1-FS-01`.
* **Disk Exclusion:** Explicitly excluded SCSI 0:1 (the 100GB data drive) on `DC1-FS-01` to optimize storage and target only the OS baseline.

> **Data Protection Scope Note:** This Phase 3.2 backup job protects the operating system baselines for the domain controllers and file server. The file server data volume was intentionally excluded from this baseline job and will require a separate data-protection policy once NTFS ACLs, share structure, and retention requirements are finalized.

* **Application-Aware Processing:** Enabled with `FORT\da_jadmin` credentials to safely quiesce the Active Directory database during snapshots.

> **Credential Hardening Note:** `FORT\da_jadmin` was used during initial lab validation. A dedicated backup service account with the minimum required permissions will be created in a later hardening pass to reduce dependency on Domain Admin credentials.

![Veeam Job Created](/images/phase3.2/39-veeam-job-configured.png)
![Veeam Backup In Progress](/images/phase3.2/40-veeam-backup-success.png)

*Result: Successful block transfer to the off-host NAS repository. This backup establishes a recoverable baseline before additional GPO, NTFS ACL, and service-hardening changes are introduced.*
