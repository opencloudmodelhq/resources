# OpenCloudModel Resources

A vendor-neutral mapping of cloud resource concepts to the Terraform resource types and attributes of
AWS, Azure and Google Cloud.

One row holds one neutral concept and its counterpart at each of the three vendors. The mapping is built by
hand, a few concepts at a time, and every placement cites the source it was checked against.

## Files

| File | Content |
|---|---|
| `data/mapping.csv` | The dataset. Verified rows only. |
| `data/providers.csv` | Terraform provider versions the references were checked against. |
| `PROTOCOL.md` | The rules by which rows are placed, graded and named. |

## Columns

| Column | Meaning |
|---|---|
| `concept_id` | Stable identifier of the neutral concept. Never reused. |
| `domain` | Subject area of the concept. |
| `concept` | Vendor-neutral name. |
| `definition` | One-sentence definition of the concept. |
| `<vendor>_term` | The vendor's own name for the concept. |
| `<vendor>_ref` | Terraform resource type, or `resource.block.argument` when the concept is an attribute. Several references are separated by `;`. Empty when the vendor has no counterpart. |
| `<vendor>_match` | `equivalent`, `close`, `partial`, or `none` when the vendor has no counterpart. |
| `<vendor>_source` | URL of the primary source the placement was checked against. For `none`, the source searched. |
| `verified_on` | Date the row was verified, `YYYY-MM-DD`. |
| `protocol_version` | Version of the placement protocol applied. |
| `note` | Scope differences and other remarks. |

`<vendor>` is `aws`, `azure` or `gcp`. A reference that contains a dot is an attribute placement.

## Status of the data

`data/mapping.csv` holds only rows a person has verified against cited sources.
It grows over time; the commit history is the record of when each concept was decided.

## Adding a row

1. Choose a concept and write its definition.
2. Find its counterpart at each vendor in the documentation and the provider schema.
3. Record term, reference, match grade and source for each vendor, or `none` with the source searched.
4. Fill `verified_on` and `protocol_version`, then commit.

## Use in Terraform

The Terraform provider reads `data/mapping.csv` at a tagged release.

## Citation and licence

See `CITATION.cff`. Data and documents are licensed CC BY 4.0, configuration files Apache 2.0; `REUSE.toml`
lists which applies to each file.
