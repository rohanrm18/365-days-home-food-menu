# Upload dish photos as a ZIP

1. Put your pictures in a ZIP file. Each picture must be named after its dish as listed in `docs/dish-photos.md` (for example `poha.jpg` or `puran_poli_and_amti.png`). Folders inside the ZIP are fine.
2. In GitHub open this folder, choose **Add file > Upload files**, drop the ZIP in and commit to `main`.
3. The "Import dish photos from ZIP" workflow unpacks the pictures into `assets/meals/`, skips anything whose name does not match a dish and then rebuilds the web app and the APK.

Pictures must be .jpg or .png and under 3 MB each. Open the workflow run to see which files were imported or skipped.
