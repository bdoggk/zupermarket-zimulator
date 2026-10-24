# Zupermarket Zimulator downloads

This branch only holds the built game files for the latest version (it's replaced
with each release). The game's code is on the `main` branch.

When this branch is updated, a GitHub Actions workflow publishes the files on the
[Releases page](https://github.com/bdoggk/zupermarket-zimulator/releases/latest):

- `ZupermarketZimulator-android.apk`: Android (phones, tablets, AYN Thor)
- `ZupermarketZimulator-windows.zip`: Windows; the workflow unzips it and publishes
  the `.exe` (the .exe on its own is over GitHub's 100 MB file limit for branches)
- `VERSION`: the release number
- `RELEASE_NOTES.md`: the text shown on the release
- `store/`: what the workflow needs to build `ZupermarketZimulator-store.msix` for the
  Microsoft Store (built once `store/identity.ini` is filled in)
