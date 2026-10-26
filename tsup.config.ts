import { defineConfig } from "tsup";

export default defineConfig({
    entry: {
        "security-report/dist/index": "security-report/src/index.ts",
        // future actions can be registered here:
        // 'gitleaks-report/dist/index': 'gitleaks-report/src/index.ts',
        // 'semgrep-report/dist/index': 'semgrep-report/src/index.ts',
    },
    format: ["cjs"],
    platform: "node",
    target: "node24",
    outDir: ".",
    outExtension: () => ({ js: ".js" }),
    bundle: true,
    splitting: false,
    clean: false,
    minify: true,
    sourcemap: false,
    noExternal: [/.*/],
});
