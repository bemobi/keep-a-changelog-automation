# Scripts Documentation

Automation scripts for version management and changelog generation.

## Scripts Overview

### 1. `bump-version.sh` - Version Bumping

Calculates the next version based on the latest git tag.

**Usage:**
```bash
./scripts/bump-version.sh <major|minor|patch>
```

**Examples:**
```bash
# Calculate next patch version (1.2.3 -> 1.2.4)
./scripts/bump-version.sh patch

# Calculate next minor version (1.2.3 -> 1.3.0)
./scripts/bump-version.sh minor

# Calculate next major version (1.2.3 -> 2.0.0)
./scripts/bump-version.sh major
```

**Output:** Returns the new version number

---

### 2. `update-changelog.sh` - Changelog Management

Automates CHANGELOG.md updates based on git commits.

**Usage:**

With version (creates/updates tag):
```bash
./scripts/update-changelog.sh <version>
```

Without version (updates [Unreleased]):
```bash
./scripts/update-changelog.sh
```

**Examples:**
```bash
# Add version 2.8.0 to changelog
./scripts/update-changelog.sh 2.8.0

# Update [Unreleased] section only
./scripts/update-changelog.sh
```

## Features

### Three Operating Modes

#### Mode 1: No arguments - Updates [Unreleased]
```bash
./scripts/update-changelog.sh
```
- Adds commits since last tag to `[Unreleased]` section
- Generates full history if CHANGELOG doesn't exist
- Useful during development to keep changelog updated

#### Mode 2: CHANGELOG doesn't exist - Generates full history
```bash
./scripts/update-changelog.sh 2.8.0
```
- Reads **all existing tags** from repository
- Generates complete changelog with full version history
- Adds the provided new version
- Automatically detects issues for each version

#### Mode 3: CHANGELOG exists - Adds new version
```bash
./scripts/update-changelog.sh 2.8.0
```
- Moves `[Unreleased]` content to new version
- Clears `[Unreleased]` for future commits
- Updates comparison links
- Keeps previous history intact

### Jira Issue Detection (Enhanced)

The script uses cascading detection, searching for issues in multiple sources:

**Search order:**
1. **Current branch name**: `feature/FS-2039-description`, `fix/RT-18-bug`
2. **Commit messages**: `feat: [FS-2039] add feature`, `fix: RT-18: fix bug`, `DEVOPS-456: update`
3. **Tag name** (if applicable): `2.8.0-RT-18`

**Supported patterns:**
- `[ISSUE-123]` - Issue in brackets
- `ISSUE-123:` - Issue followed by colon
- `ISSUE-123` - Issue anywhere in text

**Accepted prefixes:**
Any Jira project prefix (2-10 uppercase letters + hyphen + numbers):
- ✅ `FS-2039`
- ✅ `RT-18`
- ✅ `DEVOPS-456`
- ✅ `PROJ-123`
- ✅ `TEAM-999`

**Smart behavior:**
- Searches ALL commits in the range
- Stops as soon as it finds an issue
- Shows informative logs about where it was found
- Creates changelog without links if not found

### Commit Categorization

The script analyzes commits since the last tag and categorizes them:

- **Added** (feat): `feat: add new feature`
- **Fixed** (fix): `fix: resolve bug`
- **Changed** (refactor/chore): `refactor: improve code`, `chore: update dependencies`
- **Breaking Changes**: commits containing the word `BREAKING`

### Date Format

Dates in `yyyy-dd-mm` format (e.g., `2025-11-11`)

### Bitbucket Links

Automatically adds comparison links between versions at the end of CHANGELOG.

## Output Examples

### With detected issue

```markdown
## [2.8.0] - 2025-11-11

### Added
- **[[FS-2039](https://one-bemobi.atlassian.net/browse/FS-2039)]** Dynamic appName variable creation
- **[[FS-2039](https://one-bemobi.atlassian.net/browse/FS-2039)]** Public flag for fluentbit resources

### Fixed
- **[[FS-2039](https://one-bemobi.atlassian.net/browse/FS-2039)]** Extra space in IAM role name
```

### Without detected issue

```markdown
## [2.8.0] - 2025-11-11

### Added
- Dynamic appName variable creation
- Public flag for fluentbit resources

### Fixed
- Extra space in IAM role name
```

## Pipeline Integration

The scripts are integrated into `bitbucket-pipelines.yml` via Makefile and run automatically in the `release-code-version` pipeline.

### Pipeline flow:
1. Build and push Docker images (parallel)
2. Security scan (parallel)
3. **Version bump + Changelog update** ← Makefile commands executed here
4. Create tag and push

## Notes

- Script automatically moves `[Unreleased]` content to the new version
- `[Unreleased]` section is cleared after execution, ready for new commits
- Automatically removes conventional commit prefixes (feat:, fix:, etc.)
- Removes issue references from commit text to avoid duplication
- Tags with suffixes (-rc, -beta, -alpha) are automatically ignored
