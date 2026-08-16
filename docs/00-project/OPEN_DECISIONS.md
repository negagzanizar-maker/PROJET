# Open Decisions and Required Metadata

These items are intentionally visible so the implementation and French report do not invent facts. None of the identity/report metadata blocks early engineering work; explicit placeholders will be used until supplied.

## Report and identity metadata

| ID | Information needed | Current state |
|---|---|---|
| META-001 | Official project/product name | Open; working title in use |
| META-002 | Student's full name | Open |
| META-003 | School/university, program, and academic year | Open |
| META-004 | Host organization name, description, and approved logo | Open |
| META-005 | Academic supervisor name/title | Open |
| META-006 | Company supervisor name/title | Open |
| META-007 | Internship start/end dates and report deadline | Open |
| META-008 | Required cover-page/template rules from the institution | Open |
| META-009 | Approved acknowledgements and confidentiality constraints | Open |

## Product and deployment decisions

| ID | Decision | Recommended baseline | Blocking point |
|---|---|---|---|
| DEC-001 | Production hosting/provider | Linux host with public DNS and TLS | Before Goal 10 production deployment |
| DEC-002 | Public domains | Separate admin and device API hostnames | Before external integration testing |
| DEC-003 | Transactional email provider | SMTP/API provider with sandbox environment | Before invitation/reset end-to-end tests |
| DEC-004 | Production object storage | Private S3-compatible service | Before production content deployment |
| DEC-005 | Malware scanning engine | ClamAV-compatible isolated scanner | Before secure-upload gate |
| DEC-006 | Expected tenants/devices and heartbeat load | Obtain supervisor's target; test above it | Before load-test acceptance is frozen |
| DEC-007 | Maximum media sizes | Image 20 MiB, text 256 KiB, video 2 GiB as provisional limits | Before content API implementation |
| DEC-008 | Supported video codecs | MP4 with H.264 video and AAC audio | Confirm on target Pi/monitor hardware |
| DEC-009 | Schedule timezone model | One-time UTC bounds; tenant IANA timezone for input/presentation; no recurring v1 rules | Accepted baseline; revisit only by ADR |
| DEC-010 | User-facing languages | French-first administration UI; report remains French | Before UX copy is finalized |
| DEC-011 | Branding and visual identity | Accessible neutral design until supplied | Before visual acceptance |
| DEC-012 | Fleet OS/update ownership | Platform operator controls OS image and agent updates | Before operational handover |

## Security limitation requiring explicit acceptance

An ordinary Raspberry Pi does not provide a trustworthy defence against a person who has sustained physical access and root control. Such a person can modify the player, alter the agent, or extract software-held credentials. The approved baseline treats the Pi as a managed appliance without customer root access. Stronger resistance would require hardware-backed keys, measured/secure boot, physical controls, and a separately costed threat model.

## Decision procedure

Architecture-changing decisions receive an Architecture Decision Record. Smaller operational decisions are dated and recorded here. A decision is not silently inferred from an implementation convenience.
