# Biblioteca de materiales

Materiales compartidos por todas las áreas. Los específicos de un modelo (peces, hojas,
pantallas, tierra…) siguen en `assets/models/<area>/materials/`. Se asignan a los `.glb`
como materiales externos en su `.import` o desde las escenas y scripts (`@export var …: Material`).

Ninguno debe quemarse a blanco con el sol fuerte ni bajo los LED: si hace falta más brillo,
mejor subir la luz que el albedo.

| Material | Tipo | Uso |
|---|---|---|
| `white_lacquer` | Blanco lacado (albedo 0.9 sin tinte, rugosidad 0.2, clearcoat) | Mesas, macetas, bases, pies de disco, carcasas blancas, borde del tragaluz |
| `white_satin` | Blanco suave, rugoso, algo de brillo textil | Cojines e interiores tapizados |
| `chrome` | Metal pulido (metallic 1, rugosidad 0.1) | Patas, bases, ruedas, tubos finos, aros de focos |
| `brushed_aluminium` | Aluminio cepillado (metallic 1, rugosidad 0.4; albedo gris algo cálido para que en salas azules se lea plata y no azul) | Aros gruesos de ventanas y pantallas, remates metálicos mates |
| `lime_gloss` | Verde lima saturado y brillante | **Solo acentos**: aros finos, ribetes, remates. Nunca superficies grandes |
| `mint_soft` | Menta con clearcoat suave | Carcasas de butacas, sofás y sillas |
| `glass_clear` | Cristal (`glass.gdshader`): transparencia, Fresnel, refracción sutil | Tapas de mesa, mamparas claras |
| `glass_cyan` | Cristal cian más tintado y opaco | Cantos de cristal, mamparas y piezas de color |
| `shag_rug_swirl` | Alfombra de pelo largo en espiral cobalto → turquesa → verde (`shag_rug.gdshader`) | Alfombras; en calidad Alta añadir un nodo `ShagShells` (`scenes/fx/shag_shells.gd`) como hijo de la alfombra; sus `flatten_nodes` aplastan el pelo bajo los muebles |
| `led_cyan`, `led_green` | Emisivos | Tubos de `LedStrip` y `RoomLeds` |
| `downlight` | Emisivo cálido | Disco de los focos empotrados |

## Notas

- Los cristales leen la pantalla: lo transparente que quede detrás (otros cristales,
  burbujas, partículas) no se ve a través de ellos. Para variantes (otro tinte u opacidad),
  duplicar el `.tres` y ajustar sus parámetros.
- `shag_rug_swirl` dibuja el patrón en espacio local (plano XZ, centro en el origen), así
  que no necesita UV; el tamaño de los mechones y la espiral se ajustan en el material.
- Para cambiar un material en un sitio concreto sin afectar al resto, crear una variante con
  nombre propio en vez de editar el de la biblioteca.
