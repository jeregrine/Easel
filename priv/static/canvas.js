function executeOps(context, ops) {
  for (const [op, args] of ops) {
    try {
      if (op === "set") {
        context[args[0]] = args[1];
      } else if (typeof context[op] === "function") {
        context[op](...args);
      } else {
        console.warn("[Canvas] Unknown operation:", op);
      }
    } catch (e) {
      console.error("[Canvas] Error executing op:", op, args, e);
    }
  }
}

export const CanvasHook = {
  mounted() {
    this.context = this.el.getContext("2d");

    // Draw initial ops from data attribute
    const initialOps = JSON.parse(this.el.dataset.ops || "[]");
    if (initialOps.length > 0) {
      executeOps(this.context, initialOps);
    }

    // Listen for draw events
    this.handleEvent(`canvas:${this.el.id}:draw`, ({ ops }) => {
      executeOps(this.context, ops);
    });

    // Listen for clear events
    this.handleEvent(`canvas:${this.el.id}:clear`, () => {
      this.context.clearRect(0, 0, this.el.width, this.el.height);
    });
  },
};
