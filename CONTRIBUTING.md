# Publishing

## Auto-publish via GitHub Actions

1. Update `version` in `pubspec.yaml` (e.g. `1.0.2`)
2. Update `CHANGELOG.md` with what's new
3. Commit, tag, and push:

```bash
git add -A && git commit -m "v1.0.2"
git tag v1.0.2
git push origin main --tags
```

GitHub Actions will auto-publish to pub.dev.

## Manual publish

```bash
flutter pub publish
```
