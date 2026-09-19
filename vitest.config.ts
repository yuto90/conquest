import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test-function/**/*.test.ts"],
    environment: "node",
  },
});
