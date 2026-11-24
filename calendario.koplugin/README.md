# Calendario (plugin para KOReader)

Vista mensual minimalista con eventos (hora, lugar y descripción) y sincronización WebDAV.

## Instalación

1. Copia la carpeta `calendario.koplugin` a `koreader/plugins/` en tu dispositivo.
2. Reinicia KOReader.
3. Ábrelo desde el menú superior → ícono de herramientas → **Más herramientas → Calendario**.
   También puedes asignarlo a un gesto: Ajustes → Gestos → (gesto) → General → **Calendario**.

## Uso

- **Primera página:** barra de título con ☰ (izquierda) y ✕ (derecha); debajo, la cuadrícula del mes (lunes a domingo) sin márgenes. Cada cuadro muestra el número del día arriba a la derecha y sus eventos (solo el texto, sin la hora) en letra pequeña, separados por un pequeño espacio, con varias líneas si caben; si hay varios eventos el mismo día se reparten el espacio.
- **Color:** cada evento se ve como un recuadro redondeado (estilo Notion Calendar): relleno claro del color elegido con una franja más oscura a la izquierda y solo el título, en un tono oscuro del mismo color; los eventos sin color son grises. Hay un pequeño margen lateral en el cuadro del día.
- **Cambiar de mes:** desliza a izquierda/derecha o usa los botones físicos de página.
- **Tocar un día:**
  - sin eventos → página para crear uno (fecha, hora, descripción, lugar, color);
  - con eventos → lista del día; toca uno para editarlo o usa **+ Agregar evento** (debajo del último).
- **Lista del día:** desliza a la izquierda → día siguiente; a la derecha → día anterior (también con los botones físicos). Si la lista no cabe, desliza hacia arriba/abajo para cambiar de página.
- **Letra:** en el mes todos los eventos usan el mismo tamaño (constante `EV_FONT` en `calendario_widgets.lua`); en la semana la letra es mayor y se adapta al contenido de cada cuadro (hasta 20, mínimo 11); si un día tiene más eventos de los que caben, se reparte el espacio y se muestra «+N más». El día de hoy se marca con una insignia negra de esquinas redondeadas detrás del número (en el mes y en la semana).
- **Idioma:** automático, según el idioma de KOReader (español o inglés).
- **Barra de ZenOS:** si está activa en la biblioteca, el calendario deja libre el borde inferior para que se vea (usa la altura que publica ZenOS). Al tocar una pestaña de esa barra, el calendario se cierra y ZenOS abre esa pestaña.
- **Navegación:** la ✕ de la lista del día y del editor vuelve a la vista anterior (si un evento tiene cambios sin guardar, pregunta antes de descartarlos); la ✕ del mes cierra el calendario.
- **Color (editor):** el campo Color muestra el círculo de «sin color» (con una diagonal) o el color elegido; al tocarlo se abre una ventana con los colores: Rojo, Naranja, Amarillo, Verde, Celeste, Azul y Violeta. Los textos de ayuda («Configurar hora», «Agrega un lugar»…) van en negro.
- **Barra de título:** tocar el sector del título abre el menú de KOReader/ZenOS.
- **Ventanas:** al abrir un menú, confirmación o teclado, el resto de la pantalla se raya (mismo estilo que el fondo difuminado de ZenOS).
- **Hora del evento:** reloj circular estilo Android (con acento lila). Arriba, inicio y fin en círculos (toca la hora o los minutos para editarlos); en el reloj toca o desliza el dedo: primero la hora (anillo exterior 12, 1–11; interior 00, 13–23) y al soltar pasa solo a los minutos (de 5 en 5). El fin es opcional: solo existe si tocas su círculo. Para dejar el evento sin hora, no abras el selector. En el mes se muestra la hora de inicio; en la lista del día, el rango.
- **Recuerda la vista:** al volver al calendario se abre la última vista usada (mensual o semanal); se guarda en el proceso, en los ajustes globales de KOReader y en `settings/calendario.lua`, y queda anotada en `crash.log` (líneas «Calendario: última vista = …»).
- **Título:** en la vista mensual y semanal, el mes va en negrita y el año en normal.
- **Vista semanal:** ☰ → **Vista semanal**. Muestra de lunes a viernes en 2 filas de 3 cuadros (lun-mar-mié / jue-vie-sáb+dom; el sexto cuadro se divide: sábado arriba y domingo abajo). Desliza o usa los botones físicos para cambiar de semana, toca un día para abrirlo; la ✕ sale del calendario (como en el mes) y ☰ → **Vista mensual** vuelve al mes. Cada evento con hora la muestra abajo a la derecha de su tarjeta, en un tono más suave. Si la semana cruza de mes, el título dice, por ejemplo, «Diciembre - Enero 2027».
- **Menú ☰:** Vista semanal, Sincronizar calendario y Configurar WebDAV.

## Sincronización WebDAV (Nextcloud)

Menú ☰ → **Configurar WebDAV…**

- **URL de la carpeta:** `https://TU-SERVIDOR/remote.php/dav/files/TU-USUARIO/Calendario`
- **Usuario** y **contraseña** (en Nextcloud, crea una *contraseña de aplicación* en Ajustes → Seguridad).
- **Archivo:** opcional, por defecto `calendario.json`.

Ahí mismo está la opción **Sincronizar al abrir**. Luego usa **Sincronizar calendario** en el menú ☰. La sincronización es bilateral: descarga, fusiona (por evento gana el cambio más reciente), y sube solo si hay algo nuevo. Los borrados también se propagan. Si la carpeta no existe, intenta crearla (un nivel).

Notas:
- Los datos locales están en `koreader/calendario/eventos.json`; los ajustes (incluida la contraseña, en texto plano) en `koreader/settings/calendario.lua`.
- La fusión usa la hora de cada dispositivo: mantén los relojes razonablemente en hora.
