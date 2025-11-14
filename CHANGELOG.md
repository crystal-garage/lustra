# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- **PostgreSQL Geometric Types** - Comprehensive support for all PostgreSQL geometric data types:
  - Point, Circle, Polygon, Box, Line, Path, LineSegment support through crystal-pg
  - Expression engine with natural syntax for spatial queries
  - Distance, containment, overlap, intersection, and positioning operations
  - Complete test coverage with 11 comprehensive test scenarios
  - Real-world examples including store locator and spatial analysis

## [v0.12.0] - 2025-10-13
### Added
- ✅ `update_all` - Bulk updates without loading models (bypasses validations and callbacks)
- ✅ `find_by` / `find_by!` - Convenient finder methods for ActiveRecord-style querying
- ✅ `find([ids])` - Multiple ID lookup with array of IDs
- ✅ `increment!` / `decrement!` - Atomic counter updates for thread-safe operations
- ✅ `update_column` / `update_columns` - Direct column updates without validations/callbacks
- ✅ `touch` - Update timestamps without running validations/callbacks
- ✅ `destroy` / `destroy_all` - Rails-compatible deletion with callbacks
- ✅ `default_scope` - Automatically apply filters to all queries (soft deletes, multi-tenancy)
- ✅ `query.unscoped` - Bypass default_scope when needed
- ✅ Attribute change tracking - `column.change`, `changes`, `changed` for auditing
- ✅ `ids` - Convenient shortcut for getting array of primary keys
- ✅ `explain` / `explain_analyze` - PostgreSQL query performance analysis

### Changed
- **BREAKING:** `delete` now skips callbacks (fast deletion)
- **BREAKING:** `destroy` triggers callbacks (safe deletion)
- **BREAKING:** Callback event renamed: `:delete` → `:destroy`
- Use `before(:destroy)` and `after(:destroy)` instead of `before(:delete)` and `after(:delete)`

### Dedication
- In memory of cat Sviatoslav (26.04.2023 - 13.10.2025) 💔😿

## [v0.11.0] - 2025-10-09
### Changed
- **BREAKING:** `or_where` → `where.or` - Improved chaining syntax for OR conditions
- More consistent query builder API

## [v0.10.1] - 2025-10-09
### Fixed
- Fix model without primary_key support
- Improved handling of models that don't have primary keys defined

## [v0.10.0] - 2025-10-08
### Added
- Handle append_operation for has_many through relationships
- Prevent duplicate associations in relationships
- Join a relation using association name (auto-joins)
- Autosave functionality for associated models

### Improved
- Better association handling and relationship management
- Enhanced join operations with automatic detection

## [v0.9.0] - 2025-10-06
### Added
- Test callbacks implementation
- Counter cache functionality for associations
- Improved supported features documentation

### Changed
- **BREAKING:** Clear → Lustra - Complete rebranding from Clear to Lustra
- Removed Kemal CLI generator (no longer supported)
- Enhanced join SQL construction with better specs

### Improved
- Better callback system with comprehensive testing
- Enhanced association features

## [v0.8.24] - 2025-09-26
### Added
- Touch functionality for belongs_to associations
- Automatic timestamp updates when parent records change

### Dependencies
- Bump actions/checkout from 4 to 5

## [v0.8.23] - 2025-06-09
### Maintenance
- Internal improvements and optimizations

## [v0.8.22] - 2025-06-09
### Maintenance
- Internal improvements and optimizations

## [v0.8.21] - 2025-01-13
### Changed
- Use `do`...`end` instead of curly brackets for multi-line blocks
- Cosmetic code style improvements

### Fixed
- Fix Collection#each method functionality

## [v0.8.20] - 2024-11-05
### Dependencies
- Use crystal-pg 0.29.0
- Use `::sleep(Time::Span)` instead of deprecated sleep methods

## [v0.8.19] - 2024-04-18
### Fixed
- Fix nested module support
- Better handling of nested Crystal modules

## [v0.8.18] - 2024-01-12
### Dependencies
- Bump actions/checkout from 2 to 4
- Bump crazy-max/ghaction-github-pages from 2 to 3
- Bump crazy-max/ghaction-github-pages from 3 to 4

### Contributors
- First contribution from @dependabot

## [v0.8.17] - 2023-06-25
### Dependencies
- Use crystal-pg 0.27.0

## [v0.8.16] - 2023-06-25
### Fixed
- Fix specs implementation
- Fix migrations functionality

## [v0.8.15] - 2022-11-28
### Added
- Add Collection#find with parameters
- Enhanced collection querying capabilities

## [v0.8.14] - 2022-11-27
### Maintenance
- Internal improvements

## [v0.8.13] - 2022-11-12
### Code Quality
- Avoid using `not_nil!` for better null safety
- Add comprehensive specs
- Refactoring (Second round) - major code improvements
- Refactor relations system

## [v0.8.12] - 2022-11-08
### Maintenance
- Version bump and internal improvements

## [v0.8.11] - 2022-10-10
### Maintenance
- Internal improvements and optimizations

## [v0.8.10] - 2022-06-21
### Maintenance
- Internal improvements and optimizations

## [v0.8.9] - 2022-01-27
### Dependencies
- Bump PostgreSQL dependency version

## [v0.8.8] - 2022-01-07
### Added
- Support Crystal 1.3 compatibility
- Updated for latest Crystal language features

## [v0.8.7] - 2021-10-14
### Maintenance
- Internal improvements and optimizations

## [v0.8.6] - 2021-09-09
### Maintenance
- Internal improvements and optimizations

## [v0.8.5] - 2021-07-18
### Maintenance
- Internal improvements and optimizations

## [v0.8.4] - 2021-06-28
### Maintenance
- Internal improvements and optimizations

## [v0.8.2] - 2021-03-23
### Maintenance
- Internal improvements and optimizations

## [v0.8.1] - 2021-02-16 - "Fork"
### Added
- Initial fork from Clear ORM
- GitHub workflow implementation
- CI/CD pipeline setup
- PostgreSQL client integration

### Infrastructure
- Add GitHub Actions workflow
- Code formatting standards
- Database connection setup
- Remove Travis CI configuration
- Initial project cleanup

### Notes
- This marks the beginning of Lustra as an independent project, forked from Clear v0.8
- Established foundation for future development and Crystal compatibility

---

## Release Links

- [v0.12.0](https://github.com/crystal-garage/lustra/releases/tag/v0.12.0)
- [v0.11.0](https://github.com/crystal-garage/lustra/releases/tag/v0.11.0)
- [v0.10.1](https://github.com/crystal-garage/lustra/releases/tag/v0.10.1)
- [v0.10.0](https://github.com/crystal-garage/lustra/releases/tag/v0.10.0)
- [v0.9.0](https://github.com/crystal-garage/lustra/releases/tag/v0.9.0)
- [v0.8.24](https://github.com/crystal-garage/lustra/releases/tag/v0.8.24)
- [v0.8.23](https://github.com/crystal-garage/lustra/releases/tag/v0.8.23)
- [v0.8.22](https://github.com/crystal-garage/lustra/releases/tag/v0.8.22)
- [v0.8.21](https://github.com/crystal-garage/lustra/releases/tag/v0.8.21)
- [v0.8.20](https://github.com/crystal-garage/lustra/releases/tag/v0.8.20)
- [v0.8.19](https://github.com/crystal-garage/lustra/releases/tag/v0.8.19)
- [v0.8.18](https://github.com/crystal-garage/lustra/releases/tag/v0.8.18)
- [v0.8.17](https://github.com/crystal-garage/lustra/releases/tag/v0.8.17)
- [v0.8.16](https://github.com/crystal-garage/lustra/releases/tag/v0.8.16)
- [v0.8.15](https://github.com/crystal-garage/lustra/releases/tag/v0.8.15)
- [v0.8.14](https://github.com/crystal-garage/lustra/releases/tag/v0.8.14)
- [v0.8.13](https://github.com/crystal-garage/lustra/releases/tag/v0.8.13)
- [v0.8.12](https://github.com/crystal-garage/lustra/releases/tag/v0.8.12)
- [v0.8.11](https://github.com/crystal-garage/lustra/releases/tag/v0.8.11)
- [v0.8.10](https://github.com/crystal-garage/lustra/releases/tag/v0.8.10)
- [v0.8.9](https://github.com/crystal-garage/lustra/releases/tag/v0.8.9)
- [v0.8.8](https://github.com/crystal-garage/lustra/releases/tag/v0.8.8)
- [v0.8.7](https://github.com/crystal-garage/lustra/releases/tag/v0.8.7)
- [v0.8.6](https://github.com/crystal-garage/lustra/releases/tag/v0.8.6)
- [v0.8.5](https://github.com/crystal-garage/lustra/releases/tag/v0.8.5)
- [v0.8.4](https://github.com/crystal-garage/lustra/releases/tag/v0.8.4)
- [v0.8.2](https://github.com/crystal-garage/lustra/releases/tag/v0.8.2)
- [v0.8.1](https://github.com/crystal-garage/lustra/releases/tag/v0.8.1)
