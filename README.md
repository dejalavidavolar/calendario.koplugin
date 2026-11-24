# Calendario para KOReader

Plugin de calendario para KOReader (pensado para Kobo Libra Colour con ZenOS): vista mensual y semanal minimalistas, eventos con hora de inicio y fin, lugar, descripción y color, y sincronización bilateral por WebDAV (Nextcloud).

## Instalación

1. Copia la carpeta [`calendario.koplugin`](calendario.koplugin) a `koreader/plugins/` en tu dispositivo.
2. Reinicia KOReader.
3. Ábrelo desde el menú superior → herramientas → **Más herramientas → Calendario**, o asígnalo a un gesto.

La documentación completa (uso, sincronización WebDAV, ajustes) está en [`calendario.koplugin/README.md`](calendario.koplugin/README.md).

## Publicar una versión

Los releases se arman solos: al crear una etiqueta que empiece con `v`, la acción de GitHub (`.github/workflows/release.yml`) empaqueta `calendario.koplugin` en un zip y lo publica en [Releases](../../releases).

```sh
git tag v1.0.1
git push origin v1.0.1
```

(O desde la web: Releases → Draft a new release → crear la etiqueta al publicar.)
