/**
 * Budget för bakade nivåset (DESIGN §17): högst `max` set i full upplösning.
 * Äldst använda frigörs först; set i `keep` (det aktiva) och det som just används frigörs aldrig.
 */
export class SetLru {
  /** Äldst först. */
  private readonly order: string[] = [];

  constructor(private readonly max: number) {}

  get sets(): readonly string[] {
    return this.order;
  }

  /** Markerar `id` som använt. Returnerar de set som ska frigöras (textures.remove). */
  use(id: string, keep: readonly string[] = []): string[] {
    const i = this.order.indexOf(id);
    if (i >= 0) this.order.splice(i, 1);
    this.order.push(id);
    const out: string[] = [];
    for (let k = 0; this.order.length > this.max && k < this.order.length; ) {
      const s = this.order[k];
      if (s === id || keep.includes(s)) {
        k++;
        continue;
      }
      this.order.splice(k, 1);
      out.push(s);
    }
    return out;
  }
}
