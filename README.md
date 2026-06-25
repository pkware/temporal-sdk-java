# temporal-sdk-java

Patch-based fork of [temporalio/sdk-java](https://github.com/temporalio/sdk-java) published to Maven Central under `com.pkware.temporal`.

## What's different

| Patch | Description |
|-------|-------------|
| 0001 | Replace Jackson with Moshi as default JSON converter |
| 0002 | Remove GSON dependency |
| 0003 | Replace grpc-netty-shaded with grpc-netty (real, un-shaded) |
| 0004 | Change groupId to `com.pkware.temporal` |

## Maven coordinates

```kotlin
// build.gradle.kts
implementation("com.pkware.temporal:temporal-sdk:1.35.0-pkware.1")
testImplementation("com.pkware.temporal:temporal-testing:1.35.0-pkware.1")
```

## Version scheme

`{upstream}-pkware.{N}` — N starts at 1 for each new upstream version and increments for patch-only changes against the same upstream.

## How it works

No upstream source is committed. The repo contains only:
- `patches/` — git format-patch files (the delta from upstream)
- `scripts/` — shell scripts to apply/export patches
- `overlay/` — files copied on top of the patched tree (publishing config, dependency versions)
- `.github/workflows/` — CI automation

`apply-patches.sh` clones upstream at a tag into `build/`, applies patches, and copies overlay files.

## Local development

```bash
git clone https://github.com/pkware/temporal-sdk-java.git
cd temporal-sdk-java
./scripts/apply-patches.sh

cd build
./gradlew assemble
./gradlew test
```

Requires JDK 21.

### Publishing locally

```bash
cd build
./gradlew publishToMavenLocal -PoverrideVersion=1.35.0-pkware.1
```

Then add `mavenLocal()` to your consuming project's repositories block.

## Dependency versions

New dependencies introduced by patches (e.g. Moshi) have their versions in `overlay/gradle.properties`. This file is copied into `build/` by `apply-patches.sh` and is scannable by Renovate.

## Modifying patches

```bash
./scripts/apply-patches.sh

cd build
# edit files...
git add -A && git commit -m "Description of change"

cd ..
./scripts/create-patches.sh

git add patches/
git commit -m "Update patches"
```

## Resolving patch conflicts

When `apply-patches.sh` fails because upstream changed a file that a patch touches, you need to resolve the conflict manually.

```bash
# 1. Start with a clean state
rm -rf build
./scripts/apply-patches.sh v1.36.0
# Script will fail and print which patch conflicted.

# 2. Resolve conflicts in build/
cd build

# Git leaves conflict markers in the affected files. Fix them:
#   - Open each conflicting file, resolve the markers (<<<< ==== >>>>)
#   - git add each resolved file
git add <resolved-files>
git am --continue
# If additional patches also conflict, repeat: fix files, git add, git am --continue

# 3. Verify the result compiles and tests pass
./gradlew build

# 4. Export the updated patches
cd ..
./scripts/create-patches.sh

# 5. Update .upstream-version and commit
echo "v1.36.0" > .upstream-version
git add .upstream-version patches/
git commit -m "Resolve patch conflicts for v1.36.0"
```

If a conflict is too complex to resolve (e.g. upstream rewrote an entire file), you can abort and start over:

```bash
cd build
git am --abort
# Now you're back at the upstream tag with no patches applied.
# Make your changes fresh, commit them, and re-export.
```

## Alerts and notifications

The `sync.yml` workflow runs twice daily and automatically creates **GitHub Issues** when something goes wrong:

- **"Patch conflict on upstream vX.Y.Z"** — patches didn't apply cleanly against the new upstream tag. Follow the [resolving patch conflicts](#resolving-patch-conflicts) steps above.
- **"Test failure on upstream vX.Y.Z"** — patches applied but the build or tests failed. Usually means upstream changed behavior that our patches depend on.

**To receive alerts**, subscribe to GitHub notifications for this repo:
1. Go to the repo page on GitHub
2. Click **Watch** → **All Activity** (or **Custom** → check **Issues**)

Both issue types include a link to the failed CI run for debugging.

## Publishing to Maven Central

### Automatic (recommended)

The `sync.yml` workflow handles publishing automatically when it detects a new upstream tag. It:
1. Applies patches against the new tag
2. Runs the full build and test suite
3. Publishes all artifacts to Maven Central via Sonatype OSSRH
4. Creates a GitHub Release

No manual intervention needed — new upstream releases are published within 12 hours.

### Manual

Use the `manual-build.yml` workflow:
1. Go to **Actions** → **Manual Build**
2. Enter the upstream tag (e.g. `v1.35.0`)
3. Check **Publish to Maven Central**
4. Click **Run workflow**

### Required secrets

Both workflows need these repository secrets configured in GitHub:

| Secret | Description |
|--------|-------------|
| `NEXUS_USERNAME` | Sonatype OSSRH username for Maven Central |
| `NEXUS_PASSWORD` | Sonatype OSSRH password |
| `SIGNING_KEY` | ASCII-armored GPG private key for artifact signing |
| `SIGNING_KEY_ID` | GPG key ID (short or long form) |
| `SIGNING_PASSWORD` | Passphrase for the GPG key |

Without these secrets, the build/test steps still run, but publishing is skipped.

### First-time setup

If the PKWARE Sonatype account or GPG key doesn't exist yet:
1. Register a Sonatype OSSRH account and claim the `com.pkware.temporal` namespace (or verify it's already claimed under the `com.pkware` group)
2. Generate a GPG key pair: `gpg --gen-key`
3. Export the private key: `gpg --armor --export-secret-keys <key-id>`
4. Publish the public key to a keyserver: `gpg --keyserver keyserver.ubuntu.com --send-keys <key-id>`
5. Add all four secrets to the GitHub repo settings

## License

Apache License 2.0 — same as upstream Temporal SDK.
