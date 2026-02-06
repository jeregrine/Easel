function executeOps(context, ops) {
  for (const [op, args] of ops) {
    try {
      if (op === "set") {
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

function canvasXY(el, e) {
  const rect = el.getBoundingClientRect();
  return {
    x: Math.round(e.clientX - rect.left),
    y: Math.round(e.clientY - rect.top),
  };
}

export const EaselHook = {
  mounted() {
    this.context = this.el.getContext("2d");

    // Draw initial ops from data attribute
    const initialOps = JSON.parse(this.el.dataset.ops || "[]");
    if (initialOps.length > 0) {
      executeOps(this.context, initialOps);
    }

    // Listen for draw events
    this.handleEvent(`easel:${this.el.id}:draw`, ({ ops }) => {
      executeOps(this.context, ops);
    });

    // Listen for clear events
    this.handleEvent(`easel:${this.el.id}:clear`, () => {
      this.context.clearRect(0, 0, this.el.width, this.el.height);
    });

    // Wire up DOM events from data-events attribute
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
};
