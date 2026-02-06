function executeOps(context, templates, ops) {
  for (const [op, args] of ops) {
    try {
      if (op === "__instances") {
        drawInstances(context, templates, args[0], args[1]);
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

function drawInstances(context, templates, name, instances) {
  const tpl = templates[name];
  if (!tpl) { console.warn("[Easel] Unknown template:", name); return; }
  for (const inst of instances) {
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
    const templates = JSON.parse(this.el.dataset.templates || "{}");
    Object.assign(this._templates, templates);
    const ops = JSON.parse(this.el.dataset.ops || "[]");
    if (ops.length > 0) {
      this.context.clearRect(0, 0, this.el.width, this.el.height);
      executeOps(this.context, this._templates, ops);
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
  mounted() {
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
