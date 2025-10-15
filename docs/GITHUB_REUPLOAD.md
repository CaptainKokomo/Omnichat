# Re-uploading Omnichat to GitHub

If direct pushes from this environment are blocked, generate a Git bundle and publish it manually.

## 1. Create the bundle

From the project root:

```bash
scripts/create_github_bundle.sh
```

This produces `omnichat.bundle` alongside the repository.

## 2. Transfer the bundle

Download `omnichat.bundle` to your local machine using the VS Code download button or `scp`/`rsync` if available.

## 3. Push from your machine

```bash
git clone omnichat.bundle omnichat-upload
cd omnichat-upload
git remote add origin https://github.com/Captainkokmo/Omnichat.git
git push --all origin
git push --tags origin
```

GitHub now has every branch and tag that existed in the bundle. You can delete the temporary `omnichat-upload` directory afterwards.
