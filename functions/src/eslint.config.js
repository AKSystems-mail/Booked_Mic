// functions/eslint.config.js
import eslintJs from "@eslint/js";
import tseslint from "typescript-eslint";
// import eslintPluginImport from "eslint-plugin-import"; // If you can configure it for flat config
// import eslintConfigGoogle from "eslint-config-google"; // Google config might be harder to integrate directly

export default tseslint.config(
  eslintJs.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked, // For stricter, type-aware linting
  // OR use ...tseslint.configs.recommended, // For basic TS linting without type checking in ESLint

  // Example for integrating eslint-plugin-import if it supports flat config
  // (You'll need to check its documentation for ESLint v9 flat config)
  // {
  //   plugins: {
  //     import: eslintPluginImport,
  //   },
  //   rules: {
  //     ...eslintPluginImport.configs.recommended.rules,
  //     ...eslintPluginImport.configs.typescript.rules,
  //     "import/no-unresolved": "off", // Example: turning off a rule
  //   },
  //   settings: {
  //     'import/resolver': {
  //       typescript: {}
  //     }
  //   }
  // },

  {
    languageOptions: {
      parserOptions: {
        project: ["./tsconfig.json", "./tsconfig.dev.json"], // Ensure these paths are correct
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      "quotes": ["error", "double"],
      "indent": ["error", 2],
      "object-curly-spacing": ["error", "never"],
      "max-len": ["warn", { "code": 120, "ignoreUrls": true, "ignoreStrings": true, "ignoreTemplateLiterals": true }], // Increased max-len a bit
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/no-unused-vars": ["warn", { "argsIgnorePattern": "^_" }],
      // Add other rules from your old .eslintrc.js that you want to keep
    },
  },
  {
    ignores: ["lib/", "generated/", "node_modules/"],
  }
);