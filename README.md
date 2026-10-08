# Modern Driver Management (maintained fork)

This repository is a maintained fork of
[MSEndpointMgr/ModernDriverManagement](https://github.com/MSEndpointMgr/ModernDriverManagement),
preserving the upstream MIT license and attribution. It contains community
maintenance updates while remaining compatible with the upstream project.

For implementation instructions, please go to https://www.msendpointmgr.com/modern-driver-management

## Driver package scope

This is a Configuration Manager/task-sequence apply engine, not an Intune or
OEM vendor-catalog downloader. OEM and platform recognition is separate from
catalog acquisition: the script classifies Dell/Alienware, HP, Lenovo,
Microsoft Surface, Acer, ASUS, Fujitsu, Panasonic, Intel/NUC, Getac,
MSI/Micro-Star, GIGABYTE, Dynabook/Toshiba, and known hypervisors. Unlisted
physical OEMs use best-effort manufacturer/model matching.
Successful deployment still requires administrators to create or import packages
with matching metadata; the script does not acquire vendor catalogs for you. For
Getac, source and validate the applicable driver pack through Getac's published
support channels before creating or importing the matching package.

MSI/Micro-Star systems are normalized to package manufacturer `MSI`, GIGABYTE
systems to `GIGABYTE`, and Dynabook or Toshiba systems to `Dynabook`. These
additional OEMs intentionally use exact `Win32_ComputerSystem.Model` matching
without an assumed SystemSKU source. Create or import packages with that normalized
manufacturer and the model reported by the target hardware, then validate them in
`-DebugMode` before deployment. Dynabook's official Laptop Builder can produce PnP
driver packs suitable for direct Configuration Manager import:
https://support.dynabook.com/support/navShell?cf=laptop-builder

This recognition does not scrape vendor download sites, discover MSI or GIGABYTE
catalogs, run MSI Center, GIGABYTE Control Center, `@BIOS`, or M-FLASH, guess
installer switches, or perform firmware updates. Package content and any
vendor-specific installation command remain separately governed; no vendor
installer command is supplied or executed by this change. This script's supported
driver path applies validated INF content with Windows tooling.

## Windows ADK and WinPE compatibility

Recognizing a Windows release in this script does not certify every Configuration
Manager, Windows ADK, or WinPE combination for that release. For Windows 11 26H2,
Microsoft's current ADK documentation lists the serviced `10.1.26100.9457` kit,
and Configuration Manager supports the `10.1.26100.x` ADK family. Configuration
Manager 2509 does not support Windows 11 26H2 clients; use 2603 or later. Microsoft lists
ADK `10.1.28000.1` specifically for Windows 11 26H1 Arm64, but currently marks it
unsupported with Configuration Manager 2509, 2603, and 2609. Check the current
[Windows ADK download guidance](https://learn.microsoft.com/windows-hardware/get-started/adk-install)
and
[Configuration Manager ADK support matrix](https://learn.microsoft.com/intune/configmgr/core/plan-design/configs/support-for-windows-adk)
before updating a boot image. Re-download the current ADK installer when Microsoft
replaces a release and apply the latest
[ADK servicing update](https://learn.microsoft.com/windows-hardware/get-started/adk-servicing);
the ADK download page identifies current security fixes and prerequisites.

The WinPE boot image must include the optional components required by this script,
including WinPE-WMI and WinPE-PowerShell with their dependencies. Configuration
Manager 2403 or later and ADK `10.1.26100.x` or later are required for supported
Arm64 operating-system deployment. Modern ADKs do not include an x86 WinPE image.
Windows 11 26H1 is a specialized new-hardware release, not a general in-place-upgrade
target for existing Windows 11 devices.

## Virtual machines

`Invoke-CMApplyDriverPackage.ps1` blocks detected virtual machines by default. Use
`-AllowVirtualMachine` to opt in to virtual-machine driver package deployment.
VMware platform detection uses the case-insensitive `VMware*` wildcard, recognizing
`VMware Virtual Platform`, `VMware7,1`, `VMware 7,1`, and future VMware-prefixed
model strings without requiring a new entry for each model.
These identifiers are not treated as VMware virtual hardware version numbers.
Hyper-V detection requires the exact model `Virtual Machine` together with a
manufacturer containing `Microsoft`. These fields do not infer VM firmware or
generation. The generic model alone is not treated as Hyper-V.

Parallels is recognized when either the model or manufacturer contains `Parallels`.
Nutanix AHV is recognized when either field contains `Nutanix`; if
`Win32_ComputerSystem` exposes a blank manufacturer, the script checks
`MS_SystemInformation.SystemManufacturer`. Nutanix package matching uses the
reported `SystemProductName` and `SystemSKU` when available and never substitutes
a hard-coded AHV version.

VirtualBox is recognized by the exact model `VirtualBox`, including guests reporting
`innotek GmbH` or `Oracle Corporation` as manufacturer. QEMU/KVM detection recognizes
models containing `KVM`, or a manufacturer containing `QEMU`. A `Standard PC` model
also requires a manufacturer containing `QEMU` or `Red Hat`.
A Red Hat manufacturer is accepted when the model also contains `Virtual Machine`,
rather than treating every Red Hat system as a VM. Xen/Citrix detection recognizes
`HVM domU` and models or manufacturers containing `Xen` or `Citrix` before the
QEMU/KVM and physical OEM checks. The `Hypervisor-XenCitrix` label identifies the
family, not a specific host product. Virtual package labels include `Citrix`,
`Xen`, `XenServer`, `XenEnterprise`, `Parallels`, `Nutanix`, and `AHV`.
The platform, manufacturer, and model are logged.

Platform detection is a best-effort SMBIOS heuristic. Hypervisors can override the
manufacturer and product strings exposed to the guest, and vendor documentation does
not define these values as a stable cross-version detection API. Customized values
can therefore produce `Physical-Unknown`; use the log and `-DebugMode` to validate
new environments before deployment.

QEMU/KVM identification does not distinguish Proxmox from other QEMU/KVM hosts or
infer firmware/chipset from a model string. The script deploys matching INF driver
packages; it does not automatically run VMware Tools, Parallels Tools, Nutanix
Guest Tools, VirtualBox Guest Additions, or other guest-tools installers based
solely on platform detection.

Physical OEM classification runs only after hypervisor detection. Logged labels
cover Dell, Alienware, HP/Hewlett-Packard, Lenovo, Fujitsu, Panasonic, ASUS/ASUSTeK,
Acer, Intel (including NUC models), Microsoft Surface, MSI/Micro-Star, GIGABYTE,
and Dynabook/Toshiba. Surface requires both a Microsoft manufacturer and a model
containing `Surface`. Unlisted brands are logged as `Physical-Unknown` and still use
the existing manufacturer/model package matching.
OEM labels are informational: they do not replace manufacturer normalization, SKU
detection, or package validation, and do not trigger vendor tools or MSI installers.
Panasonic systems are normalized to `Panasonic` to match packages created by Driver
Automation Tool.

## Virtual-machine servicing boundaries

`-AllowVirtualMachine` permits only explicitly labelled virtual-hardware driver
packages to pass the normal package-selection and INF deployment workflow. This
supports packages such as extracted VirtIO, VMXNET, PVSCSI, and Xen drivers. It
does not install or update VMware Tools, VirtualBox Guest Additions, Citrix VM
Tools, Parallels Tools, Nutanix Guest Tools, or other integration-suite
installers. Hyper-V integration components for supported Windows guests are
serviced by Windows.

Secure Boot certificate rotation is also outside this script's scope. The 2026
Microsoft Secure Boot certificate transition changes UEFI PK, KEK, DB, and boot
manager trust state; it is not a driver-package operation. Remediation differs by
hypervisor, VM hardware version, Secure Boot state, vTPM state, guest operating
system, and host patch level. Follow Microsoft's
[Secure Boot certificate updates guidance](https://support.microsoft.com/en-us/servicing/os/secure-boot/2025/06/secure-boot-certificate-updates-guidance-for-it-professionals-and-organizations)
and the hypervisor vendor's current guidance. Do not modify virtual NVRAM,
replace platform keys, or infer readiness from the platform label produced by
this script. Use Microsoft's supported fleet inventory and event-based monitoring
rather than treating a simple certificate-name string search as a complete
readiness test.

Existing manufacturer, exact model, Windows version, and architecture matching
rules still apply. Packages must also be explicitly labelled for virtual hardware
in their name, description, or manufacturer. Detection of another numbered VMware
model does not make packages for `VMware7,1` interchangeable with it. DebugMode
permits detection on virtual machines without downloading or installing drivers.

Use separately approved profiles or sources for OEM model packages, component
supplements, WinPE drivers, and offline or recovery content. Administrators must
validate and import third-party content through a controlled content-management
process; this script does not discover or trust external sources automatically.

XML deployments accept `OSUpgrade`; the existing `OSUpdate` value is an alias that
also stages content for Windows Setup. Missing XML package files stop execution.
SystemSKU lists support comma, semicolon, and whitespace separators and match
complete tokens, not substrings or regular expressions. Arm64 is recognized in
fallback packages as well as regular packages. DriverUpdate logs PnPUtil output
to `Install-Drivers.txt`, accepts 0 and the standard Windows reboot-required code
3010, and stops on other failures instead of reporting success. Microsoft documents
the PnPUtil command syntax but does not publish a PnPUtil-specific exit-code table.
PreCache downloads compressed content without expanding it. WIM packages are
dismounted immediately after extraction so recursive DISM processing sees one copy
of each driver, and bare-metal DISM output is retained as `DISM.log` with the task
sequence logs. Packages containing multiple `DriverPackage.*` archives or an
unsupported archive type fail closed. XML package logic is parsed with DTD processing
and external entity resolution disabled.

## AdminService authentication security

The script does not install or update PowerShell Gallery modules during deployment.
External AdminService/CMG authentication uses the existing `MDMTenantName`,
`MDMClientID`, `MDMApplicationIDURI`, `MDMUserName`, and `MDMPassword` values to
request an OAuth token directly from the Microsoft identity platform. This
non-interactive resource-owner-password flow requires an account and tenant policy
that permit it; accounts requiring MFA or passwordless authentication are not
compatible with that legacy flow. Microsoft recommends migrating unattended
workloads to a service principal with a certificate credential where the target
API supports app-only access; review the current
[ROPC limitations and migration guidance](https://learn.microsoft.com/entra/identity-platform/v2-oauth-ropc).

For internal AdminService authentication, the configured user name is attempted
first. If it receives `401 Unauthorized`, the script can retry inferred UPN and
down-level domain-qualified forms. This is compatibility handling for environments
that reject a bare account name, not a Microsoft-documented ConfigMgr 2603
UPN-only requirement. Prefer an explicit UPN to avoid ambiguous domain inference,
and validate the account format and policy in your own site.

Internal AdminService TLS validation fails closed. The preferred configuration is
to trust the certificate's issuing CA in the full operating system and WinPE boot
image. When an internal AdminService intentionally uses a self-signed certificate,
set `MDMAdminServiceCertificateThumbprint` to the exact 40-character SHA-1
thumbprint of the leaf certificate, or pass
`-AdminServiceCertificateThumbprint`. The pin permits only chain-trust errors for
that certificate, never hostname mismatches, and is removed immediately after the
retry. Do not use a thumbprint copied from an untrusted connection.