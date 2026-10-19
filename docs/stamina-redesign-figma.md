# Stamina — rediseño iOS en Figma

**Archivo:** [Stamina en Figma](https://www.figma.com/design/TeWZt5hDZFrPFD2qYdpaiU/Stamina)  
**Referencia:** editorial de running aportada por el usuario. Se toma su energía visual (marfil, rojo profundo, negro, titulares amplios y métricas protagonistas), sin usar PANTONE como marca de la app.  
**Estado:** propuesta de diseño y entrega visual. Los datos de las pantallas son ejemplos; el código de producción no se modificó.

## 1. Estructura del archivo

| Página | Contenido | Cómo usarla |
| --- | --- | --- |
| `00 · Fundamentos` | Paleta, contraste, tipografía, espaciado y criterios de accesibilidad. | Consultar antes de dibujar una pantalla nueva. |
| `01 · Componentes` | Botones, tarjetas de sesión y navegación inferior, con variantes y un tablero de ejemplos. | Crear instancias y cambiar texto o estado desde la instancia. |
| `02 · Flujos y entrega` | Cinco marcos iPhone de 393 × 852: Inicio, Entreno activo, Plan, Nutrición y Perfil. | Duplicar un marco de la misma familia para estados vacíos, error y carga. |

La limitación de tres páginas del plan de Figma se resuelve agrupando los flujos y la entrega en una sola página. Los marcos y componentes tienen nombres semánticos para encontrarlos desde Capas o Recursos.

## 2. Relación con la app actual

La navegación se tomó de [`RaizHomeView.swift`](../ios/Trainer/Trainer/Pantallas/Home/RaizHomeView.swift). La barra conserva **Inicio, Plan, Entreno, Nutrición y Perfil**. Entreno es la acción central y su sesión en curso se presenta a pantalla completa, sin barra inferior. Gimnasio se abre desde la agenda y Ajustes desde Perfil. Registrar comida abre una hoja modal.

| Marco de Figma | Flujo de código que representa | Elementos preservados |
| --- | --- | --- |
| Inicio · sesión de hoy | `InicioView.swift` | Próxima sesión, progreso, agenda y acceso a historial. |
| Entreno · en curso | `EntrenoView` | Ruta, distancia, tiempo, ritmo, calorías y controles Pausar/Finalizar. |
| Plan · semana | `PlanView.swift` | Sesiones del plan y sus tipos, con acceso a historial. |
| Nutrición · hoy | `NutricionView.swift` | Meta de energía, comidas y registro modal. La app actual también muestra macros e hidratación; esas secciones deben conservarse al implementar el rediseño. |
| Perfil · metas y ajustes | `PerfilView.swift` | Datos corporales, metas, agenda de entrenamiento y acceso a Ajustes. |

En Perfil no se añadieron logros ficticios al producto: el historial está en Inicio y Plan. Las cifras y el nombre del ejemplo deben vincularse a los modelos existentes antes de implementar las vistas.

## 3. Tokens y estilos

Las colecciones de variables en Figma son `Primitivos`, `Semánticos Claro`, `Semánticos Oscuro` y `Medidas`. Para una pantalla nueva, usar roles semánticos en rellenos y texto; reservar los primitivos para definir esos roles.

| Rol de la propuesta | Valor claro | Uso |
| --- | --- | --- |
| `fondo/primario` | `#F7F4EF` | Fondo de pantallas. |
| `superficie/primaria` | `#FFFFFF` | Tarjetas y barra inferior. |
| `texto/primario` | `#171719` | Titulares, métricas y cuerpo principal. |
| `texto/secundario` | `#56545A` | Ayuda y metadatos. |
| `accion/primaria` | `#9F1724` | Botones, selección y tarjeta destacada. |

La guía del archivo documenta contraste aproximado de 8:1 para blanco sobre rojo y 6,8:1 para texto secundario sobre marfil. Mantener la misma lectura al crear estados nuevos; no comunicar progreso, error o selección únicamente con color.

**Tipografía.** El archivo incluye los estilos `Stamina/Display` 36/42, `Título` 28/34, `Sección` 20/26, `Cuerpo` 17/24, `Apoyo` 15/21, `Etiqueta` 13/18 y `Métrica` 40/44. El carácter editorial usa Archivo en el diseño. Para portar a SwiftUI, empaquetar la fuente y registrar variantes escalables con Dynamic Type; no depender de la red para cargarla. Los números de distancia, tiempo y kcal deben ser tabulares.

**Espaciado y forma.** La base es 4 pt, con pasos de 8, 12, 16, 24 y 32 pt. El margen de pantalla es 16 pt; las tarjetas usan esquinas redondeadas cercanas a 18 pt y los botones primarios son tipo cápsula. La sombra queda reservada para superficies flotantes: fondo, superficie y borde fino deben resolver la jerarquía ordinaria.

**Dos temas.** La colección oscura ofrece una base de variables para revisar la interfaz en modo oscuro. Las cinco pantallas son la propuesta clara; falta diseñar y verificar cada pantalla oscura antes de considerarla lista para implementación.

## 4. Construcción y mantenimiento de componentes

1. En `01 · Componentes`, abrir `Stamina / Button`. Usar la variante primaria para la acción principal, la secundaria para una acción equivalente de menor peso y la deshabilitada cuando la acción no está disponible. Conservar altura interactiva mínima de **44 pt** y texto verbal.
2. Usar `Stamina / Session card` para sesión próxima o elemento de plan. La variante roja destaca la próxima acción; la clara mantiene una lectura secundaria. Sustituir texto y datos de ejemplo sin desvincular la instancia.
3. Usar `Stamina / Bottom navigation` con las cinco áreas actuales. El destino activo combina color con texto/icono; el botón central Entreno mantiene una zona táctil propia. Ocultar la barra durante una sesión activa, igual que en `RaizHomeView`.
4. Al añadir estados, agrupar variantes por **tipo**, **estado** y, si corresponde, **tema**. Nombrar capas internas (`Título`, `Descripción`, `Indicador`, `Acción`) para que las instancias sean editables y comprensibles para desarrollo.
5. Aplicar Auto Layout a tarjetas, filas y secciones antes de convertir un marco nuevo en componente. Permitir que el texto crezca; evitar alturas cerradas alrededor de párrafos.

## 5. Revisión de accesibilidad iOS

- Conservar áreas táctiles de al menos 44 × 44 pt, safe areas y separación suficiente entre acciones cercanas.
- Comprobar Dynamic Type grande: titulares deben envolver líneas y las tarjetas crecer en altura. Los rótulos de 13 pt se reservan para metadatos; acciones y contenido principal deben tener tamaños superiores.
- Exponer encabezados y etiquetas de accesibilidad para métricas, navegación y controles. En VoiceOver, anunciar valor y unidad juntos: “Distancia, 5 coma 12 kilómetros”.
- Mantener texto o icono junto al color para estado activo, progreso, pausa, error o éxito.
- Respetar Reducir movimiento al portar transiciones. La sesión y sus controles deben seguir legibles sin animación.

## 6. Paso de Figma a producción

El proyecto ya tiene una fuente de tokens en [`shared/design/tokens.json`](../shared/design/tokens.json) y una paleta SwiftUI en [`Paleta.swift`](../ios/TrainerCore/Sources/TrainerCore/Tema/Paleta.swift). La propuesta roja y clara **difiere del sistema actual**, cuyo acento canónico es verde y cuya paleta SwiftUI adapta vistas claras y oscuras; implementarla requiere una decisión de producto y una migración coordinada de tokens, Assets.xcassets, clientes generados y pruebas de contraste. No copiar hexadecimales en cada vista. Según las instrucciones del repositorio, un cambio de `shared/design/tokens.json` debe regenerar los clientes en el mismo cambio.

Secuencia sugerida: aprobar paleta y tipografía → reconciliar tokens compartidos y variantes claro/oscuro → portar componentes SwiftUI → integrar las cinco vistas conservando navegación y modelos → verificar Dynamic Type, VoiceOver, contraste y estados sin conexión. Esta entrega se detiene en el diseño editable de Figma y su especificación; no sustituye esa integración.
