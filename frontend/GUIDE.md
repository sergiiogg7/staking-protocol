# Guía del frontend

Material de estudio del frontend, escrito módulo a módulo mientras se construye. Cada módulo explica un concepto con analogías Java/backend, recorre el código real del proyecto y cierra con un experimento, preguntas de control y una frase de entrevista.

| # | Módulo | Estado |
|---|---|---|
| 0 | Herramientas: npm, Vite, tsc | hecho |
| 1 | El arranque: `index.html` → `main.tsx` → `App`, StrictMode y providers | hecho |
| 2 | Componentes y estado | hecho |
| 3 | Hooks y TanStack Query | hecho |
| 4 | La pila web3: viem, wagmi, `wagmi.ts`, `contracts.ts` y el ABI | hecho |
| 5 | Los playgrounds | pendiente |
| 6 | Un clic de punta a punta, visto en la pestaña Network | pendiente |
| 7 | Las posiciones: datos derivados de eventos, funciones puras y un hook fino | hecho |
| 8 | Las acciones: simular, firmar, esperar y la máquina de estados | hecho |

---

## Módulo 0: herramientas

### La idea en una frase

En Java, Maven hace todo (dependencias, compilar, probar, empaquetar). En el mundo Node esas tareas las reparten **tres herramientas** distintas, y el proyecto las encadena con *scripts*.

### Mapa Maven ↔ npm

| Java / Maven | Frontend | Qué es aquí |
|---|---|---|
| Maven Central | registro de npm | De dónde se descargan los paquetes |
| `pom.xml` | `package.json` | Dependencias y scripts. No tiene ciclo de vida: los scripts son comandos libres |
| versión `[2.57.14,3)` | `"viem": "^2.57.14"` | `^` admite versiones compatibles (misma versión mayor) |
| lockfile / `dependencyManagement` | `package-lock.json` | Versión exacta de **cada** paquete, directo o transitivo |
| `~/.m2` (compartido) | `node_modules/` (por proyecto) | Copia local de los paquetes, dentro del proyecto |
| `mvn install` | `npm install` / `npm ci` | `npm ci` instala exactamente lo del lockfile (lo que usa un CI) |
| `mvn package` | `npm run build` | Genera lo que se despliega |
| JVM | **Node.js** | Ejecuta las herramientas. La aplicación corre en el navegador |

### Las tres herramientas y qué hace cada una

```
                       ┌────────────────────────────────────────────────┐
   package.json ─────► │ npm   descarga los paquetes en node_modules/   │
                       └────────────────────────────────────────────────┘

   *.ts / *.tsx ─────► tsc    ¿los tipos cuadran?   (solo comprueba, no genera nada)

   *.ts / *.tsx ─────► Vite   convierte TypeScript y JSX en JavaScript,
                              sirve la app en desarrollo y la empaqueta para producción
```

- **npm**: gestor de dependencias y ejecutor de scripts. No compila nada.
- **tsc** (TypeScript 7): comprobador de tipos. En `tsconfig.app.json` figura `"noEmit": true`, así que **no genera archivos**, solo dice si hay errores.
- **Vite** (8.3.5): servidor de desarrollo y empaquetador. Su empaquetador es Rolldown (escrito en Rust).
- **oxlint**: el linter (como Checkstyle).

En Java, `javac` comprueba y compila a la vez. Aquí el trabajo está **partido**: `tsc` comprueba, Vite transforma.

### Los scripts de `package.json`

```json
"dev":     "vite",                     // servidor de desarrollo
"build":   "tsc -b && vite build",     // comprueba tipos y, si pasa, empaqueta
"lint":    "oxlint",
"preview": "vite preview"              // sirve dist/ para probar la versión de producción
```

`&&` en `build` significa que si `tsc` falla, **no se empaqueta nada**.

### Modo desarrollo frente a modo producción

```
npm run dev                                   npm run build
───────────                                   ─────────────
Navegador ──GET /src/main.tsx──► Vite         tsc -b            (¿tipos bien? si no, para)
Navegador ──GET /src/App.tsx───► Vite            │
Navegador ──GET /src/wagmi.ts──► Vite            ▼
   (un archivo por petición,                  vite build        (Rolldown junta todo,
    convertido al vuelo a JavaScript)                            elimina lo no usado,
                                                                 minimiza y pone hash)
Cambias un archivo → el navegador                  │
se actualiza solo (HMR), sin recargar              ▼
                                              dist/  ← archivos estáticos
```

Por qué el servidor de desarrollo arranca en milisegundos (239 ms con el proyecto vacío): **no empaqueta nada**. Los navegadores modernos entienden `import`, así que Vite solo transforma cada archivo cuando se lo piden.

### Lo que se midió en este proyecto

- **Dependencias**: 12 directas (`npm ls --depth=0`) que arrastran unas **544 entradas** en el lockfile y 262 carpetas de primer nivel en `node_modules/`. Un frontend moderno trae muchas dependencias transitivas.
- **Lo que sirve Vite** para `src/main.tsx`: el JSX ya son llamadas `_jsxDEV(...)`, los tipos han desaparecido, y `import ... from "react"` se ha reescrito a `/node_modules/.vite/deps/react.js?v=...`. Vite *preempaqueta* las librerías de `node_modules` porque vienen en muchos archivos pequeños.
- **Resultado de `npm run build`** (`dist/`): `index.html` (461 bytes), un CSS (584 bytes) y `assets/index-DOpeMFCr.js` (**412 855 bytes**). Es todo estático: se sirve desde cualquier hosting sin servidor. El nombre lleva un *hash* del contenido para que el navegador no use una versión vieja en caché.

### Experimento: ¿quién detecta un error de tipos?

Se creó un archivo con `const edad: number = "hola";`.

| Herramienta | Resultado |
|---|---|
| Vite (desarrollo) | **HTTP 200**, sirvió `const edad = "hola";`: quitó el tipo sin comprobarlo |
| `tsc -b` | `error TS2322: Type 'string' is not assignable to type 'number'` |

Moraleja: **el servidor de desarrollo no comprueba tipos**. Los errores te los dan tu editor (subrayados rojos) y `npm run build`. Por eso el `build` empieza con `tsc -b`.

### Node frente al navegador

Node es el **entorno de ejecución de las herramientas** (npm, Vite y tsc corren en Node, como Maven corre en la JVM). La aplicación que escribimos corre en el **navegador**. Los scripts de `src/playground/` son la excepción: se ejecutan directamente en Node.

### Qué es "empaquetar" (y qué no)

Aquí se confunde fácilmente con el empaquetado de Java, así que conviene dejarlo claro.

| | Java | Frontend (SPA) |
|---|---|---|
| Resultado | jar o binario, normalmente dentro de una imagen Docker | carpeta `dist/` con HTML, CSS y JS |
| ¿Qué es? | código compilado | **texto**: JavaScript minimizado (`JavaScript source, ASCII text`) |
| ¿Dónde se ejecuta? | en tu **servidor** (JVM) | en el **navegador de cada usuario** |
| ¿Hace falta un runtime en producción? | sí (JVM) | **no hay Node**; solo un servidor de archivos estáticos |

Empaquetar (*bundling*) **no es compilar a binario**: es convertir JavaScript en JavaScript más compacto. Junta los cientos de módulos y paquetes en unos pocos archivos, elimina el código que nadie usa (*tree shaking*), lo minimiza y le pone un hash al nombre. Se hace para que el navegador descargue poco y en pocas peticiones. Tu proyecto: 544 paquetes y tu código quedan en **un** archivo de 412 855 bytes y 35 líneas, en el que sigue apareciendo el texto `Stake per position` de `ProtocolStats`.

```
 DESARROLLO (tu máquina)                              PRODUCCIÓN
 ┌──────────────── Node ────────────────┐             ┌── hosting estático / CDN ──┐
 │ Vite (servidor, :5173)               │             │  index.html, *.js, *.css    │
 └──────────────────┬───────────────────┘             └──────────────┬──────────────┘
                    │ HTTP: envía archivos                           │ HTTP: envía archivos
                    ▼                                                ▼
 ┌─────────────── Navegador ────────────┐             ┌────────── Navegador ────────┐
 │ aquí SE EJECUTA la app (motor JS)    │             │ aquí SE EJECUTA la app      │
 └──────────────────┬───────────────────┘             └──────────────┬──────────────┘
                    └──── JSON-RPC ──► nodo Anvil          └── JSON-RPC ──► nodo de la red
```

La app corre siempre en el navegador. Node solo aparece en desarrollo, como servidor de archivos. Esto es lo que diferencia una SPA de un framework con renderizado en servidor (Next.js), que sí necesita Node en producción.

### Tres trabajos distintos, y qué llega al navegador

"Traducir" y "empaquetar" no son lo mismo:

| Trabajo | Qué hace | Ejemplo | ¿Cuándo? |
|---|---|---|---|
| **Transformar** | TypeScript y JSX → JavaScript normal; quita los tipos | `const x: number = 1` → `const x = 1` | dev y build |
| **Empaquetar** | Junta cientos de módulos en pocos archivos | tu código + 544 paquetes → 1 archivo | solo build |
| **Optimizar** | Quita lo que nadie usa, minimiza y pone hash | 412 855 bytes, 35 líneas | solo build |

Y cada cosa del proyecto es de un tipo distinto:

| Qué es | Ejemplos | ¿Llega al navegador? |
|---|---|---|
| Lenguaje | TypeScript, JSX | **No**: desaparece en el build; el navegador nunca ve un tipo |
| Librerías | React, viem, wagmi, TanStack Query | **Sí**: están dentro de los 412 KB |
| Herramientas de build | npm, `tsc`, Vite, oxlint | **No**: solo viven en tu máquina |
| Entorno de ejecución | Node (para las herramientas), navegador (para la app) | — |

El navegador **interpreta** HTML y CSS (pinta la página) y **ejecuta** JavaScript con su motor (V8 en Chrome). Cuando un frontend "pesa mucho", pesan las librerías, no TypeScript.

### Preguntas de control

1. ¿Qué diferencia hay entre `npm run dev` y `npm run build`, y por qué el primero arranca mucho más rápido?
2. Si cambias una función de `string` a `number` y rompes una llamada, ¿qué te avisa en desarrollo y qué en el build?
3. ¿Qué es `package-lock.json` y por qué un CI usaría `npm ci` y no `npm install`?

### Frase de entrevista

"En el frontend las responsabilidades de Maven están repartidas: npm gestiona dependencias, `tsc` comprueba tipos, y Vite sirve la app en desarrollo sin empaquetar y la empaqueta para producción. El build encadena `tsc` y Vite, porque el servidor de desarrollo no comprueba tipos."

---

## Módulo 1: el arranque

### La cadena completa

```
 el navegador pide /
        │
        ▼
 index.html        <div id="root"></div>  vacío
 (líneas 10-11)    <script type="module" src="/src/main.tsx">
        │ el navegador descarga y ejecuta main.tsx
        ▼
 main.tsx          createRoot(#root).render( ...providers... <App /> )
 (líneas 12-20)
        │ React construye el árbol de componentes
        ▼
 App.tsx           <ConnectButton />  <ProtocolStats />   →  React los convierte en HTML dentro de #root
```

- `index.html` es la única página. Está vacía a propósito: solo trae un contenedor (`#root`) y la etiqueta que carga el JavaScript. Todo lo que ves lo pinta React después.
- `main.tsx` **no es un componente**: es el punto de entrada, el `main()` de la aplicación. Se ejecuta una vez y monta React en `#root`.
- `App.tsx` es el **componente raíz**: de él cuelga todo lo demás.
- `document.getElementById("root")!`: el `!` le dice a TypeScript que no es `null`. Es como `Optional.get()`: si el contenedor no existiera, fallaría al arrancar.
- `import "./index.css"` se importa solo por su efecto: Vite inyecta los estilos (en el build los extrae a un `.css`).

### Qué es un provider (la analogía con Spring)

React tiene un mecanismo llamado **Context**: permite que un componente ponga un dato a disposición de **todo su subárbol** sin pasarlo por cada nivel (evita el *prop drilling*). Un **provider** es el componente que lo publica; los **hooks** son los que lo leen.

| Spring | React |
|---|---|
| `ApplicationContext` con beans | árbol de providers |
| `@Bean` / configuración | `<WagmiProvider config={config}>` |
| `@Autowired` / inyección | un hook (`useConfig()`, `useQuery()`) que lee el contexto |
| solo ven el bean los componentes dentro del contexto | solo ven el dato los componentes **dentro** del provider |
| `NoSuchBeanDefinitionException` | `useConfig must be used within WagmiProvider` |

El árbol de `main.tsx`:

```
<StrictMode>                       comprobaciones extra solo en desarrollo
  <WagmiProvider config>           publica la configuración de wagmi (cadenas, wallets)
    <QueryClientProvider client>   publica la caché de lecturas (TanStack Query)
      <App />
         ├─ <ConnectButton />      lee la config con useAccount, useConnect...
         └─ <ProtocolStats />      lee la config y la caché con useStakingConfig
```

### Experimento (ejecutado sobre el hook real `useStakingConfig`)

| Intento | Resultado |
|---|---|
| 1. sin ningún provider | `ERROR: useConfig must be used within WagmiProvider` |
| 2. solo `WagmiProvider` | `ERROR: No QueryClient set, use QueryClientProvider to set one` |
| 3. los dos providers | `<p>useStakingConfig ran, isPending=true</p>` |

Un solo hook necesita **dos** providers, porque `useReadContracts` usa la configuración de wagmi y la caché de TanStack Query. Es el error más típico al montar una dApp.

### StrictMode

Es un componente que **no pinta nada**. Solo en desarrollo hace que React ejecute dos veces las funciones de los componentes y monte, desmonte y vuelva a montar los efectos. Su objetivo es destapar código impuro o que no limpia lo que abre. Es como ejecutar Java con `-ea` (aserciones activas): en el build de producción no hace nada. Si ves un `console.log` duplicado en desarrollo, es esto.

### Experimento para hacer en tu navegador

1. Con `npm run dev`, añade `console.log("render")` al principio de `ProtocolStats`: en la consola verás el mensaje **dos veces**.
2. Quita `<StrictMode>` de `main.tsx`: se verá una sola vez.
3. Restáuralo. Con `npm run build` y `npm run preview` también sale una sola vez, porque en producción StrictMode no actúa.

### Preguntas de control

1. ¿Por qué `index.html` está casi vacío y quién pinta lo que ves en pantalla?
2. ¿Por qué el orden `WagmiProvider` → `QueryClientProvider` → `App` importa, y qué pasaría si `App` estuviera fuera de ellos?
3. ¿Qué hace `StrictMode` y por qué no afecta a producción?

### Frase de entrevista

"`main.tsx` monta React en un contenedor vacío de `index.html` y envuelve la app en providers, que son Context de React: publican dependencias (la configuración de wagmi y la caché de TanStack Query) para todo el subárbol, como los beans de Spring. Los hooks las consumen, y si falta un provider fallan con un error explícito."

---

## Módulo 2: componentes y estado

### Un componente es una función que devuelve la interfaz

```
   datos (props + estado) ───►  función del componente  ───►  JSX (descripción de la interfaz)
                                                                   │
                                                  React lo compara con lo anterior y
                                                  actualiza solo lo que cambió en el DOM
```

La idea central de React: **la interfaz es una función del estado**. No tocas el DOM a mano: describes cómo debe verse para cada estado y React se encarga de llegar ahí. El nombre del componente empieza por mayúscula (`ConnectButton`), y debe ser una función **pura**: mismos datos, mismo JSX, sin efectos secundarios al renderizar (StrictMode lo vigila).

### JSX son llamadas a funciones

Compilado con `tsc --jsx react-jsx` (lo mismo que hace Vite):

```tsx
// entrada
<p className="saludo">Hola, {nombre}</p>
<Saludo nombre="Sergio" />
```
```js
// salida que recibe el navegador
_jsxs("p", { className: "saludo", children: ["Hola, ", nombre] })
_jsx(Saludo, { nombre: "Sergio" })
```

- Los atributos se convierten en un objeto de **props**: `{ nombre: "Sergio" }`.
- Lo que va dentro de las etiquetas llega como la prop `children`. Así funcionan los providers: `<WagmiProvider config={config}>…</WagmiProvider>` recibe `config` y `children`.
- Entre llaves `{}` va cualquier expresión de JavaScript. `className` en lugar de `class`.

### Props y estado

| | Props | Estado |
|---|---|---|
| Qué es | entradas que **recibe** el componente | memoria que el componente **conserva** entre renders |
| Analogía Java | parámetros del método / constructor | campos de la instancia |
| Quién lo cambia | el componente padre | el propio componente (o un hook) |
| ¿Mutable? | solo lectura | se cambia con una función `setX`, que provoca un nuevo render |

El ciclo de un cambio de estado:

```
   evento (clic, respuesta de red)
        │  setState / un hook cambia su estado
        ▼
   React vuelve a llamar a la función del componente
        │  las variables locales se recrean; el estado persiste
        ▼
   devuelve JSX nuevo → React compara con el anterior → actualiza solo el DOM que cambió
```

### Dónde vive el estado en este proyecto

Los componentes de `ConnectButton` y `ProtocolStats` **no usan `useState`**. Su estado vive en otros sitios y los hooks se lo entregan:

| Tipo de estado | Dónde vive | Quién lo expone |
|---|---|---|
| Local de un componente | memoria de React, con `useState` | (todavía no hay ninguno) |
| Conexión de wallet | almacén de wagmi (`config`) | `useAccount`, `useConnect`... |
| Datos leídos de la cadena | caché de TanStack Query | `useReadContracts` dentro de `useStakingConfig` |

### Por qué `ConnectButton` tiene varios estados

Conectar una wallet es **asíncrono y puede fallar**. La interfaz debe decir la verdad en cada momento (no dejar pulsar dos veces, mostrar el error). Cada `if` con `return` es un estado:

```
 sin conectar ──connect()──► conectando ──ok, red soportada──► conectado ──disconnect──► sin conectar
 (líneas 14-25)              (isPending)                       (líneas 41-50)
                                  └──ok, red NO soportada──► red equivocada ──switchChain──► conectado
                                                              (líneas 28-39)
 (si connect falla, el error aparece junto al botón: línea 22)
```

| Estado | Condición | Lo que se pinta |
|---|---|---|
| Sin conectar | `!isConnected` | botón "Connect wallet" |
| Conectando | `isPending` | botón desactivado "Connecting…" |
| Red equivocada | conectado pero `!chain` | botón "Switch to Foundry" y "Disconnect" |
| Conectado | todo lo demás | dirección abreviada, nombre de la red y "Disconnect" |
| Error | `error` | mensaje rojo bajo el botón |

`ProtocolStats` tiene tres: cargando (`isPending`), error (`error`) y datos. Las condiciones van **de más específica a más general** y cada una devuelve (guard clauses, como en Java).

### Resultado de renderizar los componentes reales (con una wallet simulada)

| Estado | HTML generado |
|---|---|
| ProtocolStats, leyendo | `<p>Loading protocol settings…</p>` |
| ConnectButton, sin conectar | `<div class="connect"><button>Connect wallet</button></div>` |
| ConnectButton, conectado | `…<span title="0x7099…">0x7099…79C8 · Foundry</span><button class="secondary">Disconnect</button>…` |
| ConnectButton, red no soportada | `<button>Switch to Foundry</button><button class="secondary">Disconnect</button>` |

### Detalles de código que aparecen en estos archivos

- `const { address, chain, isConnected } = useAccount();` es desestructurar el objeto que devuelve el hook. `isPending: isSwitching` renombra el campo para no chocar con otro `isPending`.
- `{error && <p>…</p>}`: si `error` es falso no se pinta nada. Es la forma habitual de renderizado condicional.
- `onClick={() => connector && connect({ connector })}`: se pasa una **función** (no se ejecuta al pintar). El `connector &&` es una guarda para TypeScript.
- `disabled={!connector || isPending}`: evita pulsar mientras la operación está en curso.

### Preguntas de control

1. ¿Qué dos cosas devuelve el hook `useAccount` que `ConnectButton` usa para decidir qué pintar, y por qué hay que tratar `isPending` aparte?
2. Si un componente es "una función del estado", ¿por qué no se modifica el DOM a mano?
3. ¿En qué se diferencia que el estado de la wallet viva en wagmi, y no en un `useState` dentro de `ConnectButton`?

### Frase de entrevista

"Un componente de React es una función pura de sus props y su estado que devuelve JSX; React compara el resultado con el anterior y actualiza solo el DOM que cambió. En `ConnectButton` modelé cada estado de la conexión (sin conectar, conectando, red equivocada, conectado y error) con retornos tempranos, porque una operación de wallet es asíncrona y puede fallar."

---

## Módulo 3: hooks y TanStack Query

### Qué es un hook

Una función de componente se vuelve a ejecutar entera en cada render, así que no puede guardar nada en variables locales. Un **hook** es una función cuyo nombre empieza por `use` y que le pide a React un recurso que **sobrevive entre renders**: memoria (`useState`), un contexto (`useContext`), una acción tras pintar (`useEffect`)...

| Tipo | Ejemplos | Quién lo escribe |
|---|---|---|
| Hooks de React | `useState`, `useEffect`, `useContext` | React |
| Hooks de librerías | `useAccount`, `useReadContracts` | wagmi, TanStack Query |
| Hooks propios (*custom*) | `useStakingConfig` | tú: una función que combina otros hooks |

### Las reglas de los hooks y por qué existen

1. Se llaman **siempre en el nivel superior** del componente: nunca dentro de `if`, bucles o funciones anidadas.
2. Solo desde componentes u otros hooks.

React no identifica un hook por su nombre sino por **el orden en que se llama** dentro del componente:

```
 render 1:  [useState] [useContext] [useQuery]      ← React guarda 3 "huecos" en ese orden
 render 2:  [useState] [useContext] [useQuery]      ← cada llamada recoge su hueco: correcto

 si una llamada estuviera dentro de un if:
 render 2:  [useState]            [useQuery]        ← useQuery recogería el hueco de useContext: roto
```

Comprobado con el linter (`oxlint`) sobre un componente que llama a `useState` dentro de un `if`:
`error react-hooks(rules-of-hooks): React Hook "useState" is called conditionally. React Hooks must be called in the exact same order in every component render.`

Si en el módulo 1 viste que un hook falla sin provider, aquí ves la otra restricción: dónde se pueden llamar.

### `useEffect` (aún no lo usamos)

Ejecuta código **después** de pintar, para sincronizarse con algo externo (suscribirse a un evento, abrir un socket). Recibe una lista de dependencias y puede devolver una función de limpieza. Se menciona porque es el hook que se usaba antes para pedir datos; hoy la recomendación es **no hacerlo así** y usar una librería de consultas (TanStack Query).

### Un hook propio: `useStakingConfig`

`src/hooks/useStakingConfig.ts`:

- **Línea 5**: `stakingApp` agrupa dirección y ABI para no repetirlos.
- **Líneas 10-19**: `useReadContracts` recibe una lista de lecturas. `allowFailure: false` hace que o salgan todas bien o la consulta entera falle, y que `data` sea una tupla tipada (`[bigint, bigint, bigint, boolean]`).
- **Línea 21**: `data ?? []` evita desestructurar `undefined` mientras se carga.
- **Línea 23**: `...query` devuelve también `isPending`, `error`, etc.

Qué aporta separarlo del componente (regla del `CLAUDE.md`: hooks de contrato separados de la UI):
- `ProtocolStats` no sabe qué es un ABI ni un RPC: solo recibe valores y estados.
- La lógica de lectura se reutiliza o se cambia en un solo sitio.

### TanStack Query: caché de datos del servidor

La interfaz tiene dos clases de estado. **Estado de interfaz**: qué pestaña está abierta. **Estado del servidor** (aquí, la cadena): datos que viven fuera, pueden quedar viejos y se piden con latencia y fallos. TanStack Query es una caché para el segundo.

Cada consulta tiene una **clave** (`queryKey`) que la identifica (en nuestro caso empieza por `readContracts` y contiene las lecturas y `allowFailure`) y una **función** que pide el dato. La caché guarda el resultado por clave.

```
 ProtocolStats ─► useStakingConfig ─► useReadContracts ─► useQuery(clave, función)
                                                                │
                                              ┌─── caché ◄──────┤  ¿está y es reciente?  → se devuelve, sin red
                                              │                 ▼
                                              └─ no / caducado ─► viem ─► JSON-RPC ─► nodo
```

### Experimento: cuántas peticiones llegan al nodo

Con el mismo `readContractsQueryOptions` que usa tu hook, contando las peticiones HTTP reales a Anvil:

| Caso | Peticiones al nodo |
|---|---|
| 1. una lectura (base: 4 `eth_call`) | 4 |
| 2. **dos lecturas iguales a la vez** | **4** (se agrupan en una) |
| 3. otra vez con el dato aún fresco (`staleTime` 60 s) | **0** (sale de la caché) |
| 4. otra vez con el dato caducado (`staleTime` 0, el defecto) | 4 (se vuelve a pedir) |

Consecuencias:
- **Deduplicación**: tres componentes que usen `useStakingConfig` provocan **una** consulta, no tres.
- **`staleTime`**: cuánto tiempo se considera fresco un dato. Por defecto es 0: se muestra lo cacheado y se refresca en segundo plano (*stale-while-revalidate*). Para `stakingPeriod`, que es inmutable, podría ser muy largo; para `claimableRewards`, corto.
- Las 4 peticiones son porque Anvil no tiene multicall3 configurado; en una red con multicall3 wagmi las agruparía en una sola (no probado aquí).

### Los estados de una consulta

| Campo | Significa |
|---|---|
| `isPending` | todavía **no hay dato** (primera carga) |
| `isFetching` | hay una petición **en curso**, también si ya había dato (refresco en segundo plano) |
| `error` / `isError` | la última petición falló |
| `data` | el último dato bueno, aunque se esté refrescando |

Por eso `ProtocolStats` usa `isPending`: solo muestra "Loading…" la primera vez; después enseña el dato viejo mientras refresca.

### Analogía Java

Spring Cache con `@Cacheable` y TTL (`staleTime`) + coalescencia de peticiones iguales + reintentos con *backoff* (como resilience4j) + devolver el valor viejo mientras se refresca. Todo en el cliente.

### Preguntas de control

1. ¿Por qué React exige que los hooks se llamen siempre en el mismo orden?
2. Si tres componentes llaman a `useStakingConfig`, ¿cuántas veces se pide el dato al nodo y por qué?
3. ¿Qué diferencia hay entre `isPending` e `isFetching`, y cuál usa `ProtocolStats`?

### Frase de entrevista

"Los hooks dan a una función de componente memoria y ciclo de vida entre renders, y React los distingue por el orden de llamada, de ahí sus reglas. Para leer la cadena uso un hook propio sobre `useReadContracts`, que es TanStack Query: una caché por clave que deduplica peticiones iguales y sirve datos frescos sin tocar el nodo. Lo medí: dos lecturas simultáneas generan las mismas peticiones que una, y con `staleTime` cero peticiones."

---

## Módulo 4: la pila web3

### Las capas, de abajo arriba

```
 TU CÓDIGO     ProtocolStats, useStakingConfig
     │
 wagmi         hooks de React (useAccount, useReadContracts…)  +  TanStack Query (la caché)
     │ usa
 @wagmi/core   config, conectores, acciones: readContract(config, …)      (sin React)
     │ usa
 viem          clientes, codificación ABI, JSON-RPC, tipos                 (habla con el nodo)
     │
 nodo RPC (Anvil, Sepolia…)            wallet (MetaMask) por el estándar EIP-1193
```

### viem frente a wagmi

| | viem | wagmi |
|---|---|---|
| Qué es | cliente tipado para hablar con la cadena | estado de la wallet + hooks de React + caché, encima de viem |
| Sabe | codificar llamadas con el ABI, enviar JSON-RPC, decodificar resultados, tipos | quién está conectado, en qué red, cambiar de red, reconectar al recargar |
| No sabe | nada de React, ni de wallets conectadas, ni de caché | — (usa viem para todo lo que toca la cadena) |
| Analogía Java | cliente HTTP/RPC tipado (tipo Feign) | gestor de sesión de wallet + caché + enlaces con la UI |

La misma lectura por tres caminos devolvió `90n`:

| Camino | Código |
|---|---|
| viem | `createPublicClient({ chain, transport }).readContract(call)` |
| wagmi core | `readContract(config, call)` |
| cliente de wagmi | `getPublicClient(config).readContract(call)` |

El cliente que guarda wagmi en su `config` **es de viem**. Un matiz que comprobé al fallar: `config.getClient()` devuelve un cliente **base** (tiene `request` pero no `readContract`); el completo se pide con `getPublicClient(config)`.

### `src/wagmi.ts`

- **Líneas 8-13**: `createConfig` recibe tres cosas.
  - `chains: [foundry]`: las redes que soporta la app.
  - `connectors: [injected()]`: cómo conectar una wallet. `injected()` usa la wallet que el navegador expone en `window.ethereum` (MetaMask, Rabby…).
  - `transports: { [foundry.id]: http() }`: cómo **leer** de cada red. `http()` sin URL usa la del preset de la cadena (`127.0.0.1:8545`). Para Sepolia se pondría la URL de un proveedor.
- **Líneas 16-20**: `declare module "wagmi"` amplía los tipos de wagmi con tu configuración, para que los hooks conozcan tus cadenas (un chain id inválido no compila).

### Dos caminos: lecturas y escrituras

```
 LECTURAS     tu app ──transport (http)──────────────────────────► nodo RPC
 ESCRITURAS   tu app ──connector──► wallet (MetaMask) ──firma──► nodo RPC
                                     ↑ el usuario aprueba aquí
```

Las **lecturas** van directas al nodo por el `transport` de `wagmi.ts`. Las **escrituras** pasan por la wallet, que tiene las claves: **tu app nunca ve ninguna clave privada**.

### `src/contracts.ts`

```ts
export const localAddresses = { stakingToken: "0x5FbD…", stakingApp: "0x9fE4…", … } as const satisfies Record<string, Address>;
```

| Pieza | Qué hace |
|---|---|
| `Address` | tipo `` `0x${string}` ``: cualquier texto que empiece por `0x`. El checksum **no** se comprueba al compilar, sino al ejecutar (es el error que dio viem) |
| `as const` | el objeto es de solo lectura y cada valor conserva su texto exacto, no un `string` genérico |
| `satisfies Record<string, Address>` | comprueba que cada valor sea una `Address` **sin ensanchar el tipo**: `localAddresses.stakingAppp` (con un typo) no compila. Con una anotación `: Record<string, Address>` sí compilaría |

Las direcciones cambian por red; el ABI no. Por eso viven separadas: cuando haya Sepolia, será un mapa por chain id.

### El ABI

Un ABI es un JSON con una entrada por cada función, evento y error del contrato. En `StakingApp`: 21 funciones, 9 eventos, 14 errores, un constructor y `receive`.

```json
{ "type": "function", "name": "claimableRewards",
  "inputs":  [ { "name": "tokenId_", "type": "uint256" } ],
  "outputs": [ { "name": "", "type": "uint256" } ],
  "stateMutability": "view" }

{ "type": "event", "name": "RewardsClaimed",
  "inputs": [ { "name": "user_", "type": "address", "indexed": true },
              { "name": "amount_", "type": "uint256", "indexed": false } ] }

{ "type": "error", "name": "NotPositionOwner",
  "inputs": [ { "name": "tokenId", "type": "uint256" }, { "name": "caller", "type": "address" } ] }
```

- `stateMutability: "view"` distingue lecturas de escrituras (`readContract` solo acepta `view`/`pure`).
- `indexed: true` marca los campos por los que se puede **filtrar** en los logs (es lo que usa `getLogs` para las posiciones de una wallet).
- Los `errors` son los que viem usa para nombrar un revert (módulo anterior: hay que fusionar el ABI del NFT).

**Cómo llega al frontend**: `forge build` deja el ABI en `out/StakingApp.sol/StakingApp.json`; `scripts/sync-abis.mjs` lo copia a `src/abi/stakingApp.ts` como `export const stakingAppAbi = [...] as const`.

**Por qué `as const` y no importar el JSON**: un JSON importado se ensancha a tipos genéricos (`string`) y viem no puede inferir nada. Con `as const` conserva los textos literales y viem deduce los tipos.

### Experimento: de dónde salen los tipos

Provocando errores a propósito para que TypeScript revele el tipo inferido:

| Pregunta | Tipo inferido |
|---|---|
| Retorno de `claimableRewards` | `bigint` |
| Argumentos de `claimableRewards` | `readonly [tokenId_: bigint]` (el nombre sale del ABI) |
| Retorno de `paused` | `boolean` |
| Retorno con un `Abi` genérico (sin `as const`) | `unknown` |

### Lo que se necesita para hablar con cualquier cadena

| | Anvil | Sepolia | Mainnet |
|---|---|---|---|
| ABI | el mismo | el mismo | el mismo |
| Dirección | determinista | la del despliegue | la del despliegue |
| RPC y chain id | `127.0.0.1:8545`, 31337 | un proveedor, 11155111 | un proveedor, 1 |
| Dónde vive | `src/abi/` · `contracts.ts` · `wagmi.ts` | igual | igual |

### Un clic de lectura, de punta a punta

```
 ProtocolStats ─► useStakingConfig ─► useReadContracts (wagmi) ─► TanStack Query (clave → caché)
                                              │ lee la dirección de contracts.ts y el ABI de src/abi
                                              ▼
                              config (wagmi.ts) ─► cliente viem ─► codifica con el ABI ─► eth_call
                                              ▼
                                         http://127.0.0.1:8545  (Anvil)
```

### Preguntas de control

1. ¿Qué sabe hacer wagmi que viem no, y qué usa wagmi de viem por debajo?
2. ¿Por qué las lecturas van directas al nodo pero las escrituras pasan por la wallet, y qué consecuencia tiene para la seguridad?
3. ¿Por qué el ABI se guarda con `as const` y no como un JSON importado?

### Frase de entrevista

"viem es el cliente tipado que habla con la cadena y codifica con el ABI; wagmi añade el estado de la wallet y los hooks de React sobre viem y TanStack Query. Las lecturas van por el transport directo al nodo y las escrituras por la wallet, así la app nunca maneja claves. El ABI lo extraigo de `forge build` como `as const` para que TypeScript infiera los tipos de cada función."

---

## Módulo 7: las posiciones de una wallet

### El problema y cómo se resuelve

`StakingNFT` no es `ERC721Enumerable`, así que no existe "dame los tokens de esta wallet". Se **reconstruye desde los eventos**:

```
 1. getContractEvents: Transfer(to = mi wallet)   → todos los tokens que alguna vez recibí
 2. ownerOf(tokenId) de cada uno                  → ¿sigue siendo mío? (puedo haberlo vendido o quemado)
 3. leer el detalle de los que quedan             → importe, fecha, claimableRewards
```

El paso 2 es imprescindible: un log prueba que **recibiste** el token, no que lo **tengas**. Un token quemado hace revertir a `ownerOf`, así que esas lecturas se permiten fallar (`allowFailure: true`) y se descartan.

### Estructura del código

| Archivo | Rol |
|---|---|
| `src/lib/positions.ts` | **funciones puras** (`getReceivedTokenIds`, `readPositions`): sin React, se pueden probar en Node |
| `src/hooks/useMyPositions.ts` | hook fino: conecta esas funciones con la config de wagmi y la caché de TanStack Query |
| `src/components/PositionsList.tsx` | solo pinta: cargando, error, vacío o lista |

Separar la lógica en funciones normales permite comprobarla contra Anvil sin navegador, y deja al hook en 10 líneas.

### Detalles de diseño del hook

- **Clave de caché** `["myPositions", chainId, address]`: cambiar de wallet o de red es otra entrada, así que **nunca** se ven posiciones de la cuenta anterior.
- **`enabled: address !== undefined`**: sin wallet no se lanza la consulta. Ojo: una consulta desactivada también tiene `isPending`, por eso el componente comprueba **primero** `isConnected`.
- **`key` en la lista**: React necesita una clave estable por elemento para distinguirlos entre renders; aquí el `tokenId`.
- Se usa `readContracts` de wagmi y no el `multicall` de viem: Anvil no tiene multicall3, y wagmi cae a lecturas individuales.

### Resultado contra Anvil

| Wallet | Tokens recibidos | Posiciones vivas |
|---|---|---|
| #1: recibió el 1 (y lo transfirió) y el 2 | #1, #2 | **#2** |
| #2: recibió el 1 y el 3, ambos quemados | #1, #3 | ninguna |
| #5: nunca recibió nada | ninguno | ninguna |

### Un hallazgo real

La posición #2 muestra **11.25 ETH reclamables** con **1.98 ETH** en el contrato. Han pasado 28 horas reales, el reloj de Anvil sigue corriendo y hay 1125 periodos de 90 s completos. Un `Claim` ahora fallaría con `EthTransferFailed`: es el caso que motiva el aviso previo del `PLAN.md`.

### Preguntas de control

1. ¿Por qué no basta con los logs `Transfer` para saber qué posiciones tiene una wallet?
2. ¿Por qué la dirección y la cadena forman parte de la clave de caché?
3. ¿Qué ventaja tiene poner la lógica en funciones puras y no dentro del hook?

### Frase de entrevista

"Como el NFT no es enumerable, reconstruyo las posiciones desde los eventos `Transfer` recibidos y las verifico con `ownerOf`, porque un log solo prueba que se recibió el token. La lógica son funciones puras que probé contra Anvil; el hook solo las une a la caché, con wallet y cadena en la clave."

---

## Módulo 8: las acciones (depositar, reclamar y retirar)

### Una escritura no es una lectura con otro nombre

Tarda, la aprueba una persona y puede fallar de varias formas. Por eso cada acción tiene un **estado explícito**:

```
 idle ──clic──► pending ──la wallet firma──► confirming ──minada──► success
                  │ (simulación o firma fallan)       │ (revierte en cadena)
                  └──────────────► error ◄────────────┘
```

| Fase | Qué ocurre | Mensaje |
|---|---|---|
| `pending` | simulamos y esperamos la firma | "confirm in your wallet…" |
| `confirming` | enviada, falta que se mine | "Waiting for confirmation…" y el hash |
| `success` / `error` | resultado | "Done." o el error en lenguaje humano |

### Las capas

| Pieza | Responsabilidad |
|---|---|
| `lib/errors.ts` | `describeError`: un error de viem → una frase |
| `lib/transactions.ts` | `deposit`, `claimRewards`, `withdrawTokens`: **simular → firmar → esperar el recibo** |
| `hooks/useTransaction.ts` | la máquina de estados y el refresco de la caché |
| `hooks/useStakingActions.ts` | un hook por acción (`useDeposit`, `useClaim`, `useWithdraw`) |
| componentes | `DepositPanel`, `PositionActions`, `TransactionStatus` |

### Simular antes de firmar

`simulateContract` ejecuta la llamada como una lectura. Si va a revertir, falla **antes** de que la wallet pida la firma: el usuario no paga gas por algo condenado. En las pruebas, un claim prematuro devolvió "Too early to claim: 88 more seconds" sin enviar nada.

### El depósito son dos transacciones

El token debe permitir antes que `StakingApp` mueva el STK (`approve`), y después se llama a `depositToken`. El `approve` es por el **importe exacto**, nunca ilimitado: si `StakingApp` tuviera un fallo, no podría vaciar la wallet. Si ya había permiso suficiente, se salta el primer paso. La acción avisa de cada paso con `progress.step(...)` y el estado vuelve a `pending` para la segunda firma.

### Traducir errores

Un revert llega envuelto en varias capas de errores de viem. `describeError` las recorre con `walk`, busca el `ContractFunctionRevertedError` y lo decodifica contra los ABIs de **los tres contratos** (un error del NFT o del token ocurre dentro de una llamada a `StakingApp`). También reconoce `UserRejectedRequestError`: el usuario cancela en la wallet.

| Error del contrato | Mensaje |
|---|---|
| `StakingPeriodNotElapsed(remaining)` | Too early to claim: N more seconds… |
| `NotPositionOwner` | You do not own this position. |
| `EthTransferFailed` | The contract does not hold enough ETH… |
| `EnforcedPause` | The protocol is paused… withdrawals still work. |
| `ERC721NonexistentToken` | This position no longer exists. |

### El primer `useState` real del proyecto

`useTransaction` guarda `phase`, `step`, `hash` y `error` con `useState` (módulo 2). Cada `setX` provoca un nuevo render, y el componente pinta lo que dice la fase. Al terminar, invalida las consultas `["myPositions"]` y `["balance"]` (módulo 3): la caché sabe que lo leído antes ya está viejo y vuelve a pedirlo.

### Dos cuidados de la interfaz

- **Aviso de balance insuficiente**: un claim paga el importe completo o revierte. Si `claimable > balance del contrato`, `PositionActions` avisa y desactiva `Claim`. Es el caso real medido (11.25 ETH devengados frente a 1.98 ETH).
- **Todos los hooks antes del `return` temprano** de `DepositPanel`: las reglas de los hooks (módulo 3).

### Qué se probó

Con transacciones reales contra Anvil y una wallet simulada: claim sin ETH suficiente, depósito en dos pasos, claim prematuro, claim desde otra cuenta, retiro y rechazo en la wallet. Cada caso devolvió su mensaje. Lo que **no** se ha podido probar es el flujo en un navegador con una wallet real.

### Preguntas de control

1. ¿Por qué se simula antes de pedir la firma y qué le ahorra al usuario?
2. ¿Por qué el `approve` es por el importe exacto y no ilimitado?
3. ¿Por qué `describeError` decodifica contra los tres ABIs y no solo el de `StakingApp`?

### Frase de entrevista

"Cada acción pasa por simular, firmar y esperar el recibo, con un estado explícito (idle, pending, confirming, success, error). Simulo antes para que un revert conocido no cueste gas, aprobo el importe exacto y traduzco los custom errors decodificándolos contra los tres contratos. Lo probé con transacciones reales contra Anvil."
