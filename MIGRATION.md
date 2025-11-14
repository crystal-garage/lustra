# Migrating from Clear to Lustra

This guide will help you migrate your application from Clear ORM to Lustra ORM.

## Overview

Lustra is a fork of Clear ORM with significant architectural improvements, including Rails-like associations, better query building, and enhanced model features. While many concepts remain similar, there are important changes that require careful migration.

## Step 1: Update Dependencies

### Replace Clear with Lustra in `shards.yml`
```diff
dependencies:
-  clear:
-    github: crystal-garage/clear
+  lustra:
+    github: crystal-garage/lustra

```

### Update Imports
Replace all Clear imports with Lustra:

```crystal
# Before (Clear)
require "clear"
require "clear/sql"
require "clear/model"

# After (Lustra)
require "lustra"
require "lustra/sql"
require "lustra/model"
```

## Step 2: Database Metadata Migration

### Clear Metadata Table
```sql
-- Clear uses this table
__clear_metadatas
```

### Lustra Metadata Table
```sql
-- Lustra uses this table
__lustra_metadatas
```

### Migration Strategy

Simply rename the Clear metadata table to Lustra format:

```sql
-- Rename the metadata table
ALTER TABLE __clear_metadatas RENAME TO __lustra_metadatas;
```

That's it! This preserves all your existing migration history without any data loss.

## Step 3: Namespace Migration

The main change is replacing all `Clear::*` references with `Lustra::*`:

### Common Replacements
- `Clear::Model` -> `Lustra::Model`
- `Clear::Migration` -> `Lustra::Migration`
- `Clear::SQL` -> `Lustra::SQL`
- `Clear::Connection` -> `Lustra::Connection`

### Migration Commands
```bash
# Before (Clear)
clear-cli db:migrate
clear-cli db:rollback
clear-cli migration:generate create_users

# After (Lustra)
lustra-cli db:migrate
lustra-cli db:rollback
lustra-cli migration:generate create_users
```
