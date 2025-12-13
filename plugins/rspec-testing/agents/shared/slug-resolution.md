# Slug Resolution

Standard mechanism for locating metadata files by slug.

## Slug Convention

Source file path → slug:

- Replace `/` with `_`
- Remove `.rb` extension

**Examples:**

| Source file | Slug |
|-------------|------|
| `app/services/payment.rb` | `app_services_payment` |
| `app/models/user.rb` | `app_models_user` |
| `lib/validators/email.rb` | `lib_validators_email` |
| `app/services/payments/processor.rb` | `app_services_payments_processor` |

## Resolution Algorithm

```
1. Read config: .claude/rspec-testing-config.yml
2. Extract: metadata_path (default: tmp)
3. Build path: {metadata_path}/rspec_metadata/{slug}.yml
```

**Pseudo-code:**

```ruby
config = read_yaml(".claude/rspec-testing-config.yml")
metadata_path = config["metadata_path"] || "tmp"
file_path = "#{metadata_path}/rspec_metadata/#{slug}.yml"
metadata = read_yaml(file_path)
```

## Error Handling

If metadata file not found:

```yaml
status: error
error: "Metadata file not found"
details: "Expected: {metadata_path}/rspec_metadata/{slug}.yml"
suggestion: "Run discovery-agent first to create metadata files"
```

Do NOT guess or derive data from slug — always read from metadata file.

## Who Creates Slugs

Slugs are created by discovery-agent when it creates metadata files. Downstream agents receive slug as input and resolve to metadata file using this algorithm.
