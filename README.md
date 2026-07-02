# Pixel Overdrive Soccer

Juego de fútbol para PC con estética pixel art **"18 bits"** (arcade detallado
estilo años 90) que combina simulación táctica con jugabilidad arcade.
Partidas locales **Jugador vs IA**, con equipos y jugadores 100% ficticios.

> 📖 Documento de diseño completo: [`docs/GDD.md`](docs/GDD.md)

## Características clave

- **Cámara lateral clásica 2D** emulando retransmisión de TV (estilo FIFA clásicos).
- **Solo teclado + ratón**: WASD para mover, el ratón apunta pases/centros/tiros,
  clic izquierdo/derecho para las acciones.
- **Sin fuera de juego (offside)** — decisión de diseño intencional para
  mantener el ritmo arcade.
- **Faltas y tarjetas** evaluadas por el timing y el ángulo de las entradas.
- **Estamina** que degrada el rendimiento físico y técnico del jugador.
- **Tácticas en vivo**: Ofensiva / Balanceada / Defensiva (teclas 1/2/3).
- **Achique del portero**: mantener Espacio para que el portero (IA) salga a
  tapar; Q cambia de jugador.
- **Partidos de día, atardecer o noche** (con focos de estadio) configurables
  en Ajustes, y cambio de campo clásico al descanso.
- **Ambiente de estadio** con gritos de la afición en goles, faltas y saques
  iniciales (sintetizado en tiempo real, sin assets).
- **Traits**: rasgos únicos (Súper Tiro, Súper Velocidad, Súper Salto) que
  multiplican el stat por ×1,25 — el multiplicador vive en los datos
  (`resources/traits/*.tres`), no en el código.
- **Liga Overdrive**: 8 equipos ficticios con sus jugadores estrella.
- **Modo Historia**: temporada de 14 jornadas con clasificación y 3 slots de
  guardado; **Amistoso** aparte para partidos casuales.

## Ejecutar el proyecto

1. Instalar [Godot 4.3+](https://godotengine.org/download) (rama estándar, GDScript).
2. Abrir el gestor de proyectos de Godot → *Importar* → seleccionar `project.godot`.
3. Pulsar **F5** para ejecutar (escena principal: `scenes/main/main.tscn`).

## Estructura

```
docs/GDD.md      documento de diseño (arte, mecánicas, arquitectura, liga)
scenes/          escenas: menú, partido, actores, HUD
scripts/         GDScript por capas: autoload, components, systems, actors, match, ui
resources/       datos .tres: Traits (×1,25) y los 8 equipos de la liga
assets/          sprites (Aseprite), audio y fuentes
```

## Stack

- **Godot 4.x** con **GDScript** (renderer GL Compatibility, filtro Nearest,
  viewport 640×360).
- **Aseprite** para el pixel art.
- Iluminación con nodos nativos de luz 2D (`PointLight2D`, `CanvasModulate`).
