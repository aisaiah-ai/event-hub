# Schema Evolution

Event Hub uses a **dynamic registration schema** stored in Firestore. The schema can evolve over time without code migrations.

## Location

`events/{eventId}/schemas/registration`

## Schema Structure

- **version** (int): Incremented on each save
- **updatedAt** (timestamp): Last modified
- **fields** (array): Field definitions
- **roleOverrides** (map): ADMIN/STAFF validation overrides

## Evolving the Schema

### Adding a Field

1. Open Admin → Schema Editor
2. Click "Add Field"
3. Set key, label, type, required, options
4. Save

Existing registrants will have `null` for the new field. Forms will show it as empty.

### Removing a Field

1. Open Schema Editor
2. Delete the field (only if not locked)

**Warning:** Data in `answers` or `profile` is not deleted. Old values remain in Firestore but are no longer displayed.

### Making a Field Required

If registrants already exist with empty values:

1. Schema Editor shows a confirmation
2. Existing records get `flags.hasValidationWarnings = true` and `flags.validationWarnings` populated when edited

### Locked Fields

Fields with `locked: true` cannot be removed. Use for system-critical fields.

### Formation Tags

Set `formation.tags` on a field to include its values in formation signals when populated. Tags are derived automatically on check-in and registrant update.

## Best Practices

1. **Version on save**: Schema version increments automatically
2. **Preview before save**: Use the Schema Editor preview to verify forms
3. **Avoid breaking renames**: Prefer adding a new field and migrating data rather than renaming
