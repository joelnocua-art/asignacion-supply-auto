/* ============================================================
   Terminal IA - Lógica principal
   ============================================================ */

// URL del webhook de n8n — cambia esto cuando tengas n8n corriendo
const WEBHOOK_URL = window.TERMINAL_CONFIG?.webhookUrl || 'http://localhost:5678/webhook/terminal-ia';

const output    = document.getElementById('output');
const input     = document.getElementById('command-input');
const sendBtn   = document.getElementById('send-btn');
const statusDot = document.getElementById('status-dot');
const statusTxt = document.getElementById('status-text');

// ============================================================
// Estado
// ============================================================
let isLoading = false;
const historial = [];
let historialIndex = -1;

// ============================================================
// Inicialización
// ============================================================
document.addEventListener('DOMContentLoaded', () => {
  input.focus();
  verificarConexion();

  input.addEventListener('keydown', onKeyDown);
  sendBtn.addEventListener('click', enviarComando);

  document.querySelectorAll('.quick-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      input.value = btn.dataset.cmd;
      enviarComando();
    });
  });
});

// ============================================================
// Verificar conexión con n8n
// ============================================================
async function verificarConexion() {
  setStatus('loading', 'conectando...');
  try {
    const r = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ comando: '__ping__', tipo: 'health_check' }),
      signal: AbortSignal.timeout(5000)
    });
    if (r.ok || r.status === 200) {
      setStatus('online', 'conectado');
    } else {
      setStatus('offline', 'n8n sin respuesta');
    }
  } catch {
    setStatus('offline', 'n8n no disponible');
    agregarMensaje('error', 'sistema', 'No se puede conectar con n8n. Verifica que esté corriendo en ' + WEBHOOK_URL);
  }
}

// ============================================================
// Enviar comando
// ============================================================
async function enviarComando() {
  const comando = input.value.trim();
  if (!comando || isLoading) return;

  historial.unshift(comando);
  historialIndex = -1;
  input.value = '';

  agregarMensaje('user', 'tú', comando);

  const indicador = mostrarTypingIndicator();
  setLoading(true);

  try {
    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ comando, timestamp: new Date().toISOString() }),
      signal: AbortSignal.timeout(30000)
    });

    indicador.remove();

    if (!response.ok) throw new Error(`HTTP ${response.status}`);

    const data = await response.json();
    const respuesta = data.respuesta || data.message || JSON.stringify(data, null, 2);

    agregarMensaje('ia', 'ia', respuesta);

  } catch (err) {
    indicador.remove();
    if (err.name === 'TimeoutError') {
      agregarMensaje('error', 'error', 'Tiempo de espera agotado. n8n tardó demasiado en responder.');
    } else if (err.message.includes('Failed to fetch')) {
      agregarMensaje('error', 'error', 'Sin conexión con n8n. ¿Está corriendo en ' + WEBHOOK_URL + '?');
      setStatus('offline', 'desconectado');
    } else {
      agregarMensaje('error', 'error', 'Error: ' + err.message);
    }
  } finally {
    setLoading(false);
    input.focus();
  }
}

// ============================================================
// UI helpers
// ============================================================
function agregarMensaje(tipo, prefijo, contenido) {
  const msg = document.createElement('div');
  msg.className = `message ${tipo}`;
  msg.innerHTML = `
    <span class="prefix">${escaparHTML(prefijo)}</span>
    <span class="content">${escaparHTML(contenido)}</span>
  `;
  output.appendChild(msg);
  output.scrollTop = output.scrollHeight;
}

function mostrarTypingIndicator() {
  const div = document.createElement('div');
  div.className = 'message ia';
  div.innerHTML = `
    <span class="prefix">ia</span>
    <div class="typing-indicator">
      <div class="typing-dot"></div>
      <div class="typing-dot"></div>
      <div class="typing-dot"></div>
    </div>
  `;
  output.appendChild(div);
  output.scrollTop = output.scrollHeight;
  return div;
}

function setLoading(state) {
  isLoading = state;
  sendBtn.disabled = state;
  input.disabled = state;
  if (state) setStatus('loading', 'procesando...');
  else        setStatus('online',  'conectado');
}

function setStatus(estado, texto) {
  statusDot.className = `status-dot ${estado}`;
  statusTxt.textContent = texto;
}

function escaparHTML(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/\n/g, '<br>');
}

// ============================================================
// Historial de comandos (flechas arriba/abajo)
// ============================================================
function onKeyDown(e) {
  if (e.key === 'Enter') {
    enviarComando();
    return;
  }
  if (e.key === 'ArrowUp') {
    e.preventDefault();
    if (historialIndex < historial.length - 1) {
      historialIndex++;
      input.value = historial[historialIndex];
    }
    return;
  }
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    if (historialIndex > 0) {
      historialIndex--;
      input.value = historial[historialIndex];
    } else {
      historialIndex = -1;
      input.value = '';
    }
  }
}
