# Release Workflow

Guida per gestire release beta e stable di Noteton.

## Strategia

**GitHub Flow + Pre-release**: sviluppo su `master`, tag per release, NO branch separati.

### Vantaggi
- ✅ Semplicità (no merge conflicts tra branch)
- ✅ CI/CD automatico (GitHub Actions)
- ✅ Auto-update in-app esclude beta automaticamente
- ✅ Storico completo su master

---

## Semantic Versioning

Formato: `MAJOR.MINOR.PATCH-PRERELEASE+BUILD`

### Esempi
```
0.11.0-beta.1+23   → Beta 1 (versionCode 23)
0.11.0-beta.2+24   → Beta 2 con fix (versionCode 24)
0.11.0+25          → Stable release (versionCode 25)
0.11.1+26          → Patch bug fix
0.12.0-beta.1+27   → Nuova feature in beta
```

### Regole Android
1. **`versionCode` (`+N`)**: SEMPRE crescente (Android rifiuta installazioni se decresce)
2. **`-beta.X`**: Indica pre-release (GitHub Actions lo rileva automaticamente)
3. **Rimuovi `-beta`**: Per release stable

---

## Workflow Beta Release

### 1. Preparazione

```bash
# Modifica pubspec.yaml
version: 0.11.0-beta.1+23

# Commit
git commit -am "release: v0.11.0-beta.1 - Purple theme beta"

# Tag
git tag v0.11.0-beta.1
git push origin master --tags
```

### 2. Build automatica

GitHub Actions:
- ✅ Rileva tag `v*`
- ✅ Builda APK firmato
- ✅ Crea GitHub Release
- ✅ **Automaticamente marca come "Pre-release"** (rileva `-beta`/`-alpha`/`-rc`)

### 3. Test

1. Scarica APK da: `https://github.com/ShecktorS/noteton/releases/tag/v0.11.0-beta.1`
2. Installa su smartphone
3. Testa tutte le feature:
   - Settings → Variante colore → Amethyst
   - Tutte le schermate (Libreria, Setlist, Viewer)
   - Persistenza tema (riavvia app)
   - Combinazioni: Light+Amethyst, Dark+Amethyst

### 4. Fix iterativi

Se trovi bug:

```bash
# Fix codice
# ...

# Bump versione
version: 0.11.0-beta.2+24

# Tag e push
git commit -am "fix: risolto bug X in tema purple"
git tag v0.11.0-beta.2
git push origin master --tags
```

GitHub Actions builda automaticamente la nuova beta.

---

## Workflow Stable Release

Quando la beta è stabile:

### 1. Rimuovi suffisso beta

```bash
# Modifica pubspec.yaml
version: 0.11.0+25  # Rimuovi -beta.X

# Commit
git commit -am "release: v0.11.0 - Purple theme stable"
```

### 2. Tag finale

```bash
git tag v0.11.0
git push origin master --tags
```

### 3. Release automatica

GitHub Actions:
- ✅ Builda APK
- ✅ Crea GitHub Release
- ✅ **NON marca come Pre-release** (nessun `-beta`/`-alpha`/`-rc`)
- ✅ Diventa "Latest release"
- ✅ **Auto-update in-app NOTIFICA gli utenti**

---

## Auto-Update Behavior

### Pre-release (tag con `-beta`, `-alpha`, `-rc`)

```
Visibile:     https://github.com/ShecktorS/noteton/releases
Badge:        "Pre-release" 
Auto-update:  ❌ NON notifica (API /latest esclude pre-release)
Download:     Solo tester che conoscono il link
```

### Stable release (tag senza suffisso)

```
Visibile:     https://github.com/ShecktorS/noteton/releases
Badge:        "Latest" 
Auto-update:  ✅ NOTIFICA tutti gli utenti
Download:     Automatico via in-app update
```

---

## Configurazione GitHub Actions

Il workflow `.github/workflows/release.yml` rileva automaticamente le pre-release:

```yaml
- name: Estrai la versione dal tag
  id: version
  run: |
    VERSION=${GITHUB_REF_NAME#v}
    echo "version=$VERSION" >> "$GITHUB_OUTPUT"
    # Rileva automaticamente se è una pre-release
    if [[ "$VERSION" =~ -(beta|alpha|rc) ]]; then
      echo "is_prerelease=true" >> "$GITHUB_OUTPUT"
    else
      echo "is_prerelease=false" >> "$GITHUB_OUTPUT"
    fi

- name: Pubblica la Release
  uses: softprops/action-gh-release@v2
  with:
    prerelease: ${{ steps.version.outputs.is_prerelease }}
    # ...
```

---

## Checklist Release

### Beta

- [ ] Bump `pubspec.yaml`: `version: X.Y.Z-beta.N+BUILD`
- [ ] Commit: `release: vX.Y.Z-beta.N - Descrizione`
- [ ] Tag: `git tag vX.Y.Z-beta.N`
- [ ] Push: `git push origin master --tags`
- [ ] Verifica build CI: https://github.com/ShecktorS/noteton/actions
- [ ] Verifica pre-release flag su GitHub: https://github.com/ShecktorS/noteton/releases
- [ ] Test APK su device fisico
- [ ] Verifica che auto-update NON mostri la beta

### Stable

- [ ] Beta testata e stabile
- [ ] Rimuovi `-beta.N` da `pubspec.yaml`: `version: X.Y.Z+BUILD`
- [ ] Commit: `release: vX.Y.Z - Descrizione`
- [ ] Tag: `git tag vX.Y.Z`
- [ ] Push: `git push origin master --tags`
- [ ] Verifica build CI
- [ ] Verifica "Latest release" su GitHub
- [ ] Test APK su device fisico
- [ ] Verifica che auto-update MOSTRI l'aggiornamento

---

## Rollback

Se una release ha problemi gravi:

```bash
# Elimina tag locale e remoto
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z

# Elimina GitHub Release manualmente
# https://github.com/ShecktorS/noteton/releases

# Revert commit se necessario
git revert <commit-hash>
git push origin master
```

---

## Best Practices

1. **Testa sempre in beta** prima di stable
2. **Incrementa sempre `versionCode`** (+N)
3. **Usa semantic versioning** correttamente
4. **Beta multiple** se necessario (`beta.1`, `beta.2`, ...)
5. **Documenta breaking changes** nelle release notes
6. **Test su device fisico** (non solo emulatore)
7. **Verifica auto-update** dopo ogni stable release

---

## Riferimenti

- **Semantic Versioning**: https://semver.org/
- **GitHub Releases**: https://docs.github.com/en/repositories/releasing-projects-on-github
- **Android Versioning**: https://developer.android.com/studio/publish/versioning
