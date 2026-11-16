# Placement protocol

Version 0.1 (frozen 2026-11-16).

This document states the rules by which rows are added to `data/mapping.csv`. A row is valid only if it was
made under a frozen version of this protocol, and it records that version in `protocol_version`.

## 1. Purpose

To give each kind of deployable cloud resource one vendor-neutral name and definition, and to record where that
kind appears at AWS, Azure and Google Cloud: as a Terraform resource type, as an attribute of one, or not at all.

Not covered: pricing, service levels, regional availability, runtime behaviour.

## 2. Scope

### 2.1 Vendors and versions

The providers and versions in `data/providers.csv`. A provider upgrade is its own commit and may raise the
protocol version.

### 2.2 Domains

The first domains, in order: Compute, Storage, Networking, DNS.
Other domains follow later and are not part of version 0.1.

### 2.3 Eligible resource types

A resource type is eligible when all are true:

1. It is a managed resource in the pinned provider schema, not a data source.
2. The vendor's documentation places it in an included domain.
3. The schema does not mark it deprecated.

### 2.4 Excluded types

- Types that exist only to grant access to one other resource (per-resource IAM bindings, members, policies).
- Types from preview-only providers.
- Aliases of another type: keep one, name the alias in `note`.

Association types (attachments, associations, bindings between two resources) are **included**. See 4.4.

## 3. Sources

### 3.1 Permitted

| Source                                                      | Used for                        |
| ----------------------------------------------------------- | ------------------------------- |
| Provider schema at the pinned version                       | Which types and arguments exist |
| Terraform registry page for the type, at the pinned version | What the resource is            |
| Vendor product documentation                                | Definition and behaviour        |

### 3.2 Order

Where sources disagree on what a resource is, vendor product documentation decides. Where they disagree on
arguments, the schema decides.

### 3.3 Not consulted while placing

- Vendor comparison pages ("service X for users of vendor Y").
- Third-party multi-cloud models such as Apache Libcloud and Cartography.
- AI assistants, for any placement, grade, name or definition.

## 4. Concepts

### 4.1 What a concept is

A kind of thing a customer can create, configure and delete through a vendor's control plane, described
without reference to any vendor's name for it.

### 4.2 Identity test

A vendor resource belongs to a concept when, measured against the concept's definition, the answer to each
question is yes:

1. **Function.** Does it do the job the definition describes?
2. **Position.** Does it sit at the place in the structure the definition implies: same kind of owner, same
   kind of contents?
3. **Lifecycle.** Is it created and deleted as one thing of that kind?
4. **Substitution.** In a typical deployment, would it stand in for the concept, and nothing smaller or larger?

The test is applied to every vendor in the same way, including the vendor that leads the domain (7.1).

### 4.3 Merging and splitting

- **Several types of one vendor in one row** when the vendor splits one kind by a side property (operating
  system, regional or global). List all in `<vendor>_ref`, separated by `;`, and name the property in `note`.
- **One type in more than one row** only when an argument of that type selects clearly different roles. Name
  the argument in `note` of each row.
- **Too fine:** a distinction that exists at one vendor only and is an argument value there. Merge.
- **Too coarse:** members that fail question 2 or 3 against each other. Split.

### 4.4 Association objects

A type whose only purpose is to join two other resources is a concept of its own and gets a row.
Where a vendor expresses the same join as an argument on one of the two resources, that is an attribute
placement (section 5).

### 4.5 Settings

A setting gets a row when at least one of the three vendors offers it as a separate
resource type. At the other vendors it is then an attribute placement. A setting that is an argument at all
three vendors gets no row.

### 4.6 Minimum presence

A concept is included when at least two of the three vendors have it at grade
`partial` or better. Concepts found at one vendor only are not added.

## 5. Placement

### 5.1 Resource or attribute

A concept is a **resource** placement at a vendor when a resource type represents it. It is an **attribute**
placement when no type of its own exists there and an argument or nested block of another resource sets it.

### 5.2 Notation

- Resource: the type name, for example `aws_subnet`.
- Attribute: `type.block.argument`, using schema names exactly. A reference containing a dot is an attribute.
- Several references in one cell are separated by `;`, the primary one first.
- Arguments that are computed only (cannot be set) are not valid references.

### 5.3 Grades

Each vendor is graded against the neutral concept's definition by the identity test (4.2), not against the
other vendors.

| Grade        | Rule                                                                 |
| ------------ | -------------------------------------------------------------------- |
| `equivalent` | All four identity questions yes                                      |
| `close`      | Function yes; exactly one of position, lifecycle, substitution no    |
| `partial`    | Function yes; two or more of the others no. State the gaps in `note` |
| `none`       | No counterpart. Reference and term empty                             |

### 5.4 Recording `none`

`none` is recorded only after:

1. searching the provider's resource list for the function under at least three different terms,
2. checking the documentation index of the domain,
3. checking whether an argument of another resource carries it.

`<vendor>_source` then holds the page searched. The terms searched go in `note`.

## 6. Naming and definitions

### 6.1 Concept name

Singular noun phrase in title case. No vendor product names. No abbreviations except those that are the
common term (DNS, NAT, VPN). Prefer the term most vendors use; if all differ, a descriptive phrase.

### 6.2 Definition

One sentence of the form "A [broader kind] that [what sets it apart]." Written in the author's own words,
not copied from a vendor or a standard.

### 6.3 Vendor term

The name the vendor's documentation uses for the concept, as written there.

### 6.4 Identifier

`concept_id` is `C` followed by four digits, assigned in order of creation. An identifier is never reused or
renumbered. A concept that is withdrawn keeps its row, with the reason in `note`.

## 7. Procedure

### 7.1 Order of work

One domain at a time. Within a domain:

1. List the eligible types of each vendor from the schema.
2. Take one type, or a small group of related types, from the vendor that leads the domain.
3. Read its registry page and product documentation. Write the definition.
4. Find the counterpart at each of the other two vendors. Apply the identity test. Grade.
5. For a vendor with no resource type, look for an attribute placement before recording `none`.
6. Fill the row and commit.

The leading vendor rotates by domain, so that no single vendor's model shapes every concept.

| Domain | Leading vendor |
|---|---|
| Compute | AWS |
| Storage | Azure |
| Networking | Google Cloud |
| DNS | AWS |

A domain added later takes the next vendor in the order AWS, Azure, Google Cloud.

### 7.2 When unsure

Decide, and say so in `note`, with the alternative that was considered. Do not leave a row half filled.

### 7.3 Changing a row

A row may be corrected at any time. The correction is its own commit, and the message says what changed and
why. `verified_on` takes the date of the correction.

## 8. Relations and taxonomy

Not part of version 0.1. When all concepts of a domain are placed, "is a kind of" links and relations between
its concepts are added in a separate file under a later protocol version.

## 9. Versions and freezing

- The protocol is frozen by tagging the commit that sets its version line to "frozen".
- Any change to a rule after freezing raises the version. Rows keep the version they were made under.
- Departures from a frozen rule are recorded in section 11, not hidden.

## 10. Disclosure

- An AI assistant drafted this protocol; the author reviewed and revised it before freezing.
- No AI assistant is used for placements, grades, names or definitions (3.3).
- An AI assistant prepared the repository structure and the checks that run on each commit.

## 11. Deviations

| Date | Section | What was done differently | Why |
| ---- | ------- | ------------------------- | --- |
|      |         |                           |     |
