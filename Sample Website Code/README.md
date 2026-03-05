# DayNight Admin Static Site

This repository contains a static multi-page admin dashboard theme (DayNight Admin) built with plain HTML, CSS, and JavaScript.

## What is in this project

- **Dashboard and app pages**
  - `index.html` (dashboard)
  - `projects.html` (project and task board)
  - `inbox.html` (message UI)
  - `analytics.html` (analytics layout)
  - `settings.html` (settings toggles)
  - `login.html` (authentication page)
  - `about-templatemo.html` (template information)
- **Shared assets**
  - `templatemo-daynight-style.css` for the full visual system
  - `templatemo-daynight-script.js` for theme switching, greetings, interactions, and mobile menu behavior

## Key site behavior

- **Theme persistence**: users can toggle between Snow and Carbon themes; the selected theme is stored in browser `localStorage`.
- **Responsive navigation**: includes desktop nav and a mobile menu with overlay handling.
- **Interactive widgets**: includes date-range chart updates, inbox message preview behavior, kanban drag-and-drop, and settings toggles.

## Deploying to S3 + CloudFront

Because this is a static site, deploy by uploading files to an S3 bucket and fronting it with CloudFront.

### 1) Generate deployment manifest

A helper script is included to scan the HTML pages and produce `deployment-manifest.json`:

```bash
python3 generate_deploy_manifest.py
```

The manifest contains:
- discovered HTML pages and static assets,
- suggested upload order,
- CloudFront invalidation paths,
- suggested cache-control rules by file type.

### 2) Upload to S3

You can upload files using AWS CLI (example):

```bash
aws s3 sync . s3://YOUR_BUCKET_NAME \
  --exclude ".git/*" \
  --exclude "*.py" \
  --exclude "README.md"
```

Then apply cache headers according to `deployment-manifest.json` rules (HTML short cache, CSS/JS long immutable cache).

### 3) Invalidate CloudFront cache

After upload, invalidate HTML routes so users receive the latest pages.

## Local preview

To preview locally:

```bash
python3 -m http.server 8080
```

Then open `http://localhost:8080` in your browser.
