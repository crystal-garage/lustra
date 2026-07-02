<p align="center"><img src="design/logo.png" alt="Lustra" height="200px"></p>

# Lustra

![Crystal CI](https://github.com/crystal-garage/lustra/workflows/Crystal%20CI/badge.svg)
[![GitHub release](https://img.shields.io/github/release/crystal-garage/lustra.svg)](https://github.com/crystal-garage/lustra/releases)
[![License](https://img.shields.io/github/license/crystal-garage/lustra.svg)](https://github.com/crystal-garage/lustra/blob/main/LICENSE)

Lustra is a PostgreSQL-focused ORM and SQL builder for Crystal.

It provides an Active Record style model layer, expressive query collections,
migrations, associations, validations, lifecycle callbacks, and direct access to
PostgreSQL features such as JSONB, arrays, CTEs, cursors, full-text search,
enums, UUIDs, and geometric types.

Lustra started as a fork of [Clear](https://github.com/anykeyh/clear) at version
0.8 and has since evolved as an independent project.

## Why Lustra?

Use Lustra when you want:

- PostgreSQL-first behavior instead of database-agnostic lowest-common-denominator APIs
- readable Active Record style models for application code
- a composable SQL builder for lower-level queries
- typed Crystal model fields with explicit nilability
- associations, eager loading, scopes, callbacks, validations, and migrations
- PostgreSQL-specific querying for JSONB, arrays, full-text search, CTEs, and more

Lustra is PostgreSQL-only. It is not designed for MySQL, MariaDB, or SQLite.

## Installation

Add Lustra to `shards.yml`:

```yaml
dependencies:
  lustra:
    github: crystal-garage/lustra
    version: ">= 0.18.1"
```

Require it in your application:

```crystal
require "lustra"
```

Initialize the database connection:

```crystal
Lustra::SQL.init("postgres://user:password@localhost/my_app")
```

For production applications, configure the connection pool explicitly:

```crystal
Lustra::SQL.init("postgres://user:password@localhost/my_app?max_pool_size=10&initial_pool_size=1&max_idle_pool_size=2&checkout_timeout=5")
```

Tune `max_pool_size` per running process and keep the total below PostgreSQL's
`max_connections`.

## Quick Start

Define a model:

```crystal
class User
  include Lustra::Model

  primary_key

  column email : String
  column first_name : String?

  timestamps
end
```

Create the table with a migration:

```crystal
class CreateUsers
  include Lustra::Migration

  def change(dir)
    create_table :users do |t|
      t.column :email, :string, null: false
      t.column :first_name, :string
      t.timestamps
    end
  end
end
```

Create, query, and update records:

```crystal
user = User.create!(email: "ada@example.com", first_name: "Ada")

found = User.query.find_by!(email: "ada@example.com")
found.first_name = "Ada Lovelace"
found.save!
```

## Querying

Lustra queries are model collections. They are chainable and execute when you
use terminal helpers such as `each`, `to_a`, `first`, `count`, or `exists?`.

```crystal
users = User.query
  .where(active: true)
  .order_by(created_at: :desc)
  .limit(20)
```

Associations can be joined by name:

```crystal
User.query.join(:posts).where { posts.published.true? }
```

Presence filters are available for association queries:

```crystal
User.query.where.associated(:posts)
User.query.where.missing(:posts)
```

Related-record counts can be selected without loading associated records:

```crystal
User.query.with_count(:posts)
Tag.query.with_count(:post_tags, alias_name: "tagging_count")
```

Eager loading avoids N+1 queries when reading associations:

```crystal
Post.query.with_user.each do |post|
  puts post.user.email
end
```

Collections are mutable. Use `dup` when branching from a reusable base query:

```crystal
base = User.query.where(active: true)
admins = base.dup.where(role: "admin")
editors = base.dup.where(role: "editor")
```

## Documentation

- Manual: https://crystal-garage.gitbook.io/lustra-docs/
- API documentation: https://crystal-garage.github.io/lustra/
- Releases: https://github.com/crystal-garage/lustra/releases

Start with the manual if you are new to Lustra. It covers model definitions,
associations, querying, migrations, PostgreSQL-specific features, and production
connection-pool setup.

## Development

Run the test suite:

```sh
crystal spec
```

Build the project:

```sh
shards build
```

## License

Lustra is released under the MIT License.
