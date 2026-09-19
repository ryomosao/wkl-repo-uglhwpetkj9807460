# Simple App (Static)

A tiny single-page static application with many files (pages, components, utils, styles).

## Structure

- `src/index.html` — entry HTML
- `src/components/` — header and footer fragments
- `src/pages/` — route pages (home, about, contact)
- `src/css/` — base, layout, and button styles
- `src/js/` — app bootstrap, router, utils, and UI components
- `src/assets/` — images, icons (placeholders)

## Run locally

Just open `src/index.html` in a browser. Some browsers restrict `fetch()` on file URLs; if so, start a local server:

```bash
# Python 3
cd simple-app/src
python -m http.server 8080
# then open http://localhost:8080
```

## Create a private GitHub repo and push

1. Create a new private repository on GitHub (no README): `simple-app`
2. Initialize and push:

```bash
cd simple-app
git init
git add .
git commit -m "chore: initial static app"
git branch -M main
git remote add origin https://github.com/<your-account>/simple-app.git
git push -u origin main
```

If using SSH:

```bash
git remote set-url origin git@github.com:<your-account>/simple-app.git
```

## License

MIT
