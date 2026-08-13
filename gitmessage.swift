normalize photo orientation before upload

Render every selected image once before JPEG upload so the EXIF orientation is
applied. This keeps the server original and the crop upright. Bump build to 77.
