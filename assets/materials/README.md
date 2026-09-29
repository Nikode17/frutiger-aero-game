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
| `chrome_bezel` | Cromo "de estudio" (`chrome_studio.gdshader`): reflejo real atenuado + entorno falso neutro con franja oscura de horizonte, brillo cenital y tiras de luz, para que se lea metal aunque la sala sea azul | Biseles de ventanas y pantallas, aros de discos, cable y casquillo de colgantes |
| `brushed_aluminium` | Aluminio cepillado (metallic 1, rugosidad 0.4; albedo gris algo cálido) | Sin uso por ahora (en L2b se usó en los marcos y se leía como plástico mate) |
| `lime_gloss` | Verde lima saturado y brillante | **Solo acentos**: aros finos, ribetes, remates. Nunca superficies grandes |
| `mint_soft` | Menta con clearcoat suave | Carcasas de butacas, sofás y sillas |
| `glass_clear` | Cristal (`glass.gdshader`): transparencia, Fresnel, refracción sutil | Tapas de mesa, mamparas claras |
| `glass_cyan` | Cristal cian más tintado y opaco | Cantos de cristal, mamparas y piezas de color (esferas, gotas) |
| `glass_green` | Cristal verde, mismo shader y opacidad que `glass_cyan` | Esferas y piezas de cristal verde |
| `shag_rug_swirl` | Alfombra de pelo largo en espiral cobalto → turquesa → verde (`shag_rug.gdshader`) | Alfombras; en calidad Alta añadir un nodo `ShagShells` (`scenes/fx/shag_shells.gd`) como hijo de la alfombra; sus `flatten_nodes` aplastan el pelo bajo los muebles |
| `led_cyan`, `led_green` | Emisivos | Tubos de `LedStrip` y `RoomLeds` |
| `downlight` | Emisivo cálido | Disco de los focos empotrados |
| `glow_soft` | Brillo aditivo sin luz (`glow_soft.gdshader`), más intenso en el centro de la silueta; `render_priority` 1 para verse dentro de un cristal. Color e intensidad por instancia (`glow_color`, `glow_energy`) | Núcleo de la gota colgante y brillos interiores |
| `glow_halo` | Halo aditivo en anillo sobre un quad (`glow_halo.gdshader`). Por instancia: `halo_color`, `halo_energy`, `inner_radius` | Luz que se escapa por detrás de discos y piezas retroiluminadas |
| `backlit_disc` | Fondo emisivo con degradado radial y burbujas que suben despacio (`backlit_disc.gdshader`). Por instancia: `disc_color`, `disc_energy`, `disc_seed` | Fondo de los discos de burbuja |

## Notas

- Los cristales leen la pantalla: lo transparente que quede detrás (otros cristales,
  burbujas, partículas) no se ve a través de ellos. Para variantes (otro tinte u opacidad),
  duplicar el `.tres` y ajustar sus parámetros.
- `shag_rug_swirl` dibuja el patrón en espacio local (plano XZ, centro en el origen), así
  que no necesita UV; el tamaño de los mechones y la espiral se ajustan en el material.
- Para cambiar un material en un sitio concreto sin afectar al resto, crear una variante con
  nombre propio en vez de editar el de la biblioteca. Los de color por instancia
  (`glow_soft`, `glow_halo`, `backlit_disc`) no necesitan variantes: el color se pone con
  `set_instance_shader_parameter` (lo hacen `DropPendant` y `BubbleDisc`).
- Una pieza de cristal que se apoya sobre otro cristal (esfera sobre tapa de mesa o balda)
  debe dibujarse después: `GlassOrb` usa `sorting_offset` para ello.
