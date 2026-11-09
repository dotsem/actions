import { writeFileSync } from "node:fs";

// Record received CLI args so internal-test-node.yml can assert how build-node passes `args`
writeFileSync("build-args.json", JSON.stringify(process.argv.slice(2)));
console.log("Build completed successfully.");
