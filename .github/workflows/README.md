# GitHub Actions Workflows

This directory contains automation workflows for the Horizon project.

## Active Workflow

### release-with-build.yml - Automated Release with Build

**Trigger**: Push to main branch

**Features**:
1. **Build and Test Execution** - Build the project in Zig 0.15.2 environment and run all tests
2. **Automatic Version Extraction** - Automatically read version from `build.zig.zon`
3. **Documentation Archive** - Archive the `docs/` directory in tar.gz format
4. **Automatic Git Tag Creation** - Create tags in the format `v0.1.3`
5. **GitHub Release Creation** - Create release with documentation archive attached
6. **Automatic Release Notes Generation** - Automatically generate changelog from previous tag

**Benefits**:
- Quality assurance before release (build & test execution)
- Documentation distribution
- Robust release process
- Improved release reliability

## Usage

### 1. Work on Development Branch

```bash
git checkout -b feature/new-feature
# Development work
git commit -m "Add new feature"
```

### 2. Update Version

Update version information in the following files before release:
- `build.zig.zon` `version` field (required)
- `README.md` version information (recommended)
- `docs/index.html` version information (recommended)

```bash
# Example: Update from 0.1.3 to 0.1.4
git add build.zig.zon README.md docs/index.html
git commit -m "Bump version to 0.1.4"
```

### 3. Merge to Main Branch

```bash
git checkout main
git merge feature/new-feature
git push origin main
```

### 4. Automatic Release Creation

When pushed to main branch, the following will be executed automatically:

1. Build Zig project
2. Run tests
3. Create documentation archive
4. Create Git tag (e.g., `v0.1.4`)
5. Create GitHub release
6. Generate release notes

If the build or tests fail, the release will not be created.

## Important Notes

### Version Management
- If a tag with the same version already exists, the release will not be created
- **Follow Semantic Versioning (SemVer)**
  - `MAJOR.MINOR.PATCH` format (e.g., `0.1.3`)
  - **MAJOR**: Incompatible changes
  - **MINOR**: Backward-compatible feature additions
  - **PATCH**: Backward-compatible bug fixes

### Permissions
- Release creation requires `GITHUB_TOKEN`, which is provided automatically
- Ensure "Read and write permissions" is enabled in your repository's **Settings > Actions > General > Workflow permissions**

### Testing
- All tests are executed before release
- If tests fail, the release will not be created
- **It is recommended to run `make zig build test` locally before release**

## Troubleshooting

### If Release is Not Created

1. **Check Version Format**
   - Verify that the version in `build.zig.zon` is in the correct format (e.g., `"0.1.3"`)
   - Ensure it is enclosed in quotes

2. **Check for Duplicate Tags**
   ```bash
   git tag -l  # Display list of existing tags
   ```
   - Verify that a tag with the same version does not already exist

3. **Check GitHub Actions Logs**
   - Check the execution logs from the "Actions" tab in the repository
   - Review error messages to identify the cause

### If Build Fails

1. **Test Locally**
   ```bash
   make zig build test
   ```
   - Check if the same error occurs in your local environment

2. **Check Dependencies**
   - Verify compatibility with Zig 0.15.2
   - Ensure PCRE2 library dependencies are correctly configured

3. **Check Build Configuration**
   - Review `build.zig` configuration
   - Check test files for syntax errors

## Workflow Details

### Job Flow

1. **build-and-test job**
   - Setup Zig (v0.15.2)
   - Install PCRE2
   - Build project
   - Run tests
   - Create documentation archive
   - Upload build artifacts

2. **release job** (only if build-and-test succeeds)
   - Extract version
   - Check if tag exists
   - Create and push new tag
   - Download build artifacts
   - Generate release notes
   - Create GitHub release

### Generated Release Contents

- **Tag**: `v{version}` format (e.g., `v0.1.3`)
- **Release Name**: `Horizon {version}` format
- **Attached File**: `horizon-docs.tar.gz` (documentation archive)
- **Release Notes**: Automatically generated changelog from previous tag

## Customization

The workflow can be customized by editing `.github/workflows/release-with-build.yml`:

### Example: Adding Notifications

To add Slack notifications:

```yaml
- name: Notify Slack
  if: steps.check_tag.outputs.exists == 'false'
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "New release: Horizon ${{ steps.get_version.outputs.version }}"
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Example: Additional Artifacts

To include additional files in the release:

```yaml
files: |
  ./artifacts/horizon-docs.tar.gz
  ./artifacts/zig-out/bin/my-binary
```

For more details, refer to the [GitHub Actions Official Documentation](https://docs.github.com/en/actions).
