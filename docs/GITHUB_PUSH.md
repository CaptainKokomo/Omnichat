# Publishing the Workspace to GitHub

This guide describes how to push the current project from the `work` branch to a GitHub repository when the default `main` branch does not yet exist.

## 1. Create the `main` branch locally

```
git checkout -b main
```

If you want to preserve the existing `work` branch, you can keep it or delete it after pushing.

## 2. Set the upstream remote

The remote has already been added as `origin` pointing to `https://github.com/Captainkokmo/Omnichat.git`. If it has not, add it with:

```
git remote add origin https://github.com/Captainkokmo/Omnichat.git
```

## 3. Push the new `main` branch

Once the branch exists locally, push it and set the upstream in one step:

```
git push -u origin main
```

Git will prompt for GitHub credentials or use an existing credential helper. A successful push will create the branch on GitHub and link the local `main` branch to it for future pushes.

## 4. Continue working

After the initial push, run the standard workflow:

```
git status
# make changes
# commit changes

git push
```

Git will automatically target `origin/main` thanks to the upstream configuration.

