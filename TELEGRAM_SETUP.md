# Configuración de Telegram Bot - Guía Completa

Este documento proporciona instrucciones detalladas para configurar y solucionar problemas con el bot de Telegram en OpenClaw.

## Obtener un Token de Telegram

### 1. Crear un Bot con BotFather

1. Abre Telegram y busca **@BotFather**
2. Inicia una conversación con him y envía: `/start`
3. Envía: `/newbot`
4. Proporciona un nombre para tu bot (ej: "Mi AI Assistant")
5. Proporciona un nombre de usuario único para tu bot (debe terminar con "bot", ej: "miai_assistant_bot")
6. **Copia el token que se te proporciona** (formato: `123456789:ABCDefGhIjKlMnOpqRsTuVwXyZ`)

### 2. Guardar el Token de Forma Segura

```bash
# Guardar el token en wrangler (desarrollo)
wrangler secret put TELEGRAM_BOT_TOKEN
# Pega el token cuando se te pida

# Verificar que se guardó
wrangler secret list
```

## Configurar el Bot

### Variables de Entorno Requeridas

```bash
TELEGRAM_BOT_TOKEN=123456789:ABCDefGhIjKlMnOpqRsTuVwXyZ   # Requerido
TELEGRAM_DM_POLICY=pairing                                   # Opcional: pairing (default) o open
TELEGRAM_DM_ALLOW_FROM=user1,user2                          # Opcional: lista de IDs de usuario permitidos
```

### Políticas de Mensajes Directos (DM Policy)

- **pairing** (default): Solo usuarios emparejados pueden enviar mensajes directos
- **open**: Cualquier usuario puede enviar mensajes directos
- Específico: Proporciona `TELEGRAM_DM_ALLOW_FROM` con IDs de usuario

## Solucionar Problemas

### El Bot No Arranca

1. **Verifica que el token sea válido:**
   ```bash
   wrangler secret list
   # Debe mostrar TELEGRAM_BOT_TOKEN
   ```

2. **Revisa los logs:**
   ```bash
   # Ver logs del worker
   npx wrangler tail
   
   # Ver logs del gateway
   curl https://tudominio.com/debug/logs
   ```

3. **Verifica la configuración:**
   ```bash
   curl https://tudominio.com/debug/config
   # Debe mostrar channels.telegram con tu token
   ```

### El Bot No Responde a Mensajes

1. **Verificar que el bot esté en línea:**
   ```bash
   curl https://tudominio.com/debug/health
   # Debe mostrar telegram.status = "configured" y telegram.enabled = true
   ```

2. **Comprobar que el gateway está corriendo:**
   ```bash
   curl https://tudominio.com/debug/processes
   # Debe haber un proceso "openclaw gateway" en estado "running"
   ```

3. **Comprobar conectividad de Telegram:**
   - Asegúrate de que tu servidor tiene acceso a internet
   - Telegram requiere conexión a: `https://api.telegram.org`
   - Verifica que los puertos no estén bloqueados

### Token Inválido

Si ves el error "Invalid Telegram bot token format":

- El token debe ser: `NUMEROS:LETRAS_Y_NUMEROS`
- Ejemplo válido: `123456:ABC-defGhIj_KlMnOpqRs`
- Revisa que lo copiaste correctamente de BotFather

### El Bot Se Queda Atascado

El sistema ahora incluye supervisor automático:

1. **Se reinicia automáticamente** si falla
2. **Health checks periódicos** cada 2 segundos
3. **Sincronización de memoria** cada 5 minutos a R2

Para forzar un reinicio manual:

```bash
# Ver procesos actuales
curl https://tudominio.com/debug/processes

# Matar proceso atascado (si necesario)
curl -X POST https://tudominio.com/debug/kill-process?id=<process-id>

# El sistema la relanzará automáticamente
```

## Persistencia de Memoria y Datos

El sistema asegura que la memoria del bot persista:

1. **Configuración**: Se almacena en `/root/.openclaw/openclaw.json`
2. **Memoria**: Se guarda en `/root/clawd/memory/`
3. **Respaldos**: Se sincronizan a R2 bucket automáticamente cada 5 minutos
4. **Restauración**: Al reiniciar, se restauran todos los datos desde R2

### Verificar que la Memoria se Está Guardando

```bash
# Ver archivos de memoria
curl "https://tudominio.com/debug/health" | jq '.health.memory'

# Respuesta esperada:
# {
#   "status": "has_data",
#   "files": 15,
#   "identity_file": "present"
# }
```

## Configuración del WebHook (Avanzado)

Por defecto, OpenClaw usa polling para Telegram. Si necesitas webhooks:

1. Contacta a BotFather: `/setcommands`
2. Para configurar webhook manualmente:
   ```bash
   curl -X POST https://api.telegram.org/bot<TOKEN>/setWebhook \
     -d "url=https://tudominio.com/telegram/webhook"
   ```

## Mejores Prácticas

1. **Guarda el token en secreto**
   - Nunca lo compartas
   - No lo pongas en repositorios públicos
   - Usa `wrangler secret put` para almacenarlo

2. **Mantén el bot actualizado**
   - El sistema se actualiza automáticamente
   - Revisa los logs regularmente

3. **Monitorea la salud**
   - Verifica `/debug/health` regularmente
   - Asegúrate de que `telegram.status = "configured"`

4. **Respaldos automáticos**
   - R2 se sincroniza cada 5 minutos
   - Puedes sincronizar manualmente con: `POST /api/admin/storage/sync`

## Contacto y Soporte

Si el problema persiste:

1. Revisa `/debug/logs` para ver mensajes de error específicos
2. Verifica que el token es válido con BotFather
3. Asegúrate de que el gateway está corriendo correctamente
4. Comprueba la conectividad a `api.telegram.org`
