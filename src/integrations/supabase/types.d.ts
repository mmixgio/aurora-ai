// Compatibility shim for TS moduleResolution: "bundler"
// Ensures import './types' resolves even in strict bundler mode
// Do NOT edit auto-generated types.ts; this file only forwards types.

export type Json = import('./types.ts').Json;
export type Database = import('./types.ts').Database;
export type Tables<T extends any, U extends any = never> = import('./types.ts').Tables<T, U>;
export type TablesInsert<T extends any, U extends any = never> = import('./types.ts').TablesInsert<T, U>;
export type TablesUpdate<T extends any, U extends any = never> = import('./types.ts').TablesUpdate<T, U>;
export type Enums<T extends any, U extends any = never> = import('./types.ts').Enums<T, U>;
export type CompositeTypes<T extends any, U extends any = never> = import('./types.ts').CompositeTypes<T, U>;

// Value declaration type-only (no runtime value emitted)
export const Constants: typeof import('./types.ts').Constants;
