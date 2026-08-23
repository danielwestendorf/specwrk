# Releasing Specwrk

Releases are cut from `main` in two stages:

1. `gem bump` updates the version and creates the release commit.
2. Bundler's `rake release` task tags the commit, pushes Git, and publishes the gem.

The Docker image is published separately after the gem release.

## One-time setup

Install `gem-release`, which provides the `gem bump` command. It is intentionally
not a development dependency because it is only needed by maintainers cutting a
release.

```sh
gem install gem-release
```

Configure credentials for RubyGems and Docker Hub:

```sh
gem signin
docker login docker.io
```

The Docker release also requires a buildx builder capable of building `linux/arm64`
and `linux/amd64` images. Check the active builder with:

```sh
docker buildx inspect --bootstrap
```

## Cut the gem release

Start from an up-to-date, clean `main` branch. This is important because
`rake release` pushes the current branch.

```sh
git switch main
git pull --ff-only origin main
git status --short
```

Bump the version without committing. Use `patch`, `minor`, `major`, or an
explicit version number:

```sh
gem bump --version patch --no-commit
```

This updates `lib/specwrk/version.rb` while leaving the release changes
uncommitted. Update `CHANGELOG.md` using the new version:

1. Change the Unreleased comparison link to start at the new version.
2. Add a dated section for the new version.
3. Move the Unreleased entries into that section.

Stage the version, changelog, and any release documentation, then create the
version commit:

```sh
git add lib/specwrk/version.rb CHANGELOG.md RELEASING.md
git commit -m "Bump specwrk to VERSION"
```

Replace `VERSION` with the new version, for example `0.19.4`. Confirm that the
commit contains the version and changelog updates:

```sh
git show --stat --oneline HEAD
git status --short
```

Run the full checks:

```sh
bundle exec rake
```

Publish the release:

```sh
bundle exec rake release
```

The release task requires a clean tracked worktree and then:

1. Builds `pkg/specwrk-VERSION.gem`.
2. Creates the annotated `vVERSION` tag.
3. Pushes `main` and the tag to `origin`.
4. Pushes the gem to RubyGems.org.

Use `gem bump` only to update the version file; use `bundle exec rake release`,
not `gem release`, for publishing this project.

If the RubyGems push fails after the tag was pushed, fix the authentication or
network problem and rerun `bundle exec rake release`. The task recognizes the
existing tag and retries the gem publication.

## Build and publish the Docker image

After the gem release succeeds, run:

```sh
scripts/build-server
```

The script reads the version from `bundle exec exe/specwrk --version`, builds the
gem from the current checkout, and runs a multi-platform `docker buildx build`
with `--push`. It publishes both of these tags:

- `docker.io/danielwestendorf/specwrk-server:VERSION`
- `docker.io/danielwestendorf/specwrk-server:latest`

It builds images for both `linux/arm64` and `linux/amd64`. The temporary gem in
the repository root is removed after a successful build.

Verify the published manifest with:

```sh
docker buildx imagetools inspect docker.io/danielwestendorf/specwrk-server:VERSION
```

Replace `VERSION` with the released version without the `v` prefix, for example
`0.19.4`.
