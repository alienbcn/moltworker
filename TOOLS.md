# Tools & Context Management para Jasper

## Visión General

Esta documentación define cómo Jasper gestiona tokens de contexto, herramientas disponibles, y límites para asegurar operación eficiente en producción sin agotar recursos de Claude Opus 4.5.

---

## Presupuesto Global de Tokens

```
┌─────────────────────────────────────────────────────┐
│ CONTEXTO TOTAL DISPONIBLE: 131,072 tokens          │
└─────────────────────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
    
┌──────────────────┐ ┌──────────────────┐ ┌──────────────┐
│  SISTEMA         │ │  USUARIO         │ │  HERRAMIENTAS│
│  ~1,000 toks     │ │  ~50,000 toks    │ │  ~10,000 toks│
│  (1%)            │ │  (38%)           │ │  (7.6%)      │
│                  │ │                  │ │              │
│ - Prompt sist    │ │ - Contexto hist  │ │ - Búsqueda   │
│ - Instrucciones  │ │ - Conversación   │ │ - Memoria    │
│ - Identidad      │ │ - Documentos     │ │ - Ejecución  │
│ - Configuración  │ │ - Datos usuario  │ │ - Análisis   │
└──────────────────┘ └──────────────────┘ └──────────────┘
          
┌──────────────────┐ ┌──────────────────┐
│  RESPUESTA       │ │  RESERVA/SAFETY  │
│  ~8,192 toks     │ │  ~61,880 toks    │
│  (6.2%)          │ │  (47.2%)         │
│                  │ │                  │
│ - Output modelo  │ │ - Buffer errores │
└──────────────────┘ └──────────────────┘
```

---

## Herramientas Disponibles y Sus Límites

### 1. Web Search (Brave Search API + Playwright Browser)

**Descripción**: Búsqueda inteligente en internet con estrategia de respaldo  
**Proveedores**: Brave Search API (primario) + Playwright Browser (respaldo)  
**Costo**: 1 crédito Brave por búsqueda, o compute del contenedor para Playwright

#### Estrategia de Búsqueda

```
Usuario solicita búsqueda web
           │
           ▼
    ┌─────────────────┐
    │ ¿BRAVE_API_KEY? │
    └─────────────────┘
           │
      ┌────┴────┐
      │         │
     SÍ        NO
      │         │
      ▼         ▼
┌──────────┐  ┌─────────────┐
│ Brave API│  │ Playwright  │
│ (rápido) │  │ (completo)  │
└──────────┘  └─────────────┘
      │              │
      ▼              │
   ¿Éxito?           │
      │              │
   ┌──┴──┐           │
   │     │           │
  SÍ    NO           │
   │     │           │
   │     └───────────┘
   │         │
   ▼         ▼
 Resultado  Playwright
             (fallback)
```

#### Límites de Uso

| Parámetro | Brave API | Playwright Browser |
|-----------|-----------|-------------------|
| Máx búsquedas/llamada | 3 | 1-2 (más lento) |
| Máx búsquedas/minuto | 30 | 5-10 (límite memoria) |
| Timeout por búsqueda | 10s | 30s |
| Tokens reservados | 500-1,000 | 1,000-2,000 |
| Casos de uso | Texto, noticias | JavaScript, SPAs, visual |
| Costo mensual est. | $1-5 (10k búsq.) | Incluido en compute |

#### Cuándo Usar ✅

```
✅ Usuario pregunta sobre evento actual (últimas 24h)
✅ Necesita datos que cambian frecuentemente
✅ Requiere URLs o fuentes confiables
✅ Pregunta sobre noticias, precios, clima
✅ Usuario solicita expresamente búsqueda
✅ Sitios JavaScript/SPAs que no funcionan con API (usar Playwright)
✅ Necesita screenshot o contenido visual (usar Playwright)
✅ Formularios o interacciones web (usar Playwright)

Ejemplos:
"¿Qué pasó el día de hoy en tech?"
→ Brave API → Resumir → Proporcionar URLs

"Dame el precio actual de ETH en Coinbase"
→ Brave API primero → Si falla → Playwright navega y extrae
```

#### Cuándo NO Usar ❌

```
❌ Preguntas sobre hechos históricos bien conocidos
❌ Usuario pregunta algo típicamente conocido de ML
❌ Tiempo de respuesta crítico (<3 segundos, usar solo Brave)
❌ Ya tengo información reciente en contexto
❌ Usuario dice "no necesito búsqueda"

Ejemplo:
"¿Cuál es la capital de Francia?"
→ Responder directamente (París), no buscar
```

#### Playwright vs Brave API - Guía de Decisión

| Caso | Método | Razón |
|------|--------|-------|
| Búsqueda de noticias | Brave API | Rápido, confiable para texto |
| Precio de acciones | Brave API primero | Usualmente disponible en meta tags |
| Aplicación React/Vue | Playwright | Requiere renderizado JavaScript |
| Llenar formularios | Playwright | Necesita automatización completa |
| Captura visual | Playwright | Puede tomar screenshots |
| Rate limit concern | Brave API | Límites más generosos |
| Múltiples páginas | Brave API | Más eficiente para batch |

#### Control de Exceso

```javascript
// Implementación pseudo-código para búsqueda inteligente
const SEARCH_LIMITS = {
  perCall: 3,           // Máx 3 búsquedas
  perMinute: 30,        // Throttle global
  perHour: 500,
  timeoutMs: 30000,     // Total timeout
};

async function executeSearch(query: string): Promise<boolean> {
  // 1. Intentar con Brave API primero (si disponible)
  if (process.env.BRAVE_SEARCH_API_KEY) {
    try {
      return await braveSearch(query, { timeout: 10000 });
    } catch (error) {
      console.warn('Brave API failed, falling back to Playwright');
    }
  }
  
  // 2. Fallback a Playwright si Brave falla o no está disponible
  return await playwrightSearch(query, { timeout: 30000 });
}
```

---

### 2. Memory Search / Embeddings

**Descripción**: Búsqueda semántica en memoria persistente  
**Proveedores**: Google Gemini Embeddings o OpenAI  
**Propósito**: Recordar contexto anterior sin consumir tokens de contexto

#### Límites de Uso

| Parámetro | Valor | Notas |
|-----------|-------|-------|
| Máx búsquedas | 5-10 | Por consulta |
| Máx documentos | 100 | De memoria |
| Chunk size | 1,024 toks | Por documento |
| Búsquedas/min | 60 | Límite API |
| Tokens reservados | 5,000-10,000 | Embeddings + chunks |
| Latencia | 2-5s | Generalmente |

#### Cuándo Usar ✅

```
✅ Conversación que continúa de sesiones anteriores
✅ Usuario referencia "el proyecto del mes pasado"
✅ Necesito contexto histórico sin agotarTokens
✅ Búsqueda de patrones en datos pasados
✅ Recuperar identidad/preferencias del usuario

Ejemplo:
"¿Recuerdas el documento que me pasaste la semana pasada?"
→ Buscar en embeddings → Recuperar contexto → Continuar
```

#### Cuándo NO Usar ❌

```
❌ Información que ya está en contexto actual
❌ Los primeros mensajes de nueva sesión
❌ Datos que cambian constantemente
❌ Consultas que solo necesitan web search
❌ Cuando total de tokens ya es alto (>90%)

Ejemplo:
"¿Qué acabas de decirme?" → Está en contexto, no buscar
```

#### Detalles de Almacenamiento

```
Memoria en R2 (persistente):
├── /workspace/memory/
│   ├── conversations/          # Transcripciones
│   │   └── 2026-02-*.jsonl
│   ├── documents/              # Archivos del usuario
│   │   ├── projects/
│   │   ├── references/
│   │   └── uploads/
│   ├── embeddings.db           # Vector DB
│   └── metadata.json
│
├── /workspace/IDENTITY.md      # Identidad usuario
├── /workspace/SOUL.md          # Mi personalidad
└── /workspace/context.json     # Preferencias

Sincronización automática:
- Cada 5 minutos → R2
- On-demand → Memory DB
- Recuperación en startup
```

---

### 3. Code Execution

**Descripción**: Ejecutar Python, Bash, JavaScript en sandbox  
**Timeout**: 30 segundos máximo  
**Memoria**: 512 MB máximo  
**Output**: 10,000 caracteres máximo

#### Límites de Uso

| Parámetro | Valor | Notas |
|-----------|-------|-------|
| Máx ejecuciones/llamada | 2 | Evitar loops |
| Máx tamaño archivo | 5 MB | Para análisis |
| Máx duración | 30s | Hard timeout |
| Máx memoria | 512 MB | RAM asignada |
| Máx output | 10,000 chars | Truncar si excede |
| Lenguajes soportados | Python, Bash, Node | Otros: error |

#### Cuándo Usar ✅

```
✅ Análisis de datos pequeños (CSV, JSON)
✅ Matemáticas complejas o simulaciones
✅ Transformación de formatos
✅ Debuggeo rápido de código
✅ Validación de sintaxis

Ejemplo:
"¿Cuál es la raíz cuadrada de 12345?"
→ Ejecutar código → Retornar resultado exacto
```

#### Cuándo NO Usar ❌

```
❌ Entrenar modelos de ML (demasiado tiempo)
❌ Descargas de internet (tráfico externo)
❌ Archivos >5MB
❌ Llamadas a APIs externas con latencia alta
❌ Operaciones que requieren persistencia

Ejemplo:
"Descarga este dataset de 500MB"
→ Rechazar, explicar límite, sugerir alternativa
```

#### Implementación de Límites

```javascript
// Pseudo-código para ejecución controlada
const CODE_LIMITS = {
  timeout: 30000,        // 30 segundos
  memory: 512 * 1024,    // 512 MB
  maxOutput: 10000,      // caracteres
  maxFileSize: 5 * 1024 * 1024,  // 5 MB
};

async function executeCode(code: string, lang: string): Promise<string> {
  // 1. Validar lenguaje
  if (!['python', 'bash', 'javascript'].includes(lang)) {
    throw new Error(`Lenguaje no soportado: ${lang}`);
  }

  // 2. Validar tamaño
  if (code.length > CODE_LIMITS.maxFileSize) {
    throw new Error('Código muy largo');
  }

  // 3. Ejecutar con límites
  const result = await executeWithTimeout(
    sandbox.exec(lang, code, { memory: CODE_LIMITS.memory }),
    CODE_LIMITS.timeout
  );

  // 4. Truncar output
  if (result.length > CODE_LIMITS.maxOutput) {
    return result.slice(0, CODE_LIMITS.maxOutput) + '\n... [truncado]';
  }

  return result;
}
```

---

### 4. File Analysis

**Descripción**: Analizar archivos cargados (texto, código, datos)  
**Formatos soportados**: .txt, .py, .js, .json, .csv, .md, .pdf  
**Límite de tamaño**: 5 MB máximo, 100 páginas PDF

#### Límites de Uso

| Parámetro | Valor | Notas |
|-----------|-------|-------|
| Máx análisis/llamada | 3 archivos | Por solicitud |
| Máx tamaño archive | 5 MB | Total |
| Máx páginas PDF | 100 | Ocurriendo |
| Tokens reservados | 2,000-5,000 | Contenido análisis |
| Tiempo análisis | 5-15s | Depende tamaño |

---

## Sistema de Alertas y Throttling

### Alertas Automáticas

```
NIVEL 1 (50% tokens consumidos)
┌─────────────────────────────────────┐
│ ⚠️  ADVERTENCIA: 50% contexto usado │
├─────────────────────────────────────┤
│ Tokens usados: ~65,536 / 131,072    │
│ Herramientas disponibles: Limitadas │
│ Acción: Resumir contexto pronto     │
└─────────────────────────────────────┘

NIVEL 2 (75% tokens consumidos)
┌─────────────────────────────────────┐
│ 🔴 CRÍTICO: 75% contexto usado      │
├─────────────────────────────────────┤
│ Tokens usados: ~98,304 / 131,072    │
│ Herramientas: Solo búsqueda web     │
│ Acción: Cambiar sesión inmediatamente│
└─────────────────────────────────────┘

NIVEL 3 (90% tokens consumidos)
┌─────────────────────────────────────┐
│ 💥 EMERGENCIA: 90% contexto usado   │
├─────────────────────────────────────┤
│ Tokens usados: ~117,648 / 131,072   │
│ Herramientas: DESHABILITADAS        │
│ Acción: Fallar, iniciar nueva sesión│
└─────────────────────────────────────┘
```

### Implementación

```javascript
// Monitoreo de tokens
class TokenManager {
  private THRESHOLDS = {
    warning: 0.5,   // 50%
    critical: 0.75, // 75%
    emergency: 0.9, // 90%
  };

  checkAndAlert(tokensUsed: number, totalAvailable: number): void {
    const percentage = tokensUsed / totalAvailable;

    if (percentage >= this.THRESHOLDS.emergency) {
      throw new Error('EMERGENCY: Emergency - Iniciar nueva sesión');
    }

    if (percentage >= this.THRESHOLDS.critical) {
      console.warn('CRITICAL: Tokens críticos. Resumir y cambiar sesión');
      this.disableTools(['code_execution', 'embeddings']);
    }

    if (percentage >= this.THRESHOLDS.warning) {
      console.warn('WARNING: 50% de tokens consumidos');
      this.limitToolUse(['embeddings', 'file_analysis']);
    }
  }

  disableTools(toolList: string[]): void {
    // Implementación...
  }
}
```

---

## Gestión de Sesiones

### Flujo de Nueva Sesión

```
Usuario inicia conversación
         │
         ▼
┌──────────────────────────────────────┐
│ 1. Restaurar contexto personal       │ (embeddings)
│    - Preferencias del usuario        │
│    - Historial reciente (resumen)    │
│    - Documentos relevantes           │
└──────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ 2. Cargar identidad (IDENTITY.md)    │
│    - Mi presentación                 │
│    - Capacidades disponibles         │
│    - Límites operacionales           │
└──────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ 3. Saludar y set expectativas        │
│    - Estoy listo para ayudar         │
│    - Aquí están mis capacidades      │
│    - Pregunta: ¿Qué necesitas?       │
└──────────────────────────────────────┘
         │
         ▼
   Listo para interacción
   (Tokens usados: ~20,000 / 131,072 = 15%)
```

### Cierre de Sesión (cuando >80% contexto)

```
Detector: "Tokens disponibles <25,000"
         │
         ▼
┌──────────────────────────────────────┐
│ 1. Resumir conversación              │
│    - Temas cubiertos                 │
│    - Insights clave                  │
│    - Documentos generados            │
└──────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ 2. Guardar a memoria (embeddings)    │
│    - Nuevos documentos               │
│    - Contexto importante             │
│    - Preferencias descubiertas       │
└──────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ 3. Sincronizar a R2                  │
│    - Metadata, docs, embeddings      │
│    - Timestamp de cierre             │
└──────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ 4. Invitar a nueva sesión            │
│    "Contexto a capacidad máxima.     │
│     Inicia una nueva sesión:         │
│     [Link o instrucción]"            │
└──────────────────────────────────────┘
```

---

## Mejores Prácticas

### Para Users

```markdown
### ✅ DO: Optimizar tu contexto

1. **Sé específico en preguntas**
   - Mal: "Dame información sobre Python"
   - Bien: "¿Cómo puedo parsear JSON en Python 3.10?"

2. **Usa búsqueda web cuando es reciente**
   - "Busca las noticias de hoy sobre..."
   - "¿Qué cambió en Kubernetes últimamente?"

3. **Declara archivos grandes de una vez**
   - "Voy a compartir un documento. Es 2MB..."
   - No: Dividir en 5 partes diferentes

4. **Cita contexto anterior**
   - "Como dijimos hace poco, [X]..."
   - Para que use memoria en lugar de re-explicar

### ❌ DON'T: Desperdiciar tokens

1. **No repitas lo que ya dije**
   - Yo remembrar. Directo al punto.

2. **No hagas muchas búsquedas si no es necesario**
   - "Busca sobre X, Y, Z, A, B..."
   - Máx 3 por request.

3. **No cargues archivos innecesariamente**
   - Solo paso lo que es relevante
   - No "por si acaso"
```

### Para o Implementadores

```typescript
// Patrón de uso responsable de herramientas
async function handleUserQuery(query: string, context: Context): Promise<string> {
  // 1. Estimar tokens antes de actuar
  const estimatedTokens = estimateTokens(query, context);
  if (estimatedTokens > MAX_TOKENS) {
    return suggestNewSession();
  }

  // 2. Elegir herramientas mínimas necesarias
  const requiredTools = analyzeQuery(query);
  // Si needsWebSearch && needsCodeExec && needsFileAnalysis:
  //   - Priorizar: Web > Code > FileAnalysis
  //   - Hacer máximo 2 tools

  // 3. Ejecutar con límites
  const result = await executeTools(requiredTools, {
    maxDuration: estimateToolTime(requiredTools),
    maxCalls: getRemainingSessions(),
  });

  // 4. Responder y alertar si es necesario
  return formatResponse(result, context);
}
```

---

## Tabla de Referencia Rápida

| Herramienta | Máx/Llamada | Máx/Hora | Tokens | Timeout |
|-------------|------------|----------|--------|---------|
| Web Search | 3 búsquedas | 500 | 500-1k | 30s |
| Embeddings | 10 docs | N/A | 5-10k | 5s |
| Code Exec | 2 ejecuciones | N/A | 1-3k | 30s |
| File Analysis | 3 archivos | N/A | 2-5k | 15s |
| **Total Seguro** | — | — | **15,000** | — |
| **Total Máximo** | — | — | **25,000** | — |
| **Context Capacity** | — | — | **131,072** | — |

---

## Monitoreo y Logging

```bash
# Monitorear consumo de tokens
curl https://moltbot.workers.dev/debug/health | jq '.tokens'

# Ver historial de tools usados
tail -f /root/heartbeat.log | grep "TOOL:"

# Auditar sesiones
grep "SESSION:" /root/openclaw-startup.log | tail -20

# Reportes de contexto
curl https://moltbot.workers.dev/debug/context-usage
```

---

## Cambios Futuros

**Q1 2026**: 
- Sistema de "context compression" para alargar sesiones
- Caché local de embeddings comunes
- Predicción de tools necesarios

**Q2 2026**:
- Modelo más grande con 200k tokens
- Memoria distribuida en Vector DB
- Tools dinámicos basados en user profile

---

**Última actualización**: 2026-02-08  
**Próxima revisión**: 2026-03-08  
**Responsable**: Equipo Jasper OpenClaw
