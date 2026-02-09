function executeOps(context, templates, ops) {
  for (const [op, args] of ops) {
    try {
      if (op === "__instances") {
        drawInstances(context, templates, args[0], args[1], args[2] || [], args[3] || null);
      } else if (op === "set") {
        context[args[0]] = args[1];
      } else if (typeof context[op] === "function") {
        context[op](...args);
      } else {
        console.warn("[Easel] Unknown operation:", op);
      }
    } catch (e) {
      console.error("[Easel] Error executing op:", op, args, e);
    }
  }
}

function drawInstances(context, templates, name, rows, palette = [], cols = null) {
  const tpl = templates[name];
  if (!tpl) { console.warn("[Easel] Unknown template:", name); return; }

  const layout = Array.isArray(cols) && cols.length > 0 ? cols : [0, 1, 2, 3, 4, 5, 6, 7];
  const pos = {};
  layout.forEach((col, i) => { pos[col] = i; });
  const get = (row, col) => {
    const i = pos[col];
    return i == null ? null : row[i];
  };

  for (const row of rows) {
    // Backward compatibility: older list-of-maps payload
    if (!Array.isArray(row)) {
      const inst = row || {};
      context.save();
      context.translate(inst.x || 0, inst.y || 0);
      if (inst.rotate) context.rotate(inst.rotate);
      if (inst.scale_x != null || inst.scale_y != null)
        context.scale(inst.scale_x ?? 1, inst.scale_y ?? 1);
      if (inst.fill) context.fillStyle = inst.fill;
      if (inst.stroke) context.strokeStyle = inst.stroke;
      if (inst.alpha != null) context.globalAlpha = inst.alpha;
      executeOps(context, templates, tpl);
      context.restore();
      continue;
    }

    context.save();
    const x = get(row, 0);
    const y = get(row, 1);
    const rotate = get(row, 2);
    const scaleX = get(row, 3);
    const scaleY = get(row, 4);
    const fillId = get(row, 5);
    const strokeId = get(row, 6);
    const alpha = get(row, 7);

    context.translate(x ?? 0, y ?? 0);
    if (rotate != null) context.rotate(rotate);
    if (scaleX != null || scaleY != null)
      context.scale(scaleX ?? 1, scaleY ?? 1);
    if (fillId != null && palette[fillId] != null) context.fillStyle = palette[fillId];
    if (strokeId != null && palette[strokeId] != null) context.strokeStyle = palette[strokeId];
    if (alpha != null) context.globalAlpha = alpha;
    executeOps(context, templates, tpl);
    context.restore();
  }
}

function canvasXY(el, e) {
  const rect = el.getBoundingClientRect();
  return {
    x: Math.round(e.clientX - rect.left),
    y: Math.round(e.clientY - rect.top),
  };
}

export const EaselHook = {
  drawFromData() {
    this.ensureDpr();
    const templates = JSON.parse(this.el.dataset.templates || "{}");
    Object.assign(this._templates, templates);
    const ops = JSON.parse(this.el.dataset.ops || "[]");
    if (ops.length > 0) {
      const ctx = this.context;
      const dpr = this._dpr || 1;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, this.el.width, this.el.height);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      executeOps(ctx, this._templates, ops);
    }
  },
  scheduleFrame() {
    if (this._rafId) return;
    this._rafId = requestAnimationFrame(() => {
      this._rafId = null;
      if (this._dirty) {
        this._dirty = false;
        this.drawFromData();
      }
    });
  },
  ensureDpr() {
    const dpr = window.devicePixelRatio || 1;
    this._dpr = dpr;
    const w = parseInt(this.el.getAttribute("width")) || this.el.width;
    const h = parseInt(this.el.getAttribute("height")) || this.el.height;
    if (this.el.width !== w * dpr || this.el.height !== h * dpr) {
      this.el.width = w * dpr;
      this.el.height = h * dpr;
      this.el.style.width = w + "px";
      this.el.style.height = h + "px";
    }
  },
  mounted() {
    this.ensureDpr();
    this.context = this.el.getContext("2d");
    this._templates = {};
    this._dirty = false;
    this._rafId = null;
    this.drawFromData();

    this.handleEvent(`easel:${this.el.id}:draw`, ({ ops, templates }) => {
      if (templates) Object.assign(this._templates, templates);
      executeOps(this.context, this._templates, ops);
    });

    this.handleEvent(`easel:${this.el.id}:clear`, () => {
      this.context.clearRect(0, 0, this.el.width, this.el.height);
    });

    const events = JSON.parse(this.el.dataset.events || "[]");
    const id = this.el.id;

    for (const eventType of events) {
      if (eventType === "keydown") {
        this.el.addEventListener("keydown", (e) => {
          this.pushEvent(`${id}:keydown`, {
            key: e.key,
            code: e.code,
            ctrl: e.ctrlKey,
            shift: e.shiftKey,
            alt: e.altKey,
            meta: e.metaKey,
          });
        });
      } else {
        this.el.addEventListener(eventType, (e) => {
          this.pushEvent(`${id}:${eventType}`, canvasXY(this.el, e));
        });
      }
    }
  },
  updated() {
    this._dirty = true;
    this.scheduleFrame();
  },
  destroyed() {
    if (this._rafId) cancelAnimationFrame(this._rafId);
  },
};
