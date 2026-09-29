# Guía de estilo visual

El juego busca el **retrofuturo de los 2000** (Frutiger Aero / Frutiger Eco): un futuro
tecnológico y ecológico optimista, limpio, luminoso y un poco soñado, como en los renders
y la publicidad de mediados de los 2000. Referencias en `docs/references/estilo/` (no se
suben al repositorio). En esas capturas, la interfaz de TikTok, los textos superpuestos y
las marcas de agua no forman parte del estilo.

Cada espacio usa una de las dos variantes de abajo. **El área 1 es "Eco soleado" con
acentos LED.**

## Común a todo el juego

- **Base blanca glossy**: superficies blancas brillantes, curvas y esquinas redondeadas,
  formas orgánicas (gotas, burbujas, nubes, hojas).
- **Metal**: cromo y aluminio en marcos, patas, barandillas y remates.
- **Color**: azul cielo y cian dominantes, verde lima como acento fuerte, plata. Cristal
  translúcido de color (cian, lima, azul).
- **Motivos**: agua, burbujas, hojas, peces y medusas, planeta Tierra.
- **Acabado de imagen**: foto o render de mediados de los 2000. Bloom intenso en brillos y
  reflejos, colores saturados, contraste alto, blancos que casi queman y una neblina
  luminosa suave.
- **Evitar**: marcas, logos o personajes existentes (carteles y eslóganes, siempre
  genéricos y propios); colores sucios o apagados; luz plana sin brillos.

## Variante "Eco soleado"

Espacios públicos, estaciones, tiendas, oficinas y exteriores. Refs 10, 11, 21–30.

- **Luz**: sol fuerte, a menudo dentro del encuadre con destello de estrella y lens flare
  (23–25). Sombras nítidas de montantes, pérgolas y árboles sobre el suelo (29, 30). Mucha
  luz de día que entra por cubiertas y fachadas de cristal.
- **Suelos**: blancos, pulidos, casi espejo; reflejan luz, plantas y cielo (22–25, 29, 30).
- **Materiales**: cromo y cristal (tornos, barandillas de vidrio con remate de aluminio,
  cubiertas de cristal con estructura blanca), mamparas de cristal cian y lima (29).
- **Vegetación**: árboles en maceteros blancos (30), enredaderas y plantas colgando de
  pérgolas y cornisas (24, 25).
- **Grafismo**: carteles y pantallas con eslóganes ecológicos genéricos en tipografía
  redondeada, del tipo "Un mundo más limpio y brillante" o "Próxima parada: un mañana mejor"
  (22–25). Iconos de hoja, gota y planeta.
- **Paisaje**: ciudad costera de rascacielos de cristal, mar turquesa, islas, palmeras,
  puentes curvos y monorraíl (23, 26, 27).

## Variante "Doméstico LED"

Salones, dormitorios, baños y cocinas; incluye la variante nocturna **Frutiger Night**
(refs 7–9), más oscura y en la que el LED domina. Refs 6, 12–20.

- **Luz**: tiras LED azules y verdes ocultas en bandejas de techo (18, 20, 9), zócalos
  (12), bajo camas y sofás (19, 20) y en bases de columnas (7, 8). Focos empotrados en el
  techo (12, 16, 20). Aros y plafones con borde luminoso (8, 9).
- **Hornacinas iluminadas** con piezas de cristal azul y verde (16, 18, 20).
- **Paredes** con burbujas, discos luminosos y ojos de buey (12, 13, 19). Acuarios
  empotrados con marco plateado (12–14, 19).
- **Colgantes** de gota de cristal azul (16) y esferas colgantes (6).
- **Textiles**: alfombras de pelo largo en espiral azul-verde (16, 18, 20) u ovaladas
  (12–14). Sofás curvos blancos con cojines azul y lima, mesas de cristal ovaladas.

## Cómo se consigue en Godot

Valores de partida (área 1, `scenes/areas/area_01/area_01.tscn`):

- **Sol**: `DirectionalLight3D` fuerte con sombras nítidas (poco blur). La niebla
  volumétrica da los haces visibles por el tragaluz y las ventanas.
- **Reflejos y luz rebotada**: en calidad Alta, SDFGI a resolución completa para el rebote
  de color y reflejo planar en el suelo (`scenes/fx/planar_reflection.gd`: cámara reflejada a
  un SubViewport a media resolución con un entorno barato; `leaf_floor.gdshader` lo muestrea
  con fresnel y un leve desenfoque y lo funde al material normal donde el suelo se curva). El
  reflejo de SDFGI en el suelo va con retraso al girar la cámara y se ve como una mancha que
  "nada": por eso el suelo no lo usa. Lo que no debe salir en el reflejo (terreno bajo la
  sala, vegetación exterior, objetos pequeños) va en el grupo `no_planar_reflection`; las
  partículas se ocultan solas. En Media y Baja no hay SDFGI y los reflejos son de las
  ReflectionProbes con box projection (sala principal y entrante, actualización única).
- **Imagen**: tonemap ACES con algo más de exposición, glow en modo *screen* con el umbral
  algo por encima del blanco de las paredes (~1,25) para que brillen reflejos, sol y LED sin
  velar la sala, saturación y contraste subidos en `adjustment`. Niebla volumétrica poco
  densa e iluminada casi solo por el sol: si se sube mucho, la imagen se vuelve lechosa.
- **Antialiasing**: TAA (estabiliza el brillo de detalles finos y reflejos al girar) con un
  enfoque suave en `CameraFx` para no perder nitidez. Calidad Alta/Media/Baja con F4
  (`scripts/autoload/graphics_quality.gd`); Alta usa los valores de la escena.
- **Cámara**: `scenes/fx/camera_fx.tscn` (instanciado en `main.tscn`) con destello de
  estrella y lens flare del sol y una viñeta ligera. Sirve para cualquier área con un sol.
- **Materiales**: biblioteca común en `assets/materials/` (ver su `README.md`): blanco lacado,
  blanco satinado, cromo, aluminio cepillado, menta, lima (solo acentos), cristal claro y
  cian, alfombra de pelo largo en espiral y los emisivos de LED y focos. Marcos de ventana y
  de pantalla: aro de cromo con un aro fino lima por dentro.
- **LED**: `LedStrip` (tubo emisivo y, si hace falta, luces pequeñas que bañan el suelo).
  Los LED de la propia sala (tragaluz, zócalo, columna, focos) los genera `RoomLeds` a partir
  de la geometría de la sala.
