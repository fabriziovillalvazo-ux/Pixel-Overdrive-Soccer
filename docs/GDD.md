# Pixel Overdrive Soccer — Documento de Diseño de Juego (GDD)

**Versión:** 1.0 · **Plataforma:** PC · **Motor:** Godot 4.x (GDScript) · **Arte:** Aseprite

> Juego de fútbol para PC con estética pixel art **"18 bits"** (arcade detallado
> estilo años 90) que combina **simulación táctica** con **jugabilidad arcade**.
> Partidas locales **Jugador vs IA**. Equipos y jugadores **100% ficticios**.
> **Sin fuera de juego** — decisión de diseño, no un olvido.

---

## 1. Visión general

| | |
|---|---|
| **Género** | Fútbol arcade con capa de simulación táctica |
| **Cámara** | Lateral clásica 2D, emulando retransmisión de TV (estilo FIFA clásicos) |
| **Controles** | Exclusivamente **teclado + ratón** (WASD + apuntado con cursor) |
| **Modos** | Solo partidas locales **Jugador vs IA enemiga**. Sin online, sin multijugador local |
| **Contenido** | Liga Overdrive: 8 equipos ficticios con jugadores y stats inventados |
| **Estética** | Pixel art "18 bits": más detalle que los 16 bits puros, animación expresiva, iluminación 2D moderna |

### 1.1 Pilares de diseño

1. **Ritmo por encima del reglamento.** Todo lo que frene el partido se recorta:
   no hay offside, los saques son rápidos, las celebraciones son cortas.
2. **La simulación se siente, no se lee.** Estamina, faltas y tácticas tienen
   efectos visibles en el campo, sin menús intermedios.
3. **Los datos mandan.** Stats, Traits y equipos viven en recursos (`.tres`);
   el código los consume pero nunca contiene valores de balance.
4. **Estrellas que se notan.** Un jugador con Trait cambia un partido, como los
   cracks de los arcades de los 90.

---

## 2. Dirección de arte

### 2.1 Estética "18 bits"

- Base **16 bits** (paletas limitadas por sprite, dithering sutil) + extras de
  hardware imposible: más frames de animación, partículas y luces dinámicas.
  De ahí el nombre: entre los 16 bits reales y los 32 bits pre-3D.
- **Resolución interna:** 640×360 (escalado entero a 1280×720 / 1920×1080).
  Filtro de texturas **Nearest** en todo el proyecto (configurado en
  `project.godot`).
- **Sprites de jugadores:** ~16×24 px, 4 direcciones + diagonales, producidos
  en **Aseprite**. Animaciones: idle, correr, sprint, tiro, pase, entrada,
  segada, salto/cabezazo, celebración, lamento.
- **Paleta global:** verdes saturados para el césped (franjas alternas de
  cortacésped), equipaciones de alto contraste, UI con negros azulados.

### 2.2 Iluminación

Con los nodos nativos de luz 2D de Godot:

- **`CanvasModulate`**: tinte ambiental de la escena (día, atardecer, nocturno).
- **`PointLight2D`**: focos del estadio en partidos nocturnos, destellos de
  flashes en goles, "estela" luminosa de los tiros con Súper Tiro.
- Sombras planas bajo jugadores y balón (la del balón encoge con la altura
  para vender la parábola de centros y pases elevados).

---

## 3. Cámara

Cámara **lateral clásica 2D** tipo retransmisión de TV (`MatchCamera`,
`scripts/match/match_camera.gd`):

- Sigue al balón con suavizado y un **adelanto** en la dirección del juego
  (~40 px) para que se vea venir la jugada.
- Movimiento vertical muy amortiguado: una cámara de TV apenas cabecea.
- Límites duros en los bordes del campo; zoom fijo (nada de zoom dinámico que
  ensucie el pixel art).

---

## 4. Controles (teclado + ratón)

El ratón **siempre apunta**: la dirección de cualquier pase, centro o tiro es
la del cursor respecto al jugador. Mapa definido en `project.godot`:

| Entrada | Acción (con balón) | Acción (sin balón / defensa) |
|---|---|---|
| **W A S D** | Mover al jugador | Mover al jugador |
| **Ratón** | Apuntar pase / centro / tiro | Orientar la entrada |
| **Clic izquierdo** | Pase raso hacia el cursor | Entrada normal (tackle en pie) |
| **Clic derecho** | Tiro a puerta hacia el cursor | Segada (slide tackle) |
| **E** | Pase elevado / centro al área | — |
| **Shift** | Sprint (consume estamina) | Sprint (consume estamina) |
| **Espacio** | — | Cambiar al jugador más cercano al balón |
| **1 / 2 / 3** | Táctica: Ofensiva / Balanceada / Defensiva | ídem |
| **Esc** | Pausa | Pausa |

- **Potencia por mantenimiento:** mantener pulsada la acción carga la potencia
  del pase/tiro (de 40% a 100% en 0,8 s); un toque corto es un pase suave. El
  indicador de apuntado del jugador controlado crece con la carga.
- No hay soporte de mando por diseño: el apuntado con ratón es el corazón del
  esquema de control.

---

## 5. Mecánicas de simulación

### 5.1 Reglas de partido — SIN fuera de juego

`scripts/systems/match_rules.gd` (`MatchRules`):

- 2 partes de duración real configurable (5 min por defecto), reloj presentado
  como 45' escalados.
- Gol, saque de banda, córner y saque de puerta detectados por posición del
  balón respecto a los límites del campo.
- **Saques arcade instantáneos:** el balón se coloca en el punto de saque y el
  jugador más cercano del equipo beneficiado recibe la posesión al momento,
  sin cinemáticas ni pausas (pilar nº 1: ritmo).
- **`OFFSIDE_ENABLED := false`** — constante documental. **No existe la regla
  de fuera de juego.** Es una decisión de diseño intencional (pilar nº 1):
  habilita desmarques profundos constantes y ritmo arcade. `is_offside()`
  existe solo para dejar constancia y devuelve siempre `false`.

### 5.2 Faltas y tarjetas por timing y ángulo

`scripts/systems/foul_system.gd` (`FoulSystem`). Cada entrada se evalúa con
una **puntuación de severidad**:

| Factor | Efecto |
|---|---|
| **Timing** | Ventana limpia de 0,15 s tras el último toque del balón; cada segundo de retraso suma severidad |
| **Ángulo** | Entrar a más de 120° (por la espalda) agrava la falta |
| **Segada** | Suma severidad frente a la entrada en pie |
| **Sprint** | Entrar lanzado suma severidad |
| **Stat de entrada** | Un buen `tackling` "perdona" hasta un 33% de la severidad |

Umbrales (exportados, ajustables desde el inspector): `severidad ≥ 1` falta,
`≥ 2` amarilla, `≥ 3,5` roja directa. Doble amarilla = roja. El sistema emite
señales (`foul_committed`, `card_shown`) que consumen el árbitro visual, el
HUD y el audio.

**Consecuencias en juego:** la falta devuelve la posesión a la víctima en el
punto de la infracción (libre arcade, sin barreras ni pausa); la roja expulsa
al jugador del campo y su equipo sigue con uno menos el resto del partido.

### 5.3 Estamina

`scripts/components/stamina_component.gd` (`StaminaComponent`):

- Reserva máxima derivada del stat `max_stamina` del jugador.
- **Consumo:** sprint (continuo), entradas y saltos (coste puntual).
- **Recuperación:** lenta trotando, más rápida parado.
- **Degradación en dos tramos** (la fatiga se nota primero en las piernas):
  - Por debajo del **60%**: degrada lo **físico** (velocidad, salto) hasta un
    suelo del 55% de rendimiento.
  - Por debajo del **35%**: degrada también lo **técnico** (tiro, pase,
    entrada, control) hasta un suelo del 70%.
- Señales `exhausted`/`recovered` para feedback visual (sprite sudando,
  parpadeo de la barra en el HUD).

### 5.4 Tácticas en partido

`scripts/systems/tactics_manager.gd` (`TacticsManager`). Tres tácticas
seleccionables al vuelo con **1 / 2 / 3**:

| Táctica | Altura de líneas | Presión | Amplitud | Apoyos al ataque |
|---|---|---|---|---|
| **Ofensiva** (1) | +20% adelantadas | ×1,25 | ×1,1 | ×1,3 |
| **Balanceada** (2) | Base | ×1,0 | ×1,0 | ×1,0 |
| **Defensiva** (3) | −20% replegadas | ×0,8 | ×0,9 | ×0,7 |

La IA enemiga tiene su propio `TacticsManager` y su entrenador virtual cambia
de táctica según marcador y minuto (pierde → ofensiva en el tramo final).

### 5.5 Traits (rasgos únicos) — multiplicador en datos

Algunos jugadores (las estrellas de cada equipo) tienen **un** rasgo especial
que multiplica su stat correspondiente por **×1,25**:

| Trait | Stat afectado | Feedback visual |
|---|---|---|
| **Súper Tiro** | `shot_power` | Estela luminosa en el disparo (PointLight2D) |
| **Súper Velocidad** | `speed` | Afterimages al esprintar |
| **Súper Salto** | `jump` | Salto con "hang time" exagerado |

**Regla de arquitectura:** el multiplicador **vive en los datos**, nunca en el
código. Cada Trait es un recurso `TraitData`
(`resources/traits/*.tres`) con `affected_stat` y `multiplier = 1.25`;
`StatsComponent` lo lee y lo aplica genéricamente. Rebalancear un Trait es
editar un `.tres`, sin tocar una línea de GDScript. Los valores efectivos
pueden superar 99 (un tiro 88 con Súper Tiro rinde 110): es intencional.

```
Stat efectivo = stat base (PlayerStats)
              × multiplicador de Trait (TraitData, si aplica al stat)
              × factor de estamina (StaminaComponent)
```

---

## 6. IA enemiga

`scripts/actors/ai_controller.gd` (`AIController`): máquina de estados por
jugador (POSITION / CHASE_BALL / ATTACK / DEFEND / SUPPORT) con tiempo de
reacción configurable. El comportamiento colectivo (altura, presión, apoyos)
se lee del `TacticsManager` del equipo, así el cambio de táctica del rival se
percibe de inmediato. Los compañeros no controlados del jugador usan la misma
IA con la táctica propia.

Dificultad (hito M3): escala con el tiempo de reacción y el error de pase de
la IA, nunca inflando stats (la IA juega con las mismas cartas).

---

## 7. Contenido: la Liga Overdrive

8 equipos **100% ficticios**, cada uno con un jugador estrella con Trait. Las
plantillas completas (11 jugadores) se generan proceduralmente con semilla
estable a partir de `roster_names` y `base_overall` (ver `SquadFactory`),
manteniendo los datos compactos.

| Equipo | Abrev. | Colores | Formación | Media | Estrella (pos.) | Trait |
|---|---|---|---|---|---|---|
| Neón City FC | NEO | Cian / Negro | 4-3-3 | 72 | Rex Voltaje (DEL) | Súper Tiro |
| Atlético Pixelia | PIX | Rojo / Blanco | 4-4-2 | 74 | Dash Kometa (DEL) | Súper Velocidad |
| Real Bitburgo | BIT | Blanco / Dorado | 5-3-2 | 76 | Magnus Torre (DEF) | Súper Salto |
| Sporting Glitch | GLI | Verde / Púrpura | 4-4-2 | 70 | Bugsy Rayo (MED) | Súper Velocidad |
| Deportivo Sprite | SPR | Azul / Amarillo | 4-3-3 | 71 | Koldo Cañón (DEL) | Súper Tiro |
| CF Vector | VEC | Naranja / Gris | 3-5-2 | 69 | Iván Órbita (DEL) | Súper Salto |
| Rayo Chiptune | CHI | Amarillo / Negro | 4-3-3 | 73 | Nino Turbo (DEL) | Súper Velocidad |
| Inter Cartucho | CAR | Granate / Azul | 4-4-2 | 75 | Marco Bláster (MED) | Súper Tiro |

Cada equipo es un `TeamData` en `resources/teams/*.tres` con su estrella
definida a mano (stats completos + referencia a su Trait).

---

## 8. Arquitectura técnica

### 8.1 Stack

- **Godot 4.x + GDScript** — gratuito, ideal para 2D pixel art; su sistema de
  nodos y señales encaja con la arquitectura por componentes.
- **Aseprite** para sprites y animaciones.
- **Renderer GL Compatibility**, filtro Nearest, viewport 640×360 con stretch
  `canvas_items`.

### 8.2 Arquitectura por componentes

Los actores se montan componiendo nodos; los sistemas se comunican por
**señales**, nunca por acoplamiento directo:

```
Match (MatchManager) ......... orquestador: marcador, reloj, saques
├── MatchRules ............... reglas (gol/saques; OFFSIDE_ENABLED = false)
├── FoulSystem ............... severidad de entradas → faltas/tarjetas
├── TacticsManager (×2) ...... táctica del jugador y de la IA
├── Field .................... terreno de juego (dibujo procedural)
├── Ball ..................... física arcade + altura simulada
├── MatchCamera .............. cámara lateral de TV
├── HUD (CanvasLayer) ........ marcador, reloj, estamina, táctica
└── Player (×22) ............. instancias de player.tscn
    ├── StatsComponent ....... stats efectivos (base × Trait × estamina)
    ├── StaminaComponent ..... consumo/recuperación y degradación
    └── (AIController) ....... para los no controlados por el usuario
```

Capa de datos (recursos, editables sin tocar código):

```
PlayerStats (.gd) ─ carta base 1-99 + referencia a TraitData
TraitData   (.gd) ─ stat afectado + multiplicador (×1,25 en los .tres)
TeamData    (.gd) ─ identidad, formación, estrella y nombres de plantilla
```

### 8.3 Estructura de carpetas

```
project.godot            configuración (input map, pixel art, autoloads)
docs/GDD.md              este documento
scenes/                  main / match / actors / ui
scripts/
  autoload/game_state.gd     estado global: liga cargada, equipos elegidos
  components/                StatsComponent, StaminaComponent
  systems/                   FoulSystem, TacticsManager, MatchRules, SquadFactory
  actors/                    PlayerCharacter, Ball, AIController
  match/                     MatchManager, Field, MatchCamera
  main/ · ui/                menú y HUD
  resources/                 scripts de PlayerStats, TraitData, TeamData
resources/
  traits/*.tres              los 3 Traits (multiplicador ×1,25 EN DATOS)
  teams/*.tres               los 8 equipos de la Liga Overdrive
assets/                  sprites (Aseprite), audio, fuentes
```

### 8.4 Ejemplo del contrato clave (stats efectivos)

```gdscript
# StatsComponent.get_stat() — sin números mágicos:
var value := float(stats.get(stat_name))
if stats.has_trait() and stats.special_trait.affected_stat == stat_name:
    value *= stats.special_trait.multiplier   # ×1,25 leído del .tres
if stamina_component != null:
    value *= stamina_component.get_performance_factor(stat_name)
return value
```

---

## 9. UI / HUD

- **Marcador** (arriba, centro): `NEO 2 - 1 PIX` + reloj escalado a 45'/parte.
- **Barra de estamina** (abajo-izquierda) del jugador controlado; parpadea en
  rojo por debajo del 35% (umbral técnico).
- **Táctica activa** (abajo-derecha): `TÁCTICA: OFENSIVA`.
- **Tarjetas**: overlay breve con el sprite del árbitro mostrando la cartulina.
- Menú principal (M4): selección de equipo de la liga con escudos pixelados.

## 10. Audio (resumen)

Chiptune "18 bits": módulos estilo tracker para menús, ambiente de estadio en
bucle con oleadas al atacar, SFX de golpeo con más graves cuanto mayor sea la
potencia efectiva del tiro (los Súper Tiros suenan a cañonazo).

---

## 11. Roadmap

| Hito | Contenido | Estado |
|---|---|---|
| **M1 — Esqueleto** | Proyecto Godot 4, arquitectura, datos de la liga, GDD | ✅ este commit |
| **M2 — Balón y acciones** | 11 vs 11 en campo, posesión, pase/tiro/centro con carga, saques, faltas y expulsiones en juego, IA funcional con entrenador virtual | ✅ |
| **M3 — IA fina y reglas** | Marcajes y coberturas, porteros con paradas por stats, niveles de dificultad, cambio de campo al descanso | ⬜ |
| **M4 — Presentación** | Sprites Aseprite, animaciones, luces, menú de selección, audio | ⬜ |
| **M5 — Pulido** | Balance de stats/Traits, repeticiones de gol, export final | ⬜ |
